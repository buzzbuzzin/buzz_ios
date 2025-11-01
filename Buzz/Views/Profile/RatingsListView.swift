//
//  RatingsListView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI

struct RatingsListView: View {
    @StateObject private var ratingService = RatingService()
    @StateObject private var profileService = ProfileService()
    
    let userId: UUID
    
    @State private var ratingsWithUsers: [RatingWithUser] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        List {
            if isLoading && ratingsWithUsers.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if ratingsWithUsers.isEmpty {
                EmptyStateView(
                    icon: "star",
                    title: "No Ratings Yet",
                    message: "You haven't received any ratings yet."
                )
            } else {
                ForEach(ratingsWithUsers) { ratingWithUser in
                    RatingRowView(ratingWithUser: ratingWithUser)
                }
            }
        }
        .navigationTitle("Ratings & Reviews")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await loadRatings()
        }
        .task {
            await loadRatings()
        }
    }
    
    private func loadRatings() async {
        isLoading = true
        do {
            ratingsWithUsers = try await ratingService.fetchRatingsWithUsers(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Rating Row View

struct RatingRowView: View {
    let ratingWithUser: RatingWithUser
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Profile Picture
                if let pictureUrl = ratingWithUser.raterProfile.profilePictureUrl,
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
                            Image(systemName: ratingWithUser.raterProfile.userType == .pilot ? "airplane.circle.fill" : "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: ratingWithUser.raterProfile.userType == .pilot ? "airplane.circle.fill" : "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Name
                    Text(ratingWithUser.raterProfile.fullName)
                        .font(.headline)
                    
                    // Date
                    Text(ratingWithUser.rating.createdAt.formatted(date: .long, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Star Rating
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= ratingWithUser.rating.rating ? "star.fill" : "star")
                            .font(.system(size: 14))
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            // Comment
            if let comment = ratingWithUser.rating.comment, !comment.isEmpty {
                Text(comment)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
}

