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
