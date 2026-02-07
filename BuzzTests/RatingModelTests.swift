//
//  RatingModelTests.swift
//  BuzzTests
//
//  Tests for Rating, RatingWithUser, and UserRatingSummary models.
//

import XCTest
@testable import Buzz

final class RatingModelTests: XCTestCase {

    // MARK: - Rating JSON Decode

    func testRatingDecodesFromJSON() throws {
        let ratingId = UUID()
        let bookingId = UUID()
        let fromUserId = UUID()
        let toUserId = UUID()
        let dateString = "2025-06-15T10:30:00Z"

        let json: [String: Any] = [
            "id": ratingId.uuidString,
            "booking_id": bookingId.uuidString,
            "from_user_id": fromUserId.uuidString,
            "to_user_id": toUserId.uuidString,
            "rating": 5,
            "comment": "Great pilot!",
            "created_at": dateString
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rating = try decoder.decode(Rating.self, from: data)

        XCTAssertEqual(rating.id, ratingId)
        XCTAssertEqual(rating.bookingId, bookingId)
        XCTAssertEqual(rating.fromUserId, fromUserId)
        XCTAssertEqual(rating.toUserId, toUserId)
        XCTAssertEqual(rating.rating, 5)
        XCTAssertEqual(rating.comment, "Great pilot!")
    }

    func testRatingDecodesWithNilComment() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "booking_id": UUID().uuidString,
            "from_user_id": UUID().uuidString,
            "to_user_id": UUID().uuidString,
            "rating": 3,
            "created_at": "2025-01-01T00:00:00Z"
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rating = try decoder.decode(Rating.self, from: data)

        XCTAssertNil(rating.comment)
        XCTAssertEqual(rating.rating, 3)
    }

    // MARK: - UserRatingSummary

    func testUserRatingSummaryDecodesFromJSON() throws {
        let userId = UUID()
        let json: [String: Any] = [
            "user_id": userId.uuidString,
            "average_rating": 4.5,
            "total_ratings": 12
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        let summary = try decoder.decode(UserRatingSummary.self, from: data)

        XCTAssertEqual(summary.userId, userId)
        XCTAssertEqual(summary.averageRating, 4.5, accuracy: 0.01)
        XCTAssertEqual(summary.totalRatings, 12)
    }

    // MARK: - RatingWithUser

    func testRatingWithUser_creation() {
        let rating = Rating(
            id: UUID(), bookingId: UUID(), fromUserId: UUID(),
            toUserId: UUID(), rating: 4, comment: "Good",
            createdAt: Date()
        )
        let profile = MockBackend.sampleProfile()
        let ratingWithUser = RatingWithUser(id: rating.id, rating: rating, raterProfile: profile)

        XCTAssertEqual(ratingWithUser.id, rating.id)
        XCTAssertEqual(ratingWithUser.rating.rating, 4)
        XCTAssertEqual(ratingWithUser.raterProfile.firstName, "Test")
    }
}
