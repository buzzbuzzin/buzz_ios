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
    @Environment(\.dismiss) private var dismiss
    let pilotId: UUID
    let pilotProfile: UserProfile
    var initialListing: MarketplaceListingWithSeller? = nil
    var showsDismissButton = false
    @StateObject private var messageService = MessageService()
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var showLimitAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var hasSentListingCard = false

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
                        if messageService.isLoading && messageService.directMessages.isEmpty {
                            ProgressView()
                                .padding()
                        } else if messageService.directMessages.isEmpty {
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
                            ForEach(messageService.directMessages) { message in
                                DirectMessageBubble(
                                    message: message,
                                    isFromCurrentUser: message.fromUserId == currentUserId
                                )
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: messageService.directMessages.count) { _, _ in
                    if let lastMessage = messageService.directMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastMessage = messageService.directMessages.last {
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
        .alert("Message Limit Reached", isPresented: $showLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You've reached the limit of \(maxMessagesBeforeResponse) messages. Please wait for \(pilotProfile.callSign ?? "the pilot") to respond before sending more messages.")
        }
        .alert("Error Sending Message", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage.isEmpty ? "Failed to send message. Please try again." : errorMessage)
        }
        .task {
            await loadMessages()
        }
    }

    private func loadMessages() async {
        guard let currentUserId = currentUserId else {
            return
        }

        do {
            try await messageService.fetchDirectMessages(fromUserId: currentUserId, toUserId: pilotId)
            // Mark messages from partner as read
            try await messageService.markDirectMessagesAsRead(fromUserId: pilotId, toUserId: currentUserId)

            // Auto-send listing card if opening from a marketplace listing
            if let listing = initialListing, !hasSentListingCard {
                hasSentListingCard = true
                let alreadyHasCard = messageService.directMessages.contains { msg in
                    msg.metadata?.listingCard?.listingId == listing.listing.id
                }
                if !alreadyHasCard {
                    try await messageService.sendDirectMessageWithListing(
                        fromUserId: currentUserId,
                        toUserId: pilotId,
                        listing: listing
                    )
                }
            }
        } catch {
            print("Error loading messages: \(error)")
            hasSentListingCard = false
            await MainActor.run {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
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
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Direct Message Bubble

struct DirectMessageBubble: View {
    let message: DirectMessage
    let isFromCurrentUser: Bool

    var body: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            if let listingCard = message.metadata?.listingCard,
               message.metadata?.type == "listing_card" {
                ListingCardBubble(
                    listingCard: listingCard,
                    isFromCurrentUser: isFromCurrentUser
                )
            } else {
                HStack {
                    if isFromCurrentUser {
                        Spacer(minLength: 60)
                    }

                    Text(message.text)
                        .font(.body)
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                        .cornerRadius(18)

                    if !isFromCurrentUser {
                        Spacer(minLength: 60)
                    }
                }
            }

            Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, isFromCurrentUser ? 0 : 4)
        }
    }
}

// MARK: - Listing Card Bubble

struct ListingCardBubble: View {
    let listingCard: DirectMessageListingCard
    let isFromCurrentUser: Bool

    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail image
                if let imageUrl = listingCard.imageUrl,
                   let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 120)
                                .clipped()
                        case .failure:
                            imagePlaceholder
                        default:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                                .background(Color(.systemGray6))
                        }
                    }
                } else {
                    imagePlaceholder
                }

                // Title + Price
                VStack(alignment: .leading, spacing: 4) {
                    Text(listingCard.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack {
                        Text(listingCard.price)
                            .font(.headline)
                            .foregroundColor(.orange)

                        Spacer()

                        if let condition = listingCard.condition {
                            Text(condition)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(10)
            }
            .frame(maxWidth: 240)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )

            if !isFromCurrentUser { Spacer(minLength: 60) }
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 30))
                .foregroundColor(.gray)
        }
        .frame(height: 120)
    }
}
