//
//  DirectMessageView.swift
//  Buzz
//
//  Created for direct messaging between users
//

import SwiftUI
import Auth

struct DirectMessageView: View {
    @EnvironmentObject var authService: AuthService
    let pilotId: UUID
    let pilotProfile: UserProfile
    @StateObject private var messageService = MessageService()
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var showLimitAlert = false
    
    private let maxMessagesBeforeResponse = 3
    
    var currentUserId: UUID? {
        authService.currentUser?.id
    }
    
    var sentMessageCount: Int {
        guard let currentUserId = currentUserId else { return 0 }
        return messageService.countSentMessagesBeforeResponse(fromUserId: currentUserId, toUserId: pilotId)
    }
    
    var hasResponse: Bool {
        guard let currentUserId = currentUserId else { return false }
        return messageService.hasResponse(fromUserId: currentUserId, toUserId: pilotId)
    }
    
    var canSendMessage: Bool {
        if hasResponse {
            return true // Unlimited after response
        }
        return sentMessageCount < maxMessagesBeforeResponse
    }
    
    var remainingMessages: Int {
        if hasResponse {
            return -1 // Unlimited
        }
        return max(0, maxMessagesBeforeResponse - sentMessageCount)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Pilot Info Header
                HStack(spacing: 12) {
                    Group {
                        if let pictureUrl = pilotProfile.profilePictureUrl,
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
                                    Image(systemName: "airplane.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.blue)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Image(systemName: "airplane.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let callSign = pilotProfile.callSign {
                            Text("@\(callSign)")
                                .font(.headline)
                                .foregroundColor(.primary)
                        } else {
                            Text("Pilot")
                                .font(.headline)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                
                // Message Limit Warning (only show if limit applies)
                if !hasResponse && sentMessageCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("You can send \(remainingMessages) more message\(remainingMessages == 1 ? "" : "s") before \(pilotProfile.callSign ?? "the pilot") responds.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
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
                                    
                                    if !hasResponse {
                                        Text("You can send up to \(maxMessagesBeforeResponse) messages before \(pilotProfile.callSign ?? "the pilot") responds.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                            .padding(.top, 4)
                                    }
                                }
                                .padding(.top, 40)
                            } else {
                                ForEach(messageService.messages) { message in
                                    MessageBubble(
                                        message: message,
                                        isFromCurrentUser: message.fromUserId == currentUserId
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
                
                // Message Input Bar
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
                            .disabled(!canSendMessage)
                        
                        Button(action: {
                            if canSendMessage {
                                sendMessage()
                            } else {
                                showLimitAlert = true
                            }
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(
                                    canSendMessage && !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? .blue
                                        : .gray
                                )
                        }
                        .disabled(
                            !canSendMessage || messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Message Limit Reached", isPresented: $showLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You've reached the limit of \(maxMessagesBeforeResponse) messages. Please wait for \(pilotProfile.callSign ?? "the pilot") to respond before sending more messages.")
            }
            .task {
                await loadMessages()
            }
        }
    }
    
    private func loadMessages() async {
        guard let currentUserId = currentUserId else {
            return
        }
        
        do {
            try await messageService.fetchDirectMessages(fromUserId: currentUserId, toUserId: pilotId)
        } catch {
            print("Error loading messages: \(error)")
        }
    }
    
    private func sendMessage() {
        guard let currentUserId = currentUserId,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              canSendMessage else {
            if !canSendMessage {
                showLimitAlert = true
            }
            return
        }
        
        let textToSend = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        isTextFieldFocused = false
        
        Task {
            do {
                try await messageService.sendDirectMessage(
                    fromUserId: currentUserId,
                    toUserId: pilotId,
                    text: textToSend
                )
            } catch {
                print("Error sending message: \(error)")
            }
        }
    }
}

