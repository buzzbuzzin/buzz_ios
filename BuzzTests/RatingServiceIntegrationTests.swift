//
//  RatingServiceIntegrationTests.swift
//  BuzzTests
//
//  Integration tests for RatingService calling real Supabase.
//

import XCTest
import CoreLocation
@testable import Buzz

@MainActor
final class RatingServiceIntegrationTests: IntegrationTestCase {

    private var ratingService: RatingService!
    private var bookingService: BookingService!

    override func setUp() async throws {
        try await super.setUp()
        ratingService = RatingService()
        // BookingService with mock notifications to avoid crash
        bookingService = BookingService(
            backend: nil,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )
    }

    override func tearDown() async throws {
        ratingService = nil
        bookingService = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a real booking in Supabase and tracks it for cleanup.
    /// Returns the booking ID to use as a FK for ratings.
    private func createTestBooking() async throws -> UUID {
        let booking = try await bookingService.createBooking(
            customerId: TestUser.id,
            location: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            locationName: "Rating Test Booking",
            scheduledDate: nil,
            specialization: .realEstate,
            description: "Temporary booking for rating test",
            paymentAmount: 10,
            estimatedFlightHours: 1.0
        )
        trackForCleanup(table: "bookings", id: booking.id)
        return booking.id
    }

    // MARK: - Submit & Fetch

    func testSubmitAndFetchRating() async throws {
        let bookingId = try await createTestBooking()

        try await ratingService.submitRating(
            bookingId: bookingId,
            fromUserId: TestUser.id,
            toUserId: TestUser.id,
            rating: 5,
            comment: "Integration test rating"
        )

        // Fetch it back
        let ratings = try await ratingService.fetchRatingsForUser(userId: TestUser.id)
        let testRating = ratings.first { $0.bookingId == bookingId }

        XCTAssertNotNil(testRating, "Should find the rating we just submitted")
        XCTAssertEqual(testRating?.rating, 5)
        XCTAssertEqual(testRating?.comment, "Integration test rating")

        if let foundRating = testRating {
            trackForCleanup(table: "ratings", id: foundRating.id)
        }
    }

    func testFetchRatingsForUser_returnsArray() async throws {
        let ratings = try await ratingService.fetchRatingsForUser(userId: TestUser.id)
        XCTAssertNotNil(ratings)
    }

    func testGetUserRatingSummary() async throws {
        let bookingId1 = try await createTestBooking()
        let bookingId2 = try await createTestBooking()

        try await ratingService.submitRating(
            bookingId: bookingId1,
            fromUserId: TestUser.id,
            toUserId: TestUser.id,
            rating: 4,
            comment: "Test rating 1"
        )
        try await ratingService.submitRating(
            bookingId: bookingId2,
            fromUserId: TestUser.id,
            toUserId: TestUser.id,
            rating: 5,
            comment: "Test rating 2"
        )

        // Track ratings for cleanup
        let allRatings = try await ratingService.fetchRatingsForUser(userId: TestUser.id)
        for r in allRatings where r.bookingId == bookingId1 || r.bookingId == bookingId2 {
            trackForCleanup(table: "ratings", id: r.id)
        }

        let summary = try await ratingService.getUserRatingSummary(userId: TestUser.id)
        XCTAssertNotNil(summary)
        XCTAssertGreaterThanOrEqual(summary!.totalRatings, 2)
    }

    func testHasRated_trueAfterSubmit() async throws {
        let bookingId = try await createTestBooking()

        try await ratingService.submitRating(
            bookingId: bookingId,
            fromUserId: TestUser.id,
            toUserId: TestUser.id,
            rating: 3,
            comment: "hasRated test"
        )

        // Track for cleanup
        let allRatings = try await ratingService.fetchRatingsForUser(userId: TestUser.id)
        for r in allRatings where r.bookingId == bookingId {
            trackForCleanup(table: "ratings", id: r.id)
        }

        let result = try await ratingService.hasRated(bookingId: bookingId, fromUserId: TestUser.id)
        XCTAssertTrue(result, "hasRated should return true after submitting a rating")
    }

    func testHasRated_falseForRandomBooking() async throws {
        let randomBookingId = UUID()
        let result = try await ratingService.hasRated(bookingId: randomBookingId, fromUserId: TestUser.id)
        XCTAssertFalse(result, "hasRated should return false for a booking we never rated")
    }

    func testSubmitRating_rejectsOutOfRange() async throws {
        do {
            try await ratingService.submitRating(
                bookingId: UUID(),
                fromUserId: TestUser.id,
                toUserId: TestUser.id,
                rating: 6,
                comment: nil
            )
            XCTFail("Expected error for rating > 5")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("between 0 and 5") ||
                          error.localizedDescription.contains("Rating must be"))
        }
    }
}
