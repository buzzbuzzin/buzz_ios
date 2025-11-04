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
                        ForEach(conversations) { conversation in
                            NavigationLink(destination: MessageView(
                                customerProfile: conversation.otherUserProfile,
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
        guard let currentUser = authService.currentUser,
              let userProfile = authService.userProfile else { return }
        
        isLoading = true
        
        // TODO: DEMO MODE - Load sample conversations from bookings
        // In production, this would fetch bookings that have messages
        
        do {
            let isPilot = userProfile.userType == .pilot
            
            // Get user's bookings (accepted and completed)
            try await bookingService.fetchMyBookings(userId: currentUser.id, isPilot: isPilot)
            
            // Create conversation items from bookings
            var items: [ConversationItem] = []
            
            // Only include accepted or completed bookings (confirmed bookings)
            for booking in bookingService.myBookings {
                if booking.status == .accepted || booking.status == .completed {
                    if isPilot {
                        // For pilots: show customer profiles
                        if let customerProfile = profileService.getSampleCustomerProfile(customerId: booking.customerId) {
                            items.append(ConversationItem(
                                id: booking.id,
                                booking: booking,
                                otherUserProfile: customerProfile
                            ))
                        }
                    } else {
                        // For customers: show pilot profiles
                        if let pilotId = booking.pilotId,
                           let pilotProfile = profileService.getSamplePilotProfile(pilotId: pilotId) {
                    items.append(ConversationItem(
                        id: booking.id,
                        booking: booking,
                                otherUserProfile: pilotProfile
                    ))
                        }
                    }
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
    let otherUserProfile: UserProfile // Customer profile for pilots, Pilot profile for customers
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: ConversationItem
    
    var body: some View {
        HStack(spacing: 12) {
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
                    Text(callSign)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
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

