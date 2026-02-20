//
//  BookingServiceExtendedTests.swift
//  BuzzTests
//
//  Extended tests for BookingService using protocol-based dependency injection.
//

import XCTest
import CoreLocation
@testable import Buzz

@MainActor
final class BookingServiceExtendedTests: XCTestCase {

    // MARK: - Create Booking Payload Tests

    func testCreateBookingWithAllOptionalFields() async throws {
        let customerId = UUID()
        let scheduledDate = Date()
        let endDate = Date().addingTimeInterval(3600)
        let booking = MockBackend.sampleBooking(customerId: customerId)
        let backend = MockBackend(createBookingResult: booking)
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        _ = try await service.createBooking(
            customerId: customerId,
            location: .init(latitude: 37.77, longitude: -122.42),
            locationName: "Full Test",
            scheduledDate: scheduledDate,
            endDate: endDate,
            specialization: .motionPicture,
            description: "Full description",
            paymentAmount: 500,
            estimatedFlightHours: 3.0,
            requiredMinimumRank: 2,
            paymentIntentId: "pi_test123",
            chargeId: "ch_test456"
        )

        let payload = backend.capturedPayload
        XCTAssertNotNil(payload["scheduled_date"]?.stringValue)
        XCTAssertNotNil(payload["end_date"]?.stringValue)
        XCTAssertEqual(payload["specialization"]?.stringValue, "motion_picture")
        XCTAssertEqual(payload["description"]?.stringValue, "Full description")
        XCTAssertEqual(payload["payment_intent_id"]?.stringValue, "pi_test123")
        XCTAssertEqual(payload["charge_id"]?.stringValue, "ch_test456")
    }

    func testCreateBookingWithMinimalFields() async throws {
        let customerId = UUID()
        let booking = MockBackend.sampleBooking(customerId: customerId)
        let backend = MockBackend(createBookingResult: booking)
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        _ = try await service.createBooking(
            customerId: customerId,
            location: .init(latitude: 0, longitude: 0),
            locationName: "Minimal",
            scheduledDate: nil,
            specialization: nil,
            description: nil,
            paymentAmount: 50,
            estimatedFlightHours: 1.0
        )

        let payload = backend.capturedPayload
        XCTAssertNil(payload["scheduled_date"])
        XCTAssertNil(payload["specialization"])
        XCTAssertNil(payload["description"])
        XCTAssertNil(payload["payment_intent_id"])
        XCTAssertNil(payload["charge_id"])
    }

    func testCreateBookingPayloadHasCorrectStatus() async throws {
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
            location: .init(latitude: 0, longitude: 0),
            locationName: "Status Test",
            scheduledDate: nil,
            specialization: .realEstate,
            description: nil,
            paymentAmount: 100,
            estimatedFlightHours: 2.0
        )

        XCTAssertEqual(backend.capturedPayload["status"]?.stringValue, "available")
    }

    func testCreateBookingPayloadHasEstimatedFlightHours() async throws {
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
            location: .init(latitude: 0, longitude: 0),
            locationName: "Hours Test",
            scheduledDate: nil,
            specialization: nil,
            description: nil,
            paymentAmount: 100,
            estimatedFlightHours: 4.5
        )

        XCTAssertEqual(backend.capturedPayload["estimated_flight_hours"]?.doubleValue, 4.5)
    }

    func testCreateBookingPayloadHasRequiredMinimumRank() async throws {
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
            location: .init(latitude: 0, longitude: 0),
            locationName: "Rank Test",
            scheduledDate: nil,
            specialization: nil,
            description: nil,
            paymentAmount: 100,
            estimatedFlightHours: 2.0,
            requiredMinimumRank: 3
        )

        XCTAssertEqual(backend.capturedPayload["required_minimum_rank"]?.intValue, 3)
    }

    func testCreateBookingPayloadHasLocationCoordinates() async throws {
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
            location: .init(latitude: 37.7749, longitude: -122.4194),
            locationName: "San Francisco",
            scheduledDate: nil,
            specialization: nil,
            description: nil,
            paymentAmount: 100,
            estimatedFlightHours: 1.0
        )

        XCTAssertEqual(backend.capturedPayload["location_lat"]?.doubleValue, 37.7749)
        XCTAssertEqual(backend.capturedPayload["location_lng"]?.doubleValue, -122.4194)
        XCTAssertEqual(backend.capturedPayload["location_name"]?.stringValue, "San Francisco")
    }

    // MARK: - Search & Rescue Booking Tests

    func testCreateSearchRescueBookingPayloadFields() async throws {
        let customerId = UUID()
        let booking = MockBackend.sampleBooking(customerId: customerId, specialization: .searchRescue)
        let backend = MockBackend(createBookingResult: booking)
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        _ = try await service.createSearchRescueBooking(
            customerId: customerId,
            location: .init(latitude: 37.0, longitude: -122.0),
            locationName: "SAR Location",
            scheduledDate: nil,
            description: "Emergency search",
            isVoluntary: false,
            hourlyRate: 25,
            estimatedFlightHours: 4.0,
            assignmentType: .airSearch,
            governmentAgency: .fireDepartment,
            usesBeaconProgram: true,
            requiredMinimumRank: 1,
            numberOfPilots: 3
        )

        let payload = backend.capturedPayload
        XCTAssertEqual(payload["specialization"]?.stringValue, "search_rescue")
        XCTAssertEqual(payload["is_voluntary"]?.boolValue, false)
        XCTAssertEqual(payload["uses_beacon_program"]?.boolValue, true)
        XCTAssertEqual(payload["number_of_pilots"]?.intValue, 3)
        XCTAssertEqual(payload["assignment_type"]?.stringValue, "air_search")
        XCTAssertEqual(payload["government_agency"]?.stringValue, "fire_department")
    }

    func testCreateSearchRescueBookingCalculatesTotalPayment() async throws {
        let booking = MockBackend.sampleBooking(specialization: .searchRescue)
        let backend = MockBackend(createBookingResult: booking)
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        // hourlyRate=25, estimatedHours=4, numberOfPilots=3 => 25*4*3 = 300
        _ = try await service.createSearchRescueBooking(
            customerId: UUID(),
            location: .init(latitude: 0, longitude: 0),
            locationName: "Payment Test",
            scheduledDate: nil,
            description: "test",
            isVoluntary: false,
            hourlyRate: 25,
            estimatedFlightHours: 4.0,
            numberOfPilots: 3
        )

        let paymentAmount = backend.capturedPayload["payment_amount"]?.doubleValue ?? 0
        XCTAssertEqual(paymentAmount, 300.0, accuracy: 0.01)
    }

    // MARK: - Accept Booking Tests

    func testAcceptBookingNonAutomotiveSetsAcceptedStatus() async throws {
        let bookingId = UUID()
        let pilotId = UUID()
        let booking = MockBackend.sampleBooking(id: bookingId, specialization: .realEstate, scheduledDate: Date())
        let backend = MockBackend(
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
        XCTAssertEqual(backend.lastUpdatedValues?["status"]?.stringValue, "accepted")
        XCTAssertEqual(backend.lastUpdatedValues?["pilot_id"]?.stringValue, pilotId.uuidString)
    }

    func testAcceptBookingSearchRescueUsesCrewJoin() async throws {
        // S&R bookings are NOT crew bookings through isAutomotiveCrewBooking
        // They go through the normal accept path, not joinAutomotiveBooking
        // The actual S&R crew join is a separate method (joinSearchRescueBooking)
        let bookingId = UUID()
        let pilotId = UUID()
        let booking = MockBackend.sampleBooking(id: bookingId, specialization: .searchRescue, scheduledDate: Date())
        let backend = MockBackend(
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

        // S&R goes through update path (not automotive crew join)
        XCTAssertTrue(backend.updateCalled)
        XCTAssertFalse(backend.joinCalled)
    }

    func testAcceptBookingNotifiesOnSuccess() async throws {
        let bookingId = UUID()
        let pilotId = UUID()
        let booking = MockBackend.sampleBooking(id: bookingId, specialization: .realEstate, scheduledDate: Date())
        let backend = MockBackend(
            fetchBookingResult: booking,
            userProfileResult: MockBackend.sampleProfile(id: pilotId)
        )
        let notificationManager = MockNotificationManager()
        let service = BookingService(
            backend: backend,
            notificationManager: notificationManager,
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: false
        )

        try await service.acceptBooking(bookingId: bookingId, pilotId: pilotId)

        XCTAssertEqual(notificationManager.acceptedCalls, 1)
    }

    func testAcceptBookingSchedulesReminderWhenDateProvided() async throws {
        let bookingId = UUID()
        let pilotId = UUID()
        let scheduledDate = Date().addingTimeInterval(86400)
        let booking = MockBackend.sampleBooking(id: bookingId, specialization: .realEstate, scheduledDate: scheduledDate)
        let backend = MockBackend(
            fetchBookingResult: booking,
            userProfileResult: MockBackend.sampleProfile(id: pilotId)
        )
        let notificationManager = MockNotificationManager()
        let service = BookingService(
            backend: backend,
            notificationManager: notificationManager,
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: false
        )

        try await service.acceptBooking(bookingId: bookingId, pilotId: pilotId)

        XCTAssertEqual(notificationManager.reminderCalls, 1)
    }

    // MARK: - Error Handling Tests

    func testCreateBookingSetsErrorOnFailure() async throws {
        let backend = MockBackend()
        backend.shouldThrowOnCreate = true
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        do {
            _ = try await service.createBooking(
                customerId: UUID(),
                location: .init(latitude: 0, longitude: 0),
                locationName: "Error Test",
                scheduledDate: nil,
                specialization: nil,
                description: nil,
                paymentAmount: 100,
                estimatedFlightHours: 1.0
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(service.errorMessage)
            XCTAssertFalse(service.isLoading)
        }
    }

    func testAcceptBookingErrorOnFetchFailure() async throws {
        let backend = MockBackend()
        backend.shouldThrowOnFetch = true
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        do {
            try await service.acceptBooking(bookingId: UUID(), pilotId: UUID())
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(service.errorMessage)
            XCTAssertFalse(service.isLoading)
        }
    }

    func testAcceptBookingErrorOnUpdateFailure() async throws {
        let booking = MockBackend.sampleBooking(specialization: .realEstate)
        let backend = MockBackend(fetchBookingResult: booking)
        backend.shouldThrowOnUpdate = true
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        do {
            try await service.acceptBooking(bookingId: UUID(), pilotId: UUID())
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(service.errorMessage)
            XCTAssertFalse(service.isLoading)
        }
    }

    // MARK: - Join Automotive Booking Tests

    func testJoinAutomotiveBookingReturnsResponse() async throws {
        let crewMember = JoinedCrewMemberInfo(id: UUID(), role: "crew", rank: "Lieutenant", payoutAmount: 50)
        let crewStatus = CrewStatusInfo(currentCount: 2, maxCount: 4, hasQualifiedLead: true, bookingAccepted: false)
        let joinResponse = JoinCrewResponse(
            success: true,
            message: "Joined crew",
            crewMember: crewMember,
            crewStatus: crewStatus,
            error: nil
        )
        let backend = MockBackend(joinResponse: joinResponse)
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        let result = try await service.joinAutomotiveBooking(bookingId: UUID(), pilotId: UUID())

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.message, "Joined crew")
        XCTAssertEqual(result.crewMember?.role, "crew")
        XCTAssertEqual(result.crewStatus?.currentCount, 2)
        XCTAssertEqual(result.crewStatus?.maxCount, 4)
    }

    func testJoinAutomotiveBookingThrowsOnErrorResponse() async throws {
        let joinResponse = JoinCrewResponse(
            success: false,
            message: nil,
            crewMember: nil,
            crewStatus: nil,
            error: "Crew is full"
        )
        let backend = MockBackend(joinResponse: joinResponse)
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        do {
            _ = try await service.joinAutomotiveBooking(bookingId: UUID(), pilotId: UUID())
            XCTFail("Expected error to be thrown")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.localizedDescription, "Crew is full")
        }
    }

    // MARK: - Loading State Tests

    func testCreateBookingResetsLoadingOnSuccess() async throws {
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
            location: .init(latitude: 0, longitude: 0),
            locationName: "Loading Test",
            scheduledDate: nil,
            specialization: nil,
            description: nil,
            paymentAmount: 100,
            estimatedFlightHours: 1.0
        )

        XCTAssertFalse(service.isLoading)
        XCTAssertNil(service.errorMessage)
    }

    // MARK: - Expiration Payload Tests

    func testCreateBookingPayloadHasExpiresAtWithScheduledDate() async throws {
        let scheduledDate = Date().addingTimeInterval(48 * 60 * 60) // 2 days out
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
            location: .init(latitude: 0, longitude: 0),
            locationName: "Expiry With Schedule",
            scheduledDate: scheduledDate,
            specialization: nil,
            description: nil,
            paymentAmount: 100,
            estimatedFlightHours: 1.0
        )

        let payload = backend.capturedPayload
        // expires_at should be set to the scheduled date
        let expiresAtStr = payload["expires_at"]?.stringValue
        let scheduledDateStr = payload["scheduled_date"]?.stringValue
        XCTAssertNotNil(expiresAtStr)
        XCTAssertEqual(expiresAtStr, scheduledDateStr,
                        "expires_at should equal scheduled_date when provided")
        XCTAssertEqual(payload["expiration_notified"]?.boolValue, false)
    }

    func testCreateBookingPayloadHasExpiresAtWithout_ScheduledDate() async throws {
        let booking = MockBackend.sampleBooking()
        let backend = MockBackend(createBookingResult: booking)
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        let beforeCreate = Date()
        _ = try await service.createBooking(
            customerId: UUID(),
            location: .init(latitude: 0, longitude: 0),
            locationName: "Expiry No Schedule",
            scheduledDate: nil,
            specialization: nil,
            description: nil,
            paymentAmount: 100,
            estimatedFlightHours: 1.0
        )

        let payload = backend.capturedPayload
        XCTAssertNil(payload["scheduled_date"], "No scheduled_date in payload when nil")
        let expiresAtStr = payload["expires_at"]?.stringValue
        XCTAssertNotNil(expiresAtStr, "expires_at should still be set")

        // Verify ~7 days from now
        if let expiresAtDate = ISO8601DateFormatter().date(from: expiresAtStr!) {
            let expected = beforeCreate.addingTimeInterval(7 * 24 * 60 * 60)
            let diff = abs(expiresAtDate.timeIntervalSince(expected))
            XCTAssertLessThan(diff, 5.0, "expires_at should be ~7 days from creation")
        }
    }

    func testSearchRescueBookingPayloadHasExpiration() async throws {
        let booking = MockBackend.sampleBooking(specialization: .searchRescue)
        let backend = MockBackend(createBookingResult: booking)
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        _ = try await service.createSearchRescueBooking(
            customerId: UUID(),
            location: .init(latitude: 0, longitude: 0),
            locationName: "SAR Expiry Test",
            scheduledDate: nil,
            description: "test",
            isVoluntary: false,
            hourlyRate: 25,
            estimatedFlightHours: 2.0
        )

        let payload = backend.capturedPayload
        XCTAssertNotNil(payload["expires_at"]?.stringValue, "SAR booking should have expires_at")
        XCTAssertEqual(payload["expiration_notified"]?.boolValue, false)
    }

    // MARK: - Demo Mode Tests

    func testStartBookingInProgress_demoMode_returnsWithoutError() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true
        defer { DemoModeManager.shared.isDemoModeEnabled = false }

        let service = BookingService(
            backend: MockBackend(),
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        // Should not throw in demo mode
        try await service.startBookingInProgress(bookingId: UUID())
        XCTAssertFalse(service.isLoading)
    }

    func testMarkSearchRescueAsStaffed_demoMode_returnsWithoutError() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true
        defer { DemoModeManager.shared.isDemoModeEnabled = false }

        let service = BookingService(
            backend: MockBackend(),
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        try await service.markSearchRescueAsStaffed(bookingId: UUID())
        XCTAssertFalse(service.isLoading)
    }

    func testExtendBooking_demoMode_returnsWithoutError() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true
        defer { DemoModeManager.shared.isDemoModeEnabled = false }

        let service = BookingService(
            backend: MockBackend(),
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        try await service.extendBooking(
            bookingId: UUID(),
            newScheduledDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
            newEndDate: nil
        )
        XCTAssertFalse(service.isLoading)
    }

    func testCreateDispute_demoMode_returnsDemoDispute() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true
        defer { DemoModeManager.shared.isDemoModeEnabled = false }

        let service = BookingService(
            backend: MockBackend(),
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        let bookingId = UUID()
        let dispute = try await service.createDispute(
            bookingId: bookingId,
            reason: "quality_issue",
            description: "Demo test"
        )

        XCTAssertEqual(dispute.bookingId, bookingId)
        XCTAssertEqual(dispute.reason, "quality_issue")
        XCTAssertEqual(dispute.status, .open)
        XCTAssertFalse(service.isLoading)
    }

    func testFetchDisputesForBooking_demoMode_returnsEmptyArray() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true
        defer { DemoModeManager.shared.isDemoModeEnabled = false }

        let service = BookingService(
            backend: MockBackend(),
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        let disputes = try await service.fetchDisputesForBooking(bookingId: UUID())
        XCTAssertTrue(disputes.isEmpty)
    }

    func testFetchMyDisputes_demoMode_setsEmptyDisputes() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true
        defer { DemoModeManager.shared.isDemoModeEnabled = false }

        let service = BookingService(
            backend: MockBackend(),
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        try await service.fetchMyDisputes()
        XCTAssertTrue(service.disputes.isEmpty)
        XCTAssertFalse(service.isLoading)
    }

    func testResolveDispute_demoMode_returnsWithoutError() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true
        defer { DemoModeManager.shared.isDemoModeEnabled = false }

        let service = BookingService(
            backend: MockBackend(),
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        try await service.resolveDispute(disputeId: UUID(), resolution: "Demo resolution")
        XCTAssertFalse(service.isLoading)
    }

    func testCheckAndExpireBookings_demoMode_returnsWithoutError() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true
        defer { DemoModeManager.shared.isDemoModeEnabled = false }

        let service = BookingService(
            backend: MockBackend(),
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        try await service.checkAndExpireBookings()
        // Should return immediately in demo mode without error
    }

    func testNotifyExpiringBookings_demoMode_returnsWithoutError() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true
        defer { DemoModeManager.shared.isDemoModeEnabled = false }

        let service = BookingService(
            backend: MockBackend(),
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        try await service.notifyExpiringBookings()
        // Should return immediately in demo mode without error
    }

    // MARK: - Empty Description Tests

    func testCreateBookingDescriptionNotIncludedWhenEmpty() async throws {
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
            location: .init(latitude: 0, longitude: 0),
            locationName: "Empty Desc",
            scheduledDate: nil,
            specialization: nil,
            description: "",
            paymentAmount: 100,
            estimatedFlightHours: 1.0
        )

        // Empty string description should not be included in payload
        XCTAssertNil(backend.capturedPayload["description"])
    }
}
