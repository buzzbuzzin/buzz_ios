//
//  MessageService.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import Supabase
import Combine
import CryptoKit

@MainActor
class MessageService: ObservableObject {
    @Published var messages: [Message] = []
    @Published var directMessages: [DirectMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    private let notificationManager = NotificationManager.shared
    private let iso8601Formatter = ISO8601DateFormatter()
    
    // MARK: - Fetch Messages for Booking
    
    func fetchMessages(bookingId: UUID, pilotId: UUID, customerId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            // Simulate API call delay
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            // SAMPLE DATA FOR DEMO PURPOSES
            let sampleMessages = createSampleMessages(for: bookingId, pilotId: pilotId, customerId: customerId)
            
            await MainActor.run {
                self.messages = sampleMessages
                self.isLoading = false
            }
            return
        }
        
        // Real backend call
        do {
            let fetchedMessages: [Message] = try await supabase
                .from("messages")
                .select()
                .eq("booking_id", value: bookingId.uuidString)
                .is("deleted_at", value: nil)
                .order("created_at", ascending: true)
                .execute()
                .value

            let reactionsByMessage = try await fetchBookingMessageReactions(messageIds: fetchedMessages.map(\.id))
            let hydratedMessages = fetchedMessages.map { message in
                var message = message
                message.reactions = reactionsByMessage[message.id] ?? []
                return message
            }
            
            await MainActor.run {
                self.messages = hydratedMessages
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Send Message
    
    func sendMessage(bookingId: UUID, fromUserId: UUID, toUserId: UUID, text: String) async throws {
        isLoading = true
        errorMessage = nil
        
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            // Add message to local array for demo
            let newMessage = Message(
                id: UUID(),
                bookingId: bookingId,
                fromUserId: fromUserId,
                toUserId: toUserId,
                text: text,
                createdAt: Date(),
                isRead: false
            )
            
            await MainActor.run {
                self.messages.append(newMessage)
                self.isLoading = false
            }
            return
        }

        let optimisticMessage = Message(
            id: UUID(),
            bookingId: bookingId,
            fromUserId: fromUserId,
            toUserId: toUserId,
            text: text,
            createdAt: Date(),
            isRead: false
        )
        
        // Real backend call
        do {
            await MainActor.run {
                self.messages.append(optimisticMessage)
            }

            let messageData: [String: AnyJSON] = [
                "booking_id": .string(bookingId.uuidString),
                "from_user_id": .string(fromUserId.uuidString),
                "to_user_id": .string(toUserId.uuidString),
                "text": .string(text),
                "created_at": .string(iso8601Formatter.string(from: Date())),
                "is_read": .bool(false)
            ]
            
            let insertedMessage: Message = try await supabase
                .from("messages")
                .insert(messageData)
                .select()
                .single()
                .execute()
                .value
            
            // Send notification to recipient
            Task {
                await sendMessageNotification(
                    toUserId: toUserId,
                    fromUserId: fromUserId,
                    messageText: text,
                    bookingId: bookingId
                )
            }
            
            await MainActor.run {
                if let index = self.messages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                    self.messages[index] = insertedMessage
                } else {
                    self.messages.append(insertedMessage)
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.messages.removeAll { $0.id == optimisticMessage.id }
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Direct Messaging (without booking)
    
    /// Generate a consistent conversation ID from two user IDs
    /// This ensures the same conversation always uses the same ID across devices.
    static func conversationId(fromUserId: UUID, toUserId: UUID) -> UUID {
        // Sort UUIDs to ensure consistent conversation ID regardless of who initiated
        let sortedIds = [fromUserId.uuidString.lowercased(), toUserId.uuidString.lowercased()].sorted()
        let combined = sortedIds.joined(separator: "-direct-msg-")

        // Create a deterministic UUID from the SHA-256 digest.
        let digest = SHA256.hash(data: Data(combined.utf8))
        var uuidBytes = Array(digest.prefix(16))

        // Set version/variant bits to produce an RFC 4122-compatible UUID.
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x50 // Version 5 style (name-based)
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80 // Variant 10

        let uuid = uuid_t(
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        )
        return UUID(uuid: uuid)
    }

    static func directConversationFilter(userAId: UUID, userBId: UUID) -> String {
        let sortedIds = [userAId.uuidString, userBId.uuidString].sorted()
        let firstId = sortedIds[0]
        let secondId = sortedIds[1]
        return "and(from_user_id.eq.\(firstId),to_user_id.eq.\(secondId)),and(from_user_id.eq.\(secondId),to_user_id.eq.\(firstId))"
    }

    static func buildDirectMessageConversations(
        for userId: UUID,
        from messages: [DirectMessage]
    ) -> [DirectMessageConversation] {
        var conversations: [UUID: (lastMessage: DirectMessage, hasUnreadMessages: Bool)] = [:]

        for message in messages {
            let partnerId = message.fromUserId == userId ? message.toUserId : message.fromUserId
            let hasUnreadIncomingMessage = message.toUserId == userId && !message.isRead

            if var existing = conversations[partnerId] {
                if message.createdAt > existing.lastMessage.createdAt {
                    existing.lastMessage = message
                }
                existing.hasUnreadMessages = existing.hasUnreadMessages || hasUnreadIncomingMessage
                conversations[partnerId] = existing
            } else {
                conversations[partnerId] = (
                    lastMessage: message,
                    hasUnreadMessages: hasUnreadIncomingMessage
                )
            }
        }

        return conversations.map { partnerId, state in
            DirectMessageConversation(
                id: Self.conversationId(fromUserId: userId, toUserId: partnerId),
                partnerId: partnerId,
                lastMessage: state.lastMessage,
                hasUnreadMessages: state.hasUnreadMessages
            )
        }
        .sorted { $0.lastMessage.createdAt > $1.lastMessage.createdAt }
    }
    
    /// Fetch direct messages between two users (not tied to a booking)
    func fetchDirectMessages(fromUserId: UUID, toUserId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            // For demo, return empty messages
            await MainActor.run {
                self.directMessages = []
                self.isLoading = false
            }
            return
        }
        
        // Real backend call - fetch messages between these two users
        do {
            let fetchedMessages: [DirectMessage] = try await supabase
                .from("direct_messages")
                .select()
                .or(Self.directConversationFilter(userAId: fromUserId, userBId: toUserId))
                .is("deleted_at", value: nil)
                .order("created_at", ascending: true)
                .execute()
                .value

            let reactionsByMessage = try await fetchDirectMessageReactions(messageIds: fetchedMessages.map(\.id))
            let hydratedMessages = fetchedMessages.map { message in
                var message = message
                message.reactions = reactionsByMessage[message.id] ?? []
                return message
            }
            
            await MainActor.run {
                self.directMessages = hydratedMessages
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    /// Send a direct message between two users (not tied to a booking)
    func sendDirectMessage(fromUserId: UUID, toUserId: UUID, text: String) async throws {
        errorMessage = nil
        
        // Create optimistic message for immediate UI update
        let optimisticMessage = DirectMessage(
            id: UUID(),
            fromUserId: fromUserId,
            toUserId: toUserId,
            text: text,
            createdAt: Date(),
            isRead: false,
            metadata: nil
        )

        // Add optimistically to UI immediately
        await MainActor.run {
            self.directMessages.append(optimisticMessage)
        }

        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            // Already added optimistically above
            return
        }

        // Real backend call
        do {
            // Insert the direct message
            let messageData: [String: AnyJSON] = [
                "from_user_id": .string(fromUserId.uuidString),
                "to_user_id": .string(toUserId.uuidString),
                "text": .string(text),
                "created_at": .string(iso8601Formatter.string(from: Date())),
                "is_read": .bool(false)
            ]

            let insertedMessage: DirectMessage = try await supabase
                .from("direct_messages")
                .insert(messageData)
                .select()
                .single()
                .execute()
                .value

            // Send notification to recipient
            Task {
                await sendMessageNotification(
                    toUserId: toUserId,
                    fromUserId: fromUserId,
                    messageText: text,
                    bookingId: nil
                )
            }

            // Replace optimistic message with real message from backend
            await MainActor.run {
                if let index = self.directMessages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                    self.directMessages[index] = insertedMessage
                } else {
                    // If optimistic message not found, just refresh all messages
                    Task {
                        try? await self.fetchDirectMessages(fromUserId: fromUserId, toUserId: toUserId)
                    }
                }
            }
        } catch {
            // Remove optimistic message on error
            await MainActor.run {
                if let index = self.directMessages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                    self.directMessages.remove(at: index)
                }
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }

    /// Send a direct message with an embedded marketplace listing card
    func sendDirectMessageWithListing(
        fromUserId: UUID,
        toUserId: UUID,
        listing: MarketplaceListingWithSeller
    ) async throws {
        let listingCard = DirectMessageListingCard(
            listingId: listing.listing.id,
            title: listing.listing.title,
            price: listing.listing.formattedPrice,
            imageUrl: listing.listing.imageUrls.first,
            condition: listing.listing.condition.displayName
        )
        let metadata = DirectMessageMetadata(
            type: "listing_card",
            listingCard: listingCard
        )

        let text = "Interested in: \(listing.listing.title) (\(listing.listing.formattedPrice))"

        // Create optimistic message
        let optimisticMessage = DirectMessage(
            id: UUID(),
            fromUserId: fromUserId,
            toUserId: toUserId,
            text: text,
            createdAt: Date(),
            isRead: false,
            metadata: metadata
        )

        await MainActor.run {
            self.directMessages.append(optimisticMessage)
        }

        if DemoModeManager.shared.isDemoModeEnabled { return }

        do {
            let insertPayload = DirectMessageInsert(
                fromUserId: fromUserId,
                toUserId: toUserId,
                text: text,
                isRead: false,
                metadata: metadata,
                createdAt: iso8601Formatter.string(from: Date())
            )

            let insertedMessage: DirectMessage = try await supabase
                .from("direct_messages")
                .insert(insertPayload)
                .select()
                .single()
                .execute()
                .value

            Task {
                await sendMessageNotification(
                    toUserId: toUserId,
                    fromUserId: fromUserId,
                    messageText: text,
                    bookingId: nil
                )
            }

            await MainActor.run {
                if let index = self.directMessages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                    self.directMessages[index] = insertedMessage
                } else {
                    Task {
                        try? await self.fetchDirectMessages(fromUserId: fromUserId, toUserId: toUserId)
                    }
                }
            }
        } catch {
            await MainActor.run {
                if let index = self.directMessages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                    self.directMessages.remove(at: index)
                }
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }

    func setReaction(forBookingMessageId messageId: UUID, by userId: UUID, reaction: MessageReactionType) async throws {
        errorMessage = nil

        let originalReactions = messages.first(where: { $0.id == messageId })?.reactions ?? []
        updateBookingMessageReaction(messageId: messageId, reactions: originalReactions.applyingReaction(reaction, by: userId))

        if DemoModeManager.shared.isDemoModeEnabled {
            return
        }

        do {
            let payload = BookingMessageReactionUpsert(
                bookingMessageId: messageId,
                userId: userId,
                reaction: reaction,
                updatedAt: iso8601Formatter.string(from: Date())
            )

            let row: BookingMessageReactionRow = try await supabase
                .from("booking_message_reactions")
                .upsert(payload, onConflict: "booking_message_id,user_id")
                .select()
                .single()
                .execute()
                .value

            let refreshedReactions = originalReactions.applyingReaction(
                row.reaction,
                by: row.userId,
                reactionId: row.id,
                timestamp: row.updatedAt ?? row.createdAt
            )
            updateBookingMessageReaction(messageId: messageId, reactions: refreshedReactions)

            if let message = messages.first(where: { $0.id == messageId }) {
                Task {
                    await sendReactionNotification(
                        messageAuthorId: message.fromUserId,
                        reactorUserId: userId,
                        reaction: reaction,
                        messageText: message.text,
                        bookingId: message.bookingId
                    )
                }
            }
        } catch {
            updateBookingMessageReaction(messageId: messageId, reactions: originalReactions)
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func clearReaction(forBookingMessageId messageId: UUID, by userId: UUID) async throws {
        errorMessage = nil

        let originalReactions = messages.first(where: { $0.id == messageId })?.reactions ?? []
        updateBookingMessageReaction(messageId: messageId, reactions: originalReactions.removingReaction(by: userId))

        if DemoModeManager.shared.isDemoModeEnabled {
            return
        }

        do {
            _ = try await supabase
                .from("booking_message_reactions")
                .delete()
                .eq("booking_message_id", value: messageId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
        } catch {
            updateBookingMessageReaction(messageId: messageId, reactions: originalReactions)
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func setReaction(forDirectMessageId messageId: UUID, by userId: UUID, reaction: MessageReactionType) async throws {
        errorMessage = nil

        let originalReactions = directMessages.first(where: { $0.id == messageId })?.reactions ?? []
        updateDirectMessageReaction(messageId: messageId, reactions: originalReactions.applyingReaction(reaction, by: userId))

        if DemoModeManager.shared.isDemoModeEnabled {
            return
        }

        do {
            let payload = DirectMessageReactionUpsert(
                directMessageId: messageId,
                userId: userId,
                reaction: reaction,
                updatedAt: iso8601Formatter.string(from: Date())
            )

            let row: DirectMessageReactionRow = try await supabase
                .from("direct_message_reactions")
                .upsert(payload, onConflict: "direct_message_id,user_id")
                .select()
                .single()
                .execute()
                .value

            let refreshedReactions = originalReactions.applyingReaction(
                row.reaction,
                by: row.userId,
                reactionId: row.id,
                timestamp: row.updatedAt ?? row.createdAt
            )
            updateDirectMessageReaction(messageId: messageId, reactions: refreshedReactions)

            if let message = directMessages.first(where: { $0.id == messageId }) {
                Task {
                    await sendReactionNotification(
                        messageAuthorId: message.fromUserId,
                        reactorUserId: userId,
                        reaction: reaction,
                        messageText: message.text,
                        bookingId: nil
                    )
                }
            }
        } catch {
            updateDirectMessageReaction(messageId: messageId, reactions: originalReactions)
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func clearReaction(forDirectMessageId messageId: UUID, by userId: UUID) async throws {
        errorMessage = nil

        let originalReactions = directMessages.first(where: { $0.id == messageId })?.reactions ?? []
        updateDirectMessageReaction(messageId: messageId, reactions: originalReactions.removingReaction(by: userId))

        if DemoModeManager.shared.isDemoModeEnabled {
            return
        }

        do {
            _ = try await supabase
                .from("direct_message_reactions")
                .delete()
                .eq("direct_message_id", value: messageId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
        } catch {
            updateDirectMessageReaction(messageId: messageId, reactions: originalReactions)
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Count messages sent by a user before the other user responds
    /// Returns the count of consecutive messages from the sender before any response
    func countSentMessagesBeforeResponse(fromUserId: UUID, toUserId: UUID) -> Int {
        var count = 0
        
        // Sort direct messages chronologically
        let sortedMessages = directMessages.sorted(by: { $0.createdAt < $1.createdAt })
        
        // Count consecutive messages from sender before any response
        // Listing card messages are a separate category and don't count toward the limit
        for message in sortedMessages {
            if message.fromUserId == fromUserId && message.toUserId == toUserId {
                if message.isListingCard { continue }
                count += 1
            } else if message.fromUserId == toUserId && message.toUserId == fromUserId {
                // Found a response - stop counting
                break
            }
        }
        
        return count
    }
    
    /// Check if the other user has responded
    func hasResponse(fromUserId: UUID, toUserId: UUID) -> Bool {
        return directMessages.contains { message in
            message.fromUserId == toUserId && message.toUserId == fromUserId
        }
    }
    
    /// Fetch last message for a booking conversation
    func fetchLastMessageForBooking(bookingId: UUID) async throws -> Message? {
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            return nil
        }
        
        do {
            let messages: [Message] = try await supabase
                .from("messages")
                .select()
                .eq("booking_id", value: bookingId.uuidString)
                .is("deleted_at", value: nil)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            return messages.first
        } catch {
            return nil
        }
    }
    
    /// Check if booking has unread messages for user
    func hasUnreadMessagesForBooking(bookingId: UUID, userId: UUID) async throws -> Bool {
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            return false
        }
        
        do {
            let unreadCount: Int = try await supabase
                .from("messages")
                .select("id", head: true, count: .exact)
                .eq("booking_id", value: bookingId.uuidString)
                .eq("to_user_id", value: userId.uuidString)
                .eq("is_read", value: false)
                .is("deleted_at", value: nil)
                .execute()
                .count ?? 0
            
            return unreadCount > 0
        } catch {
            return false
        }
    }
    
    /// Fetch all direct message conversations for the current user
    func fetchDirectMessageConversations(userId: UUID) async throws -> [DirectMessageConversation] {
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            return []
        }
        
        // Get all unique conversations - fetch all messages and group by partner
        let allMessages: [DirectMessage] = try await supabase
            .from("direct_messages")
            .select()
            .or("from_user_id.eq.\(userId.uuidString),to_user_id.eq.\(userId.uuidString)")
            .is("deleted_at", value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value

        return Self.buildDirectMessageConversations(for: userId, from: allMessages)
    }
    
    // MARK: - Sample Data for Demo
    // TODO: Remove this function when connecting to real backend

    private func fetchBookingMessageReactions(messageIds: [UUID]) async throws -> [UUID: [MessageReactionRecord]] {
        guard !messageIds.isEmpty else { return [:] }

        let rows: [BookingMessageReactionRow]
        if messageIds.count == 1, let messageId = messageIds.first {
            rows = try await supabase
                .from("booking_message_reactions")
                .select()
                .eq("booking_message_id", value: messageId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
        } else {
            rows = try await supabase
                .from("booking_message_reactions")
                .select()
                .or(Self.reactionFilter(column: "booking_message_id", ids: messageIds))
                .order("created_at", ascending: true)
                .execute()
                .value
        }

        return Dictionary(grouping: rows, by: \.bookingMessageId)
            .mapValues { $0.map(\.record) }
    }

    private func fetchDirectMessageReactions(messageIds: [UUID]) async throws -> [UUID: [MessageReactionRecord]] {
        guard !messageIds.isEmpty else { return [:] }

        let rows: [DirectMessageReactionRow]
        if messageIds.count == 1, let messageId = messageIds.first {
            rows = try await supabase
                .from("direct_message_reactions")
                .select()
                .eq("direct_message_id", value: messageId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
        } else {
            rows = try await supabase
                .from("direct_message_reactions")
                .select()
                .or(Self.reactionFilter(column: "direct_message_id", ids: messageIds))
                .order("created_at", ascending: true)
                .execute()
                .value
        }

        return Dictionary(grouping: rows, by: \.directMessageId)
            .mapValues { $0.map(\.record) }
    }

    private func updateBookingMessageReaction(messageId: UUID, reactions: [MessageReactionRecord]) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        messages[index].reactions = reactions
    }

    private func updateDirectMessageReaction(messageId: UUID, reactions: [MessageReactionRecord]) {
        guard let index = directMessages.firstIndex(where: { $0.id == messageId }) else { return }
        directMessages[index].reactions = reactions
    }

    private static func reactionFilter(column: String, ids: [UUID]) -> String {
        ids.map { "\(column).eq.\($0.uuidString)" }
            .joined(separator: ",")
    }
    
    private func createSampleMessages(for bookingId: UUID, pilotId: UUID, customerId: UUID) -> [Message] {
        let calendar = Calendar.current
        let now = Date()
        
        // Create sample conversation history
        // Conversation starts with pilot, then alternates: pilot -> customer -> pilot -> customer
        return [
            Message(
                id: UUID(),
                bookingId: bookingId,
                fromUserId: pilotId, // Pilot starts the conversation
                toUserId: customerId, // Customer
                text: "Hi! I saw your booking. Can you provide more details about the location?",
                createdAt: calendar.date(byAdding: .hour, value: -12, to: now) ?? now,
                isRead: true
            ),
            Message(
                id: UUID(),
                bookingId: bookingId,
                fromUserId: customerId, // Customer replies
                toUserId: pilotId, // Pilot
                text: "Sure! The location is accessible and has good clearance for drone operations. Are there any specific shots you're looking for?",
                createdAt: calendar.date(byAdding: .hour, value: -11, to: now) ?? now,
                isRead: true
            ),
            Message(
                id: UUID(),
                bookingId: bookingId,
                fromUserId: pilotId, // Pilot replies
                toUserId: customerId, // Customer
                text: "Yes, I'd like aerial shots of the building facade and surrounding area. Can you do that?",
                createdAt: calendar.date(byAdding: .hour, value: -10, to: now) ?? now,
                isRead: true
            ),
            Message(
                id: UUID(),
                bookingId: bookingId,
                fromUserId: customerId, // Customer replies
                toUserId: pilotId, // Pilot
                text: "Absolutely! I have experience with architectural photography. I'll make sure to capture all angles.",
                createdAt: calendar.date(byAdding: .hour, value: -9, to: now) ?? now,
                isRead: true
            )
        ]
    }
    
    // MARK: - Soft Delete Messages
    
    func softDeleteDirectMessages(fromUserId: UUID, toUserId: UUID) async throws {
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            // In demo mode, just remove from local array
            directMessages.removeAll()
            return
        }
        
        // Real backend call - mark messages as deleted by current user
        let updates: [String: AnyJSON] = [
            "deleted_at": .string(ISO8601DateFormatter().string(from: Date())),
            "deleted_by": .string(fromUserId.uuidString)
        ]
        
        try await supabase
            .from("direct_messages")
            .update(updates)
            .or(Self.directConversationFilter(userAId: fromUserId, userBId: toUserId))
            .is("deleted_at", value: nil)
            .execute()
    }
    
    func softDeleteBookingMessages(bookingId: UUID, userId: UUID) async throws {
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            // In demo mode, just remove from local array
            messages.removeAll { $0.bookingId == bookingId }
            return
        }
        
        // Real backend call - mark messages as deleted by current user
        let updates: [String: AnyJSON] = [
            "deleted_at": .string(ISO8601DateFormatter().string(from: Date())),
            "deleted_by": .string(userId.uuidString)
        ]
        
        try await supabase
            .from("messages")
            .update(updates)
            .eq("booking_id", value: bookingId.uuidString)
            .is("deleted_at", value: nil)
            .execute()
    }
    
    // MARK: - Mark Messages as Unread
    
    func markDirectMessagesAsRead(fromUserId: UUID, toUserId: UUID) async throws {
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            for i in directMessages.indices {
                if directMessages[i].fromUserId == fromUserId && directMessages[i].toUserId == toUserId {
                    directMessages[i].isRead = true
                }
            }
            return
        }

        // Mark messages FROM the partner TO the current user as read
        let updates: [String: AnyJSON] = ["is_read": .bool(true)]

        try await supabase
            .from("direct_messages")
            .update(updates)
            .eq("from_user_id", value: fromUserId.uuidString)
            .eq("to_user_id", value: toUserId.uuidString)
            .eq("is_read", value: false)
            .is("deleted_at", value: nil)
            .execute()

        // Mirror the server-side update into the local cache so any view binding
        // (unread count, badge, conversation list) refreshes immediately without
        // waiting for a full refetch.
        for i in directMessages.indices {
            if directMessages[i].fromUserId == fromUserId
                && directMessages[i].toUserId == toUserId
                && !directMessages[i].isRead {
                directMessages[i].isRead = true
            }
        }
    }

    func markDirectMessagesAsUnread(fromUserId: UUID, toUserId: UUID) async throws {
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            // In demo mode, update local array
            for i in directMessages.indices {
                if directMessages[i].fromUserId == fromUserId && directMessages[i].toUserId == toUserId {
                    directMessages[i].isRead = false
                }
            }
            return
        }
        
        // Real backend call
        let updates: [String: AnyJSON] = ["is_read": .bool(false)]
        
        try await supabase
            .from("direct_messages")
            .update(updates)
            .eq("from_user_id", value: fromUserId.uuidString)
            .eq("to_user_id", value: toUserId.uuidString)
            .is("deleted_at", value: nil)
            .execute()
    }

    func markBookingMessagesAsRead(fromUserId: UUID, toUserId: UUID, bookingId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled {
            for i in messages.indices {
                if messages[i].bookingId == bookingId &&
                    messages[i].fromUserId == fromUserId &&
                    messages[i].toUserId == toUserId {
                    messages[i].isRead = true
                }
            }
            return
        }

        let updates: [String: AnyJSON] = ["is_read": .bool(true)]

        try await supabase
            .from("messages")
            .update(updates)
            .eq("booking_id", value: bookingId.uuidString)
            .eq("from_user_id", value: fromUserId.uuidString)
            .eq("to_user_id", value: toUserId.uuidString)
            .eq("is_read", value: false)
            .is("deleted_at", value: nil)
            .execute()
    }
    
    func markBookingMessagesAsUnread(bookingId: UUID, userId: UUID) async throws {
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            // In demo mode, update local array
            for i in messages.indices {
                if messages[i].bookingId == bookingId && messages[i].toUserId == userId {
                    messages[i].isRead = false
                }
            }
            return
        }
        
        // Real backend call
        let updates: [String: AnyJSON] = ["is_read": .bool(false)]
        
        try await supabase
            .from("messages")
            .update(updates)
            .eq("booking_id", value: bookingId.uuidString)
            .eq("to_user_id", value: userId.uuidString)
            .is("deleted_at", value: nil)
            .execute()
    }
    
    // MARK: - Notification Helper
    
    /// Send notification to message recipient
    private func sendMessageNotification(toUserId: UUID, fromUserId: UUID, messageText: String, bookingId: UUID?) async {
        do {
            guard toUserId != fromUserId else {
                return
            }
            
            // Get sender's profile for notification
            let senderProfile: UserProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: fromUserId.uuidString)
                .single()
                .execute()
                .value
            
            // Create message preview (limit to 100 characters)
            let preview = messageText.count > 100 ? String(messageText.prefix(97)) + "..." : messageText
            
            // Use booking ID as conversation ID if available, otherwise generate one
            let conversationId = bookingId ?? Self.conversationId(fromUserId: fromUserId, toUserId: toUserId)
            
            await notificationManager.notifyNewMessage(
                recipientUserId: toUserId,
                senderName: senderProfile.visibleDisplayName(to: toUserId),
                messagePreview: preview,
                conversationId: conversationId
            )
        } catch {
            print("Could not send message notification: \(error)")
            // Non-critical error, don't throw
        }
    }

    /// Send notification to message author when someone reacts to their message
    private func sendReactionNotification(messageAuthorId: UUID, reactorUserId: UUID, reaction: MessageReactionType, messageText: String, bookingId: UUID?) async {
        do {
            guard messageAuthorId != reactorUserId else {
                return
            }

            let reactorProfile: UserProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: reactorUserId.uuidString)
                .single()
                .execute()
                .value

            let conversationId = bookingId ?? Self.conversationId(fromUserId: reactorUserId, toUserId: messageAuthorId)

            await notificationManager.notifyMessageReaction(
                recipientUserId: messageAuthorId,
                reactorName: reactorProfile.visibleDisplayName(to: messageAuthorId),
                reactionEmoji: reaction.emoji,
                messagePreview: messageText,
                conversationId: conversationId
            )
        } catch {
            print("Could not send reaction notification: \(error)")
        }
    }
}
