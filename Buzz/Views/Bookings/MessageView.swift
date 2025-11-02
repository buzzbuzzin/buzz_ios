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
                // Customer Info Header
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
                await loadMessages()
            }
        }
    }
    
    private func loadMessages() async {
        guard let currentUser = authService.currentUser,
              let customerId = customerProfile?.id else {
            return
        }
        
        do {
            try await messageService.fetchMessages(
                bookingId: booking.id,
                pilotId: currentUser.id,
                customerId: customerId
            )
        } catch {
            print("Error loading messages: \(error)")
        }
    }
    
    private func sendMessage() {
        guard let currentUser = authService.currentUser,
              let customerId = customerProfile?.id,
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
                    toUserId: customerId,
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

