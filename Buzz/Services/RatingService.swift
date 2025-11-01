//
//  RatingService.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import Supabase
import Combine

@MainActor
class RatingService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    
    // MARK: - Submit Rating
    
    func submitRating(
        bookingId: UUID,
        fromUserId: UUID,
        toUserId: UUID,
        rating: Int,
        comment: String?
    ) async throws {
        isLoading = true
        errorMessage = nil
        
        guard rating >= 0 && rating <= 5 else {
            throw NSError(domain: "RatingService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Rating must be between 0 and 5"])
        }
        
        do {
            let ratingData: [String: AnyJSON] = [
                "id": .string(UUID().uuidString),
                "booking_id": .string(bookingId.uuidString),
                "from_user_id": .string(fromUserId.uuidString),
                "to_user_id": .string(toUserId.uuidString),
                "rating": .integer(rating),
                "comment": comment != nil ? .string(comment!) : .null,
                "created_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            
            try await supabase
                .from("ratings")
                .insert(ratingData)
                .execute()
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Fetch Ratings for User
    
    func fetchRatingsForUser(userId: UUID) async throws -> [Rating] {
        isLoading = true
        errorMessage = nil
        
        do {
            let ratings: [Rating] = try await supabase
                .from("ratings")
                .select()
                .eq("to_user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            isLoading = false
            return ratings
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Fetch Ratings with User Profiles
    
    func fetchRatingsWithUsers(userId: UUID) async throws -> [RatingWithUser] {
        isLoading = true
        errorMessage = nil
        
        do {
            let ratings: [Rating] = try await supabase
                .from("ratings")
                .select()
                .eq("to_user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            // Fetch profiles for all raters
            var ratingsWithUsers: [RatingWithUser] = []
            
            for rating in ratings {
                do {
                    let profile: UserProfile = try await supabase
                        .from("profiles")
                        .select()
                        .eq("id", value: rating.fromUserId.uuidString)
                        .single()
                        .execute()
                        .value
                    
                    ratingsWithUsers.append(RatingWithUser(
                        id: rating.id,
                        rating: rating,
                        raterProfile: profile
                    ))
                } catch {
                    // Skip if profile not found
                    print("Error fetching profile for rating: \(error)")
                }
            }
            
            isLoading = false
            return ratingsWithUsers
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Get User Rating Summary
    
    func getUserRatingSummary(userId: UUID) async throws -> UserRatingSummary? {
        do {
            // Use Supabase RPC or calculate in app
            let ratings: [Rating] = try await supabase
                .from("ratings")
                .select()
                .eq("to_user_id", value: userId.uuidString)
                .execute()
                .value
            
            guard !ratings.isEmpty else {
                return nil
            }
            
            let averageRating = Double(ratings.reduce(0) { $0 + $1.rating }) / Double(ratings.count)
            
            return UserRatingSummary(
                userId: userId,
                averageRating: averageRating,
                totalRatings: ratings.count
            )
        } catch {
            throw error
        }
    }
    
    // MARK: - Check if Rating Exists
    
    func hasRated(bookingId: UUID, fromUserId: UUID) async throws -> Bool {
        do {
            let result = try await supabase
                .from("ratings")
                .select("id", count: .exact)
                .eq("booking_id", value: bookingId.uuidString)
                .eq("from_user_id", value: fromUserId.uuidString)
                .execute()
            
            return (result.count ?? 0) > 0
        } catch {
            throw error
        }
    }
}

