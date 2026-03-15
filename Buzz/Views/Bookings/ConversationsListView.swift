//
//  ConversationsListView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct ConversationsListView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    @StateObject private var profileService = ProfileService()
    @StateObject private var messageService = MessageService()
    @State private var conversations: [ConversationItem] = []
    @State private var directMessageConversations: [DirectMessageConversationItem] = []
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    @State private var conversationToDelete: UUID?
    @State private var isDirectMessageDelete = false
    @State private var selectedBookingConversationId: UUID?
    @State private var selectedDirectConversationId: UUID?
    @State private var hasHandledDeepLink = false
    var deepLinkConversationId: UUID? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    LoadingView(message: "Loading conversations...")
                } else if conversations.isEmpty && directMessageConversations.isEmpty {
                    let emptyMessage = authService.userProfile?.userType == .pilot 
                        ? "Start messaging customers from booking details"
                        : "Start messaging pilots from booking details"
                    EmptyStateView(
                        icon: "message.fill",
                        title: "No Conversations",
                        message: emptyMessage
                    )
                } else {
                    List {
                        // Direct Messages Section
                        if !directMessageConversations.isEmpty {
                            Section("Direct Messages") {
                                ForEach(directMessageConversations) { conversation in
                                    NavigationLink(
                                        destination: DirectMessageView(
                                            pilotId: conversation.partnerId,
                                            pilotProfile: conversation.partnerProfile
                                        ),
                                        tag: conversation.id,
                                        selection: $selectedDirectConversationId
                                    ) {
                                        DirectMessageConversationRow(conversation: conversation)
                                    }
                                    .accessibilityLabel("Open conversation with \(conversation.partnerProfile.visibleDisplayName(to: authService.currentUser?.id))")
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            conversationToDelete = conversation.partnerId
                                            isDirectMessageDelete = true
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .accessibilityLabel("Delete conversation")
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            Task {
                                                await markDirectMessageAsUnread(partnerId: conversation.partnerId)
                                            }
                                        } label: {
                                            Label("Unread", systemImage: "message.badge")
                                        }
                                        .tint(.blue)
                                        .accessibilityLabel("Mark as unread")
                                    }
                                }
                            }
                        }
                        
                        // Booking Messages Section
                        if !conversations.isEmpty {
                            Section("Booking Messages") {
                                ForEach(conversations) { conversation in
                                    NavigationLink(
                                        destination: MessageView(
                                            customerProfile: conversation.otherUserProfile,
                                            booking: conversation.booking
                                        ),
                                        tag: conversation.id,
                                        selection: $selectedBookingConversationId
                                    ) {
                                        ConversationRow(conversation: conversation)
                                    }
                                    .accessibilityLabel("Open booking conversation with \(conversation.otherUserProfile.visibleDisplayName(to: authService.currentUser?.id))")
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            conversationToDelete = conversation.id
                                            isDirectMessageDelete = false
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .accessibilityLabel("Delete conversation")
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            Task {
                                                await markBookingMessagesAsUnread(bookingId: conversation.id)
                                            }
                                        } label: {
                                            Label("Unread", systemImage: "message.badge")
                                        }
                                        .tint(.blue)
                                        .accessibilityLabel("Mark as unread")
                                    }
                                }
                            }
                        }
                    }
                    .refreshable {
                        await loadConversations()
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task {
                    await loadConversations()
                }
            }
            .alert("Delete Conversation", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                    .accessibilityLabel("Cancel deletion")
                Button("Delete", role: .destructive) {
                    Task {
                        await performDelete()
                    }
                }
                .accessibilityLabel("Confirm delete conversation")
            } message: {
                Text("By deleting this conversation, it will be removed from your device. For security reasons, messages will be kept on our servers for up to 7 days before permanent deletion.")
            }
        }
    }
    
    private func loadConversations() async {
        guard let currentUser = authService.currentUser,
              let userProfile = authService.userProfile else { return }
        
        isLoading = true
        
        do {
            let isPilot = userProfile.userType == .pilot
            
            // Load booking conversations
            try await bookingService.fetchMyBookings(userId: currentUser.id, isPilot: isPilot)
            
            // Create conversation items from bookings
            var items: [ConversationItem] = []
            
            // Only include accepted or completed bookings (confirmed bookings)
            for booking in bookingService.myBookings {
                if booking.status == .accepted || booking.status == .completed {
                    // Fetch last message and unread status
                    let lastMessage = try? await messageService.fetchLastMessageForBooking(bookingId: booking.id)
                    let hasUnread = try? await messageService.hasUnreadMessagesForBooking(bookingId: booking.id, userId: currentUser.id)
                    
                    if isPilot {
                        // For pilots: show customer profiles
                        if let customerProfile = try await bookingConversationProfile(
                            otherUserId: booking.customerId,
                            isPilot: true
                        ) {
                            items.append(ConversationItem(
                                id: booking.id,
                                booking: booking,
                                otherUserProfile: customerProfile,
                                lastMessage: lastMessage,
                                hasUnreadMessages: hasUnread ?? false
                            ))
                        }
                    } else {
                        // For customers: show pilot profiles
                        if let pilotId = booking.pilotId,
                           let pilotProfile = try await bookingConversationProfile(
                                otherUserId: pilotId,
                                isPilot: false
                           ) {
                            items.append(ConversationItem(
                                id: booking.id,
                                booking: booking,
                                otherUserProfile: pilotProfile,
                                lastMessage: lastMessage,
                                hasUnreadMessages: hasUnread ?? false
                            ))
                        }
                    }
                }
            }
            
            conversations = items
            
            // Load direct message conversations
            let directConversations = try await messageService.fetchDirectMessageConversations(userId: currentUser.id)
            
            // Fetch profiles for each conversation partner
            var directItems: [DirectMessageConversationItem] = []
            for conversation in directConversations {
                do {
                    let partnerProfile = try await profileService.getProfile(userId: conversation.partnerId)
                    directItems.append(DirectMessageConversationItem(
                        id: conversation.id,
                        partnerId: conversation.partnerId,
                        partnerProfile: partnerProfile,
                        lastMessage: conversation.lastMessage,
                        hasUnreadMessages: conversation.hasUnreadMessages
                    ))
                } catch {
                    print("Error loading profile for \(conversation.partnerId): \(error)")
                }
            }
            
            directMessageConversations = directItems
            applyDeepLinkNavigationIfPossible()
            isLoading = false
        } catch {
            isLoading = false
            print("Error loading conversations: \(error)")
        }
    }

    private func applyDeepLinkNavigationIfPossible() {
        guard !hasHandledDeepLink, let deepLinkConversationId else { return }

        if let bookingConversation = conversations.first(where: { $0.id == deepLinkConversationId }) {
            selectedBookingConversationId = bookingConversation.id
            hasHandledDeepLink = true
            return
        }

        // Direct-message IDs have used both partnerId and conversationId in different flows.
        if let directConversation = directMessageConversations.first(where: {
            $0.id == deepLinkConversationId || $0.partnerId == deepLinkConversationId
        }) {
            selectedDirectConversationId = directConversation.id
            hasHandledDeepLink = true
        }
    }
    
    private func performDelete() async {
        guard let conversationId = conversationToDelete,
              let currentUser = authService.currentUser else { return }
        
        do {
            if isDirectMessageDelete {
                // Soft delete direct messages
                try await messageService.softDeleteDirectMessages(fromUserId: currentUser.id, toUserId: conversationId)
                // Remove from UI
                directMessageConversations.removeAll { $0.partnerId == conversationId }
            } else {
                // Soft delete booking messages
                try await messageService.softDeleteBookingMessages(bookingId: conversationId, userId: currentUser.id)
                // Remove from UI
                conversations.removeAll { $0.id == conversationId }
            }
        } catch {
            print("Error deleting conversation: \(error)")
        }
        
        conversationToDelete = nil
    }
    
    private func markDirectMessageAsUnread(partnerId: UUID) async {
        guard let currentUser = authService.currentUser else { return }
        
        do {
            try await messageService.markDirectMessagesAsUnread(fromUserId: partnerId, toUserId: currentUser.id)
            // Reload conversations to update UI
            await loadConversations()
        } catch {
            print("Error marking direct messages as unread: \(error)")
        }
    }
    
    private func markBookingMessagesAsUnread(bookingId: UUID) async {
        guard let currentUser = authService.currentUser else { return }
        
        do {
            try await messageService.markBookingMessagesAsUnread(bookingId: bookingId, userId: currentUser.id)
            // Reload conversations to update UI
            await loadConversations()
        } catch {
            print("Error marking booking messages as unread: \(error)")
        }
    }

    private func bookingConversationProfile(otherUserId: UUID, isPilot: Bool) async throws -> UserProfile? {
        if DemoModeManager.shared.isDemoModeEnabled {
            return isPilot
                ? profileService.getSampleCustomerProfile(customerId: otherUserId)
                : profileService.getSamplePilotProfile(pilotId: otherUserId)
        }

        return try await profileService.getProfile(userId: otherUserId)
    }
}

// MARK: - Conversation Item

struct ConversationItem: Identifiable {
    let id: UUID
    let booking: Booking
    let otherUserProfile: UserProfile // Customer profile for pilots, Pilot profile for customers
    let lastMessage: Message?
    let hasUnreadMessages: Bool
}

// MARK: - Conversation Row

struct ConversationRow: View {
    @EnvironmentObject var authService: AuthService
    let conversation: ConversationItem

    // Computed property to determine display name based on user types
    private var displayName: String {
        conversation.otherUserProfile.visibleDisplayName(to: authService.currentUser?.id)
    }

    private var timeText: String {
        if let lastMessage = conversation.lastMessage {
            return lastMessage.createdAt.formattedConversationTime()
        }
        return conversation.booking.createdAt.formattedConversationTime()
    }

    private var previewText: String {
        if let lastMessage = conversation.lastMessage {
            return lastMessage.text
        }
        return conversation.booking.locationName
    }

    var body: some View {
        HStack(spacing: 12) {
            // Unread indicator dot
            if conversation.hasUnreadMessages {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }

            // Other User Profile Picture (Customer for pilots, Pilot for customers)
            Group {
                if let pictureUrl = conversation.otherUserProfile.profilePictureUrl,
                   let url = URL(string: pictureUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 50, height: 50)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        case .failure:
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                }
            }
            .frame(width: 50, height: 50)
            .accessibilityHidden(true)

            // Conversation Info
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                    .fontWeight(conversation.hasUnreadMessages ? .semibold : .regular)

                if conversation.otherUserProfile.userType != .pilot,
                   let callSign = conversation.otherUserProfile.callSign,
                   !callSign.isEmpty {
                    Text("@\(callSign)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                // Show last message text or location name
                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage.text)
                        .font(.subheadline)
                        .foregroundColor(conversation.hasUnreadMessages ? .primary : .secondary)
                        .fontWeight(conversation.hasUnreadMessages ? .semibold : .regular)
                        .lineLimit(1)
                } else {
                    Text(conversation.booking.locationName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Last message time
            VStack(alignment: .trailing, spacing: 4) {
                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage.createdAt.formattedConversationTime())
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(conversation.booking.createdAt.formattedConversationTime())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName)\(conversation.hasUnreadMessages ? ", unread" : ""), \(previewText), \(timeText)")
    }
}

// MARK: - Direct Message Conversation Item

struct DirectMessageConversationItem: Identifiable {
    let id: UUID
    let partnerId: UUID
    let partnerProfile: UserProfile
    let lastMessage: DirectMessage
    let hasUnreadMessages: Bool
}

// MARK: - Direct Message Conversation Row

struct DirectMessageConversationRow: View {
    let conversation: DirectMessageConversationItem
    @EnvironmentObject var authService: AuthService

    private var partnerDisplayName: String {
        conversation.partnerProfile.visibleDisplayName(to: authService.currentUser?.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Unread indicator dot
            if conversation.hasUnreadMessages {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }

            // Partner Profile Picture
            Group {
                if let pictureUrl = conversation.partnerProfile.profilePictureUrl,
                   let url = URL(string: pictureUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 50, height: 50)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        case .failure:
                            Image(systemName: "airplane.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                }
            }
            .frame(width: 50, height: 50)
            .accessibilityHidden(true)

            // Conversation Info
            VStack(alignment: .leading, spacing: 4) {
                Text(partnerDisplayName)
                    .font(.headline)
                    .fontWeight(conversation.hasUnreadMessages ? .semibold : .regular)

                HStack(spacing: 4) {
                    if conversation.lastMessage.isListingCard {
                        Image(systemName: "tag.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    Text(conversation.lastMessage.text)
                        .font(.subheadline)
                        .foregroundColor(conversation.hasUnreadMessages ? .primary : .secondary)
                        .fontWeight(conversation.hasUnreadMessages ? .semibold : .regular)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Last message time
            VStack(alignment: .trailing, spacing: 4) {
                Text(conversation.lastMessage.createdAt.formattedConversationTime())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(partnerDisplayName)\(conversation.hasUnreadMessages ? ", unread" : ""), \(conversation.lastMessage.isListingCard ? "listing: " : "")\(conversation.lastMessage.text), \(conversation.lastMessage.createdAt.formattedConversationTime())")
    }
}

