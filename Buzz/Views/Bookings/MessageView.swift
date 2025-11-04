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
    let customerProfile: UserProfile?
    let booking: Booking
    @StateObject private var messageService = MessageService()
    @Environment(\.dismiss) var dismiss
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
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
                            Text(profile.fullName)
                                .font(.headline)
                            
                            // Show call sign for pilots
                            if let callSign = profile.callSign {
                                Text(callSign)
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
                                        isFromCurrentUser: message.fromUserId == authService.currentUser?.id
                                    )
                                }
                            }
                        }
                        .padding()
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
                    
                    HStack(spacing: 12) {
                        TextField("Type a message", text: $messageText)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6))
                            .cornerRadius(20)
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                sendMessage()
                            }
                        
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                if booking.status == .accepted || booking.status == .completed {
                    await loadMessages()
                }
            }
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
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    
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

