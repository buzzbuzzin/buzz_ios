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
    @State private var conversations: [ConversationItem] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    LoadingView(message: "Loading conversations...")
                } else if conversations.isEmpty {
                    EmptyStateView(
                        icon: "message.fill",
                        title: "No Conversations",
                        message: "Start messaging customers from booking details"
                    )
                } else {
                    List {
                        ForEach(conversations) { conversation in
                            NavigationLink(destination: MessageView(
                                customerProfile: conversation.customerProfile,
                                booking: conversation.booking
                            )) {
                                ConversationRow(conversation: conversation)
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
        }
    }
    
    private func loadConversations() async {
        guard let currentUser = authService.currentUser else { return }
        
        isLoading = true
        
        // TODO: DEMO MODE - Load sample conversations from pilot's bookings
        // In production, this would fetch bookings that have messages
        
        do {
            // Get pilot's bookings (accepted and completed)
            try await bookingService.fetchMyBookings(userId: currentUser.id, isPilot: true)
            
            // Create conversation items from bookings
            var items: [ConversationItem] = []
            
            // Only include accepted or completed bookings (confirmed bookings)
            for booking in bookingService.myBookings {
                if (booking.status == .accepted || booking.status == .completed),
                   let customerProfile = profileService.getSampleCustomerProfile(customerId: booking.customerId) {
                    items.append(ConversationItem(
                        id: booking.id,
                        booking: booking,
                        customerProfile: customerProfile
                    ))
                }
            }
            
            conversations = items
            isLoading = false
        } catch {
            isLoading = false
            print("Error loading conversations: \(error)")
        }
    }
}

// MARK: - Conversation Item

struct ConversationItem: Identifiable {
    let id: UUID
    let booking: Booking
    let customerProfile: UserProfile
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: ConversationItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Customer Profile Picture
            Group {
                if let pictureUrl = conversation.customerProfile.profilePictureUrl,
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
                Text(conversation.customerProfile.fullName)
                    .font(.headline)
                
                Text(conversation.booking.locationName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text("Tap to view messages")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            // Message Icon
            Image(systemName: "message.fill")
                .foregroundColor(.blue)
                .font(.title3)
        }
        .padding(.vertical, 8)
    }
}

