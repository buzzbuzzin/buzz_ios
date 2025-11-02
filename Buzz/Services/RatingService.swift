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
        
        // TODO: DEMO MODE - Replace this sample data with real backend call
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // SAMPLE DATA FOR DEMO PURPOSES - Replace with real Supabase query when ready
        let sampleRatings = createSampleRatingsWithUsers(for: userId)
        
        isLoading = false
        return sampleRatings
        
        /* UNCOMMENT WHEN READY TO USE REAL BACKEND:
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
        */
    }
    
    // MARK: - Sample Data for Demo (Ratings)
    // TODO: Remove this function when connecting to real backend
    
    private func createSampleRatingsWithUsers(for userId: UUID) -> [RatingWithUser] {
        let calendar = Calendar.current
        let now = Date()
        
        // Sample customer profiles who left ratings
        let sampleCustomers = [
            UserProfile(
                id: UUID(),
                userType: .customer,
                firstName: "Sarah",
                lastName: "Johnson",
                callSign: nil,
                email: "sarah.johnson@example.com",
                phone: "+1234567890",
                profilePictureUrl: nil,
                communicationPreference: .email,
                createdAt: now
            ),
            UserProfile(
                id: UUID(),
                userType: .customer,
                firstName: "Michael",
                lastName: "Chen",
                callSign: nil,
                email: "michael.chen@example.com",
                phone: "+1234567891",
                profilePictureUrl: nil,
                communicationPreference: .both,
                createdAt: now
            ),
            UserProfile(
                id: UUID(),
                userType: .customer,
                firstName: "Emily",
                lastName: "Davis",
                callSign: nil,
                email: "emily.davis@example.com",
                phone: "+1234567892",
                profilePictureUrl: nil,
                communicationPreference: .email,
                createdAt: now
            ),
            UserProfile(
                id: UUID(),
                userType: .customer,
                firstName: "Robert",
                lastName: "Taylor",
                callSign: nil,
                email: "robert.taylor@example.com",
                phone: "+1234567893",
                profilePictureUrl: nil,
                communicationPreference: .text,
                createdAt: now
            ),
            UserProfile(
                id: UUID(),
                userType: .customer,
                firstName: "Lisa",
                lastName: "Anderson",
                callSign: nil,
                email: "lisa.anderson@example.com",
                phone: "+1234567894",
                profilePictureUrl: nil,
                communicationPreference: .email,
                createdAt: now
            ),
            UserProfile(
                id: UUID(),
                userType: .customer,
                firstName: "David",
                lastName: "Wilson",
                callSign: nil,
                email: "david.wilson@example.com",
                phone: "+1234567895",
                profilePictureUrl: nil,
                communicationPreference: .both,
                createdAt: now
            )
        ]
        
        // Sample ratings from different customers
        let sampleRatings = [
            Rating(
                id: UUID(),
                bookingId: UUID(),
                fromUserId: sampleCustomers[0].id,
                toUserId: userId,
                rating: 5,
                comment: "Excellent work! Professional, punctual, and delivered stunning aerial footage. Highly recommend!",
                createdAt: calendar.date(byAdding: .day, value: -5, to: now) ?? now
            ),
            Rating(
                id: UUID(),
                bookingId: UUID(),
                fromUserId: sampleCustomers[1].id,
                toUserId: userId,
                rating: 5,
                comment: "Outstanding service! The pilot was very experienced and captured exactly what we needed. Will book again!",
                createdAt: calendar.date(byAdding: .day, value: -12, to: now) ?? now
            ),
            Rating(
                id: UUID(),
                bookingId: UUID(),
                fromUserId: sampleCustomers[2].id,
                toUserId: userId,
                rating: 4,
                comment: "Great quality footage and very responsive. Minor delay but overall excellent experience.",
                createdAt: calendar.date(byAdding: .day, value: -18, to: now) ?? now
            ),
            Rating(
                id: UUID(),
                bookingId: UUID(),
                fromUserId: sampleCustomers[3].id,
                toUserId: userId,
                rating: 5,
                comment: "Professional drone pilot with great attention to detail. The final product exceeded our expectations!",
                createdAt: calendar.date(byAdding: .day, value: -25, to: now) ?? now
            ),
            Rating(
                id: UUID(),
                bookingId: UUID(),
                fromUserId: sampleCustomers[4].id,
                toUserId: userId,
                rating: 5,
                comment: "Fantastic work! Very professional and timely. The aerial shots were perfect for our project.",
                createdAt: calendar.date(byAdding: .day, value: -32, to: now) ?? now
            ),
            Rating(
                id: UUID(),
                bookingId: UUID(),
                fromUserId: sampleCustomers[5].id,
                toUserId: userId,
                rating: 4,
                comment: "Good service overall. Pilot was knowledgeable and delivered quality results.",
                createdAt: calendar.date(byAdding: .day, value: -40, to: now) ?? now
            )
        ]
        
        // Combine ratings with customer profiles
        return sampleRatings.enumerated().map { index, rating in
            RatingWithUser(
                id: rating.id,
                rating: rating,
                raterProfile: sampleCustomers[index]
            )
        }
    }
    
    // MARK: - Get User Rating Summary
    
    func getUserRatingSummary(userId: UUID) async throws -> UserRatingSummary? {
        // TODO: DEMO MODE - Replace this sample data with real backend call
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // SAMPLE DATA FOR DEMO PURPOSES - Replace with real Supabase query when ready
        // Using sample ratings to calculate summary
        let sampleRatings = createSampleRatingsWithUsers(for: userId)
        let ratings = sampleRatings.map { $0.rating }
        
        guard !ratings.isEmpty else {
            return nil
        }
        
        let averageRating = Double(ratings.reduce(0) { $0 + $1.rating }) / Double(ratings.count)
        
        return UserRatingSummary(
            userId: userId,
            averageRating: averageRating,
            totalRatings: ratings.count
        )
        
        /* UNCOMMENT WHEN READY TO USE REAL BACKEND:
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
        */
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

