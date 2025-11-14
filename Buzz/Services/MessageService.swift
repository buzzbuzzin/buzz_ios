//
//  MessageService.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import Supabase
import Combine

@MainActor
class MessageService: ObservableObject {
    @Published var messages: [Message] = []
    @Published var directMessages: [DirectMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    
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
            let messages: [Message] = try await supabase
                .from("messages")
                .select()
                .eq("booking_id", value: bookingId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            await MainActor.run {
                self.messages = messages
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
        
        // Real backend call
        do {
            let messageData: [String: AnyJSON] = [
                "booking_id": .string(bookingId.uuidString),
                "from_user_id": .string(fromUserId.uuidString),
                "to_user_id": .string(toUserId.uuidString),
                "text": .string(text),
                "created_at": .string(ISO8601DateFormatter().string(from: Date())),
                "is_read": .bool(false)
            ]
            
            try await supabase
                .from("messages")
                .insert(messageData)
                .execute()
            
            await MainActor.run {
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
    
    // MARK: - Direct Messaging (without booking)
    
    /// Generate a consistent conversation ID from two user IDs
    /// This ensures the same conversation always uses the same booking ID
    static func conversationId(fromUserId: UUID, toUserId: UUID) -> UUID {
        // Sort UUIDs to ensure consistent conversation ID regardless of who initiated
        let sortedIds = [fromUserId.uuidString.lowercased(), toUserId.uuidString.lowercased()].sorted()
        let combined = sortedIds.joined(separator: "-direct-msg-")
        
        // Create a deterministic UUID v5-like from the combined string
        // Using a simple hash-based approach
        var hash = combined.hashValue
        var uuidBytes = [UInt8](repeating: 0, count: 16)
        
        // Distribute hash across bytes
        for i in 0..<16 {
            uuidBytes[i] = UInt8(abs((hash >> (i * 2)) & 0xFF))
        }
        
        // Set version (4) and variant bits for valid UUID v4 format
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x40 // Version 4
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80 // Variant 10
        
        // Convert to UUID
        let uuidString = String(format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
                                uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
                                uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
                                uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
                                uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15])
        
        return UUID(uuidString: uuidString) ?? UUID()
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
            // Fetch messages where from_user_id is one user and to_user_id is the other, or vice versa
            let messages1: [DirectMessage] = try await supabase
                .from("direct_messages")
                .select()
                .eq("from_user_id", value: fromUserId.uuidString)
                .eq("to_user_id", value: toUserId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            let messages2: [DirectMessage] = try await supabase
                .from("direct_messages")
                .select()
                .eq("from_user_id", value: toUserId.uuidString)
                .eq("to_user_id", value: fromUserId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            // Combine and sort by creation date
            let allMessages = (messages1 + messages2).sorted(by: { $0.createdAt < $1.createdAt })
            
            await MainActor.run {
                self.directMessages = allMessages
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
            isRead: false
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
                "created_at": .string(ISO8601DateFormatter().string(from: Date())),
                "is_read": .bool(false)
            ]
            
            let insertedMessage: DirectMessage = try await supabase
                .from("direct_messages")
                .insert(messageData)
                .select()
                .single()
                .execute()
                .value
            
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
    
    /// Count messages sent by a user before the other user responds
    /// Returns the count of consecutive messages from the sender before any response
    func countSentMessagesBeforeResponse(fromUserId: UUID, toUserId: UUID) -> Int {
        var count = 0
        
        // Sort direct messages chronologically
        let sortedMessages = directMessages.sorted(by: { $0.createdAt < $1.createdAt })
        
        // Count consecutive messages from sender before any response
        for message in sortedMessages {
            if message.fromUserId == fromUserId && message.toUserId == toUserId {
                // This is a message from the sender
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
        
        // Get all unique conversations (distinct pairs of users)
        // This query gets the latest message from each conversation
        let query = """
            SELECT DISTINCT ON (
                LEAST(from_user_id, to_user_id),
                GREATEST(from_user_id, to_user_id)
            )
            id, from_user_id, to_user_id, text, created_at, is_read
            FROM direct_messages
            WHERE from_user_id = '\(userId.uuidString)' OR to_user_id = '\(userId.uuidString)'
            ORDER BY LEAST(from_user_id, to_user_id), GREATEST(from_user_id, to_user_id), created_at DESC
        """
        
        // For now, use a simpler approach - get all messages and group them
        let allMessages: [DirectMessage] = try await supabase
            .from("direct_messages")
            .select()
            .or("from_user_id.eq.\(userId.uuidString),to_user_id.eq.\(userId.uuidString)")
            .order("created_at", ascending: false)
            .execute()
            .value
        
        // Group by conversation partner
        var conversations: [UUID: DirectMessage] = [:]
        for message in allMessages {
            let partnerId = message.fromUserId == userId ? message.toUserId : message.fromUserId
            if conversations[partnerId] == nil || message.createdAt > (conversations[partnerId]?.createdAt ?? Date.distantPast) {
                conversations[partnerId] = message
            }
        }
        
        return conversations.map { partnerId, lastMessage in
            DirectMessageConversation(
                partnerId: partnerId,
                lastMessage: lastMessage
            )
        }
    }
    
    // MARK: - Sample Data for Demo
    // TODO: Remove this function when connecting to real backend
    
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
}

