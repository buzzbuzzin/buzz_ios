//
//  BookingServiceTests.swift
//  BuzzTests
//
//  Created for validating booking creation and acceptance flows.
//

import XCTest
import CoreLocation
@testable import Buzz

@MainActor
final class BookingServiceTests: XCTestCase {
    func testCreateBookingBuildsPayloadAndReturnsBooking() async throws {
        let customerId = UUID()
        let bookingId = UUID()
        let created = MockBackend.sampleBooking(
            id: bookingId,
            customerId: customerId,
            specialization: .realEstate,
            paymentAmount: 10,
            estimatedFlightHours: 1.5
        )

        let backend = MockBackend(createBookingResult: created, fetchBookingResult: created)
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        let result = try await service.createBooking(
            customerId: customerId,
            location: .init(latitude: 1, longitude: 2),
            locationName: "Test",
            scheduledDate: nil,
            specialization: .realEstate,
            description: "desc",
            paymentAmount: 10,
            estimatedFlightHours: 1.5
        )

        XCTAssertEqual(result.id, created.id)
        XCTAssertEqual(backend.capturedPayload["status"]?.stringValue, BookingStatus.available.rawValue)
        XCTAssertEqual(backend.capturedPayload["customer_id"]?.stringValue, customerId.uuidString)
    }

    func testAcceptBookingUpdatesNonAutomotive() async throws {
        let bookingId = UUID()
        let pilotId = UUID()
        let booking = MockBackend.sampleBooking(
            id: bookingId,
            specialization: .realEstate,
            status: .available,
            paymentAmount: 20,
            estimatedFlightHours: 2,
            scheduledDate: Date()
        )

        let backend = MockBackend(
            createBookingResult: booking,
            fetchBookingResult: booking,
            userProfileResult: MockBackend.sampleProfile(id: pilotId)
        )
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        try await service.acceptBooking(bookingId: bookingId, pilotId: pilotId)

        XCTAssertTrue(backend.updateCalled)
        XCTAssertFalse(backend.joinCalled)
        XCTAssertEqual(backend.lastUpdatedValues?["pilot_id"]?.stringValue, pilotId.uuidString)
    }

    func testCreateBookingPayloadIncludesExpiresAt() async throws {
        let booking = MockBackend.sampleBooking()
        let backend = MockBackend(createBookingResult: booking)
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        _ = try await service.createBooking(
            customerId: UUID(),
            location: .init(latitude: 1, longitude: 2),
            locationName: "Expiry Test",
            scheduledDate: nil,
            specialization: .realEstate,
            description: "desc",
            paymentAmount: 10,
            estimatedFlightHours: 1.5
        )

        XCTAssertNotNil(backend.capturedPayload["expires_at"]?.stringValue,
                         "Payload should include expires_at")
    }

    func testCreateBookingPayloadIncludesExpirationNotified() async throws {
        let booking = MockBackend.sampleBooking()
        let backend = MockBackend(createBookingResult: booking)
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        _ = try await service.createBooking(
            customerId: UUID(),
            location: .init(latitude: 1, longitude: 2),
            locationName: "Notified Test",
            scheduledDate: nil,
            specialization: nil,
            description: nil,
            paymentAmount: 10,
            estimatedFlightHours: 1.0
        )

        XCTAssertEqual(backend.capturedPayload["expiration_notified"]?.boolValue, false,
                        "Payload should include expiration_notified = false")
    }

    func testCreateBookingWithScheduledDate_setsExpiresAtToScheduledDate() async throws {
        let scheduledDate = Date().addingTimeInterval(3 * 24 * 60 * 60) // 3 days from now
        let booking = MockBackend.sampleBooking()
        let backend = MockBackend(createBookingResult: booking)
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        _ = try await service.createBooking(
            customerId: UUID(),
            location: .init(latitude: 1, longitude: 2),
            locationName: "Scheduled Expiry Test",
            scheduledDate: scheduledDate,
            specialization: nil,
            description: nil,
            paymentAmount: 50,
            estimatedFlightHours: 1.0
        )

        // When scheduledDate is provided, expires_at should match the scheduledDate
        let expiresAtString = backend.capturedPayload["expires_at"]?.stringValue
        let scheduledDateString = backend.capturedPayload["scheduled_date"]?.stringValue
        XCTAssertNotNil(expiresAtString)
        XCTAssertNotNil(scheduledDateString)
        // Both should encode to the same ISO8601 date
        XCTAssertEqual(expiresAtString, scheduledDateString,
                        "expires_at should match scheduled_date when provided")
    }

    func testCreateBookingWithoutScheduledDate_setsExpiresAt7Days() async throws {
        let beforeCreate = Date()
        let booking = MockBackend.sampleBooking()
        let backend = MockBackend(createBookingResult: booking)
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        _ = try await service.createBooking(
            customerId: UUID(),
            location: .init(latitude: 1, longitude: 2),
            locationName: "No Schedule Expiry Test",
            scheduledDate: nil,
            specialization: nil,
            description: nil,
            paymentAmount: 50,
            estimatedFlightHours: 1.0
        )

        let expiresAtString = backend.capturedPayload["expires_at"]?.stringValue
        XCTAssertNotNil(expiresAtString, "expires_at should be set even without scheduledDate")

        // Parse and verify it's approximately 7 days from now
        let formatter = ISO8601DateFormatter()
        if let expiresAtDate = formatter.date(from: expiresAtString!) {
            let sevenDaysFromBefore = beforeCreate.addingTimeInterval(7 * 24 * 60 * 60)
            let diff = abs(expiresAtDate.timeIntervalSince(sevenDaysFromBefore))
            XCTAssertLessThan(diff, 5.0, "expires_at should be approximately 7 days from creation")
        } else {
            XCTFail("Could not parse expires_at date string: \(expiresAtString!)")
        }
    }

    func testAcceptBookingUsesCrewJoinForAutomotive() async throws {
        let bookingId = UUID()
        let pilotId = UUID()
        let booking = MockBackend.sampleBooking(
            id: bookingId,
            specialization: .automotive,
            status: .available,
            paymentAmount: 20,
            estimatedFlightHours: 2,
            requiredMinimumRank: 1
        )

        let backend = MockBackend(
            createBookingResult: booking,
            fetchBookingResult: booking,
            joinResponse: JoinCrewResponse(success: true, message: nil, crewMember: nil, crewStatus: nil, error: nil)
        )
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        try await service.acceptBooking(bookingId: bookingId, pilotId: pilotId)

        XCTAssertTrue(backend.joinCalled)
        XCTAssertFalse(backend.updateCalled)
    }
}
