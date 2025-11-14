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
                                    SwipeableConversationRow(
                                        content: {
                                            NavigationLink(destination: DirectMessageView(
                                                pilotId: conversation.partnerId,
                                                pilotProfile: conversation.partnerProfile
                                            )) {
                                                DirectMessageConversationRow(conversation: conversation)
                                            }
                                        },
                                        onDelete: {
                                            conversationToDelete = conversation.partnerId
                                            isDirectMessageDelete = true
                                            showDeleteConfirmation = true
                                        },
                                        onMarkUnread: {
                                            Task {
                                                await markDirectMessageAsUnread(partnerId: conversation.partnerId)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Booking Messages Section
                        if !conversations.isEmpty {
                            Section("Booking Messages") {
                                ForEach(conversations) { conversation in
                                    SwipeableConversationRow(
                                        content: {
                                            NavigationLink(destination: MessageView(
                                                customerProfile: conversation.otherUserProfile,
                                                booking: conversation.booking
                                            )) {
                                                ConversationRow(conversation: conversation)
                                            }
                                        },
                                        onDelete: {
                                            conversationToDelete = conversation.id
                                            isDirectMessageDelete = false
                                            showDeleteConfirmation = true
                                        },
                                        onMarkUnread: {
                                            Task {
                                                await markBookingMessagesAsUnread(bookingId: conversation.id)
                                            }
                                        }
                                    )
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
            .task {
                await loadConversations()
            }
            .alert("Delete Conversation", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await performDelete()
                    }
                }
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
                        if let customerProfile = profileService.getSampleCustomerProfile(customerId: booking.customerId) {
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
                           let pilotProfile = profileService.getSamplePilotProfile(pilotId: pilotId) {
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
                        lastMessage: conversation.lastMessage
                    ))
                } catch {
                    print("Error loading profile for \(conversation.partnerId): \(error)")
                }
            }
            
            directMessageConversations = directItems
            isLoading = false
        } catch {
            isLoading = false
            print("Error loading conversations: \(error)")
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
    let conversation: ConversationItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Unread indicator dot
            if conversation.hasUnreadMessages {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
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
            
            // Conversation Info
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.otherUserProfile.fullName)
                    .font(.headline)
                
                // Show call sign for pilots
                if let callSign = conversation.otherUserProfile.callSign {
                    Text("@\(callSign)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                // Show last message text or location name
                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage.text)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Direct Message Conversation Item

struct DirectMessageConversationItem: Identifiable {
    let id: UUID
    let partnerId: UUID
    let partnerProfile: UserProfile
    let lastMessage: DirectMessage
}

// MARK: - Direct Message Conversation Row

struct DirectMessageConversationRow: View {
    let conversation: DirectMessageConversationItem
    @EnvironmentObject var authService: AuthService
    
    var hasUnreadMessages: Bool {
        // Check if last message is unread and was sent to current user
        guard let currentUserId = authService.currentUser?.id else { return false }
        return !conversation.lastMessage.isRead && conversation.lastMessage.toUserId == currentUserId
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Unread indicator dot
            if hasUnreadMessages {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
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
            
            // Conversation Info
            VStack(alignment: .leading, spacing: 4) {
                if let callSign = conversation.partnerProfile.callSign {
                    Text("@\(callSign)")
                        .font(.headline)
                } else {
                    Text(conversation.partnerProfile.fullName)
                        .font(.headline)
                }
                
                Text(conversation.lastMessage.text)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Last message time
            VStack(alignment: .trailing, spacing: 4) {
                Text(conversation.lastMessage.createdAt.formattedConversationTime())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Swipeable Conversation Row

struct SwipeableConversationRow<Content: View>: View {
    let content: Content
    let onDelete: () -> Void
    let onMarkUnread: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isDeleting = false
    
    init(
        @ViewBuilder content: () -> Content,
        onDelete: @escaping () -> Void,
        onMarkUnread: @escaping () -> Void
    ) {
        self.content = content()
        self.onDelete = onDelete
        self.onMarkUnread = onMarkUnread
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Background actions
            HStack(spacing: 0) {
                // Mark as unread (swipe right)
                HStack(spacing: 0) {
                    Button(action: {
                        withAnimation {
                            offset = 0
                        }
                        onMarkUnread()
                    }) {
                        Image(systemName: "message.badge")
                            .foregroundColor(.blue)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 42, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                    Spacer()
                        .frame(width: 15) // Gap between button and content
                }
                
                Spacer()
                
                // Delete (swipe left)
                HStack(spacing: 0) {
                    Spacer()
                        .frame(width: 15) // Gap between content and button
                    Button(action: {
                        withAnimation {
                            offset = 0
                            isDeleting = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDelete()
                        }
                    }) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 42, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.red)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
            }
            
            // Content
            content
                .background(Color(.systemBackground))
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            let dragAmount = value.translation.width
                            // Limit swipe distance (42 for button + 15 for gap + 8 for edge padding)
                            if dragAmount > 0 {
                                // Swipe right - show unread
                                offset = min(dragAmount, 65)
                            } else {
                                // Swipe left - show delete
                                offset = max(dragAmount, -65)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if abs(value.translation.width) > 30 {
                                    // Snap to action
                                    offset = value.translation.width > 0 ? 65 : -65
                                } else {
                                    // Snap back
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .onChange(of: isDeleting) { _, newValue in
            if newValue {
                offset = 0
            }
        }
    }
}

