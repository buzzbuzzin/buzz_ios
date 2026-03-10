//
//  MessageView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct MessageView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    let customerProfile: UserProfile?
    let booking: Booking
    var showsDismissButton = false
    @StateObject private var messageService = MessageService()
    @State private var messageText = ""
    @State private var messageBubbleFrames: [UUID: CGRect] = [:]
    @State private var selectedReactionMessageId: UUID?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @FocusState private var isTextFieldFocused: Bool

    private var currentUserId: UUID? {
        authService.currentUser?.id
    }

    private var selectedReactionMessage: Message? {
        guard let selectedReactionMessageId else { return nil }
        return messageService.messages.first(where: { $0.id == selectedReactionMessageId })
    }
    
    // Computed property to determine display name based on user type
    private var displayName: String {
        guard let profile = customerProfile else { return "User" }

        return profile.visibleDisplayName(to: authService.currentUser?.id)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Check if booking is confirmed
            if booking.status != .accepted && booking.status != .completed {
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("Messaging Unavailable")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Messaging is only available after a booking has been accepted by the pilot.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Other User Info Header (Customer for pilots, Pilot for customers)
                if let profile = customerProfile {
                    HStack(spacing: 12) {
                        Group {
                            if let pictureUrl = profile.profilePictureUrl,
                               let url = URL(string: pictureUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 40, height: 40)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                    case .failure:
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.blue)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName)
                                .font(.headline)
                            
                            if profile.userType != .pilot,
                               let callSign = profile.callSign,
                               !callSign.isEmpty {
                                Text("@\(callSign)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            Text(booking.locationName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                }
                
                // Messages List
                ScrollViewReader { proxy in
                    GeometryReader { geometry in
                        ZStack(alignment: .topLeading) {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    if messageService.isLoading && messageService.messages.isEmpty {
                                        ProgressView()
                                            .padding()
                                    } else if messageService.messages.isEmpty {
                                        VStack(spacing: 8) {
                                            Image(systemName: "message.fill")
                                                .font(.system(size: 40))
                                                .foregroundColor(.secondary)
                                            Text("No messages yet")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.top, 40)
                                    } else {
                                        ForEach(messageService.messages) { message in
                                            MessageBubble(
                                                message: message,
                                                isFromCurrentUser: message.fromUserId == currentUserId,
                                                currentUserId: currentUserId,
                                                onLongPress: presentReactionPicker(for:)
                                            )
                                        }
                                    }
                                }
                                .padding()
                            }
                            .coordinateSpace(name: MessageReactionOverlayLayout.coordinateSpaceName)
                            .disabled(selectedReactionMessageId != nil)

                            if let selectedReactionMessage,
                               let frame = messageBubbleFrames[selectedReactionMessage.id] {
                                MessageReactionPickerOverlay(
                                    currentReaction: selectedReactionMessage.reactions.currentReaction(for: currentUserId),
                                    targetFrame: frame,
                                    containerSize: geometry.size,
                                    onSelect: { reaction in
                                        handleBookingReactionSelection(reaction, for: selectedReactionMessage.id)
                                    },
                                    onClear: {
                                        handleBookingReactionClear(for: selectedReactionMessage.id)
                                    },
                                    onDismiss: dismissReactionPicker
                                )
                            }
                        }
                        .onPreferenceChange(MessageBubbleFramePreferenceKey.self) { messageBubbleFrames = $0 }
                    }
                    .onChange(of: messageService.messages.count) { _, _ in
                        if let lastMessage = messageService.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let lastMessage = messageService.messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                
                // Message Input Bar (Uber-style)
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(alignment: .bottom, spacing: 12) {
                        TextField("Type a message", text: $messageText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(1...6)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6))
                            .cornerRadius(20)
                            .focused($isTextFieldFocused)
                        
                        Button(action: {
                            sendMessage()
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                        }
                        .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                }
            }
        }
        .navigationTitle("Message")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage.isEmpty ? "Something went wrong. Please try again." : errorMessage)
        }
        .task {
            if booking.status == .accepted || booking.status == .completed {
                await loadMessages()
            }
        }
    }

    private func presentReactionPicker(for messageId: UUID) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            selectedReactionMessageId = messageId
        }
    }

    private func dismissReactionPicker() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            selectedReactionMessageId = nil
        }
    }
    
    private func loadMessages() async {
        guard let currentUser = authService.currentUser,
              let otherUserId = customerProfile?.id else {
            return
        }
        
        // Determine pilot and customer IDs based on current user
        let (pilotId, customerId): (UUID, UUID)
        if authService.userProfile?.userType == .pilot {
            pilotId = currentUser.id
            customerId = otherUserId
        } else {
            pilotId = otherUserId
            customerId = currentUser.id
        }
        
        do {
            try await messageService.fetchMessages(
                bookingId: booking.id,
                pilotId: pilotId,
                customerId: customerId
            )
            try await messageService.markBookingMessagesAsRead(
                fromUserId: otherUserId,
                toUserId: currentUser.id,
                bookingId: booking.id
            )
        } catch {
            print("Error loading messages: \(error)")
        }
    }
    
    private func sendMessage() {
        // Only allow sending messages for confirmed bookings
        guard booking.status == .accepted || booking.status == .completed,
              let currentUser = authService.currentUser,
              let toUserId = customerProfile?.id,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let textToSend = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        isTextFieldFocused = false
        
        Task {
            do {
                try await messageService.sendMessage(
                    bookingId: booking.id,
                    fromUserId: currentUser.id,
                    toUserId: toUserId,
                    text: textToSend
                )
            } catch {
                print("Error sending message: \(error)")
            }
        }
    }

    private func handleBookingReactionSelection(_ reaction: MessageReactionType, for messageId: UUID) {
        guard let currentUserId else { return }
        dismissReactionPicker()

        Task {
            do {
                try await messageService.setReaction(
                    forBookingMessageId: messageId,
                    by: currentUserId,
                    reaction: reaction
                )
            } catch {
                print("Error setting booking reaction: \(error)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }

    private func handleBookingReactionClear(for messageId: UUID) {
        guard let currentUserId else { return }
        dismissReactionPicker()

        Task {
            do {
                try await messageService.clearReaction(
                    forBookingMessageId: messageId,
                    by: currentUserId
                )
            } catch {
                print("Error clearing booking reaction: \(error)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    let currentUserId: UUID?
    let onLongPress: (UUID) -> Void
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                    .cornerRadius(18)
                    .contentShape(RoundedRectangle(cornerRadius: 18))
                    .captureMessageBubbleFrame(messageId: message.id)
                    .onLongPressGesture {
                        onLongPress(message.id)
                    }

                MessageReactionBadges(
                    reactions: message.reactions,
                    currentUserId: currentUserId
                )
                
                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
}
