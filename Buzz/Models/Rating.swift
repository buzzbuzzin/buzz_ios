//
//  Rating.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation

struct Rating: Codable, Identifiable {
    let id: UUID
    let bookingId: UUID
    let fromUserId: UUID
    let toUserId: UUID
    let rating: Int // 0-5
    let comment: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case bookingId = "booking_id"
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case rating
        case comment
        case createdAt = "created_at"
    }
}

struct RatingWithUser: Identifiable {
    let id: UUID
    let rating: Rating
    let raterProfile: UserProfile
}

struct UserRatingSummary: Codable {
    let userId: UUID
    let averageRating: Double
    let totalRatings: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case averageRating = "average_rating"
        case totalRatings = "total_ratings"
    }
}
