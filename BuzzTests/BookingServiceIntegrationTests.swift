//
//  BookingServiceIntegrationTests.swift
//  BuzzTests
//
//  Integration tests for BookingService calling real Supabase.
//  Uses the default SupabaseBookingBackend (real DB) but mocks
//  NotificationManager to avoid crashes in the test host.
//

import XCTest
import CoreLocation
import Supabase
@testable import Buzz

@MainActor
final class BookingServiceIntegrationTests: IntegrationTestCase {

    private var service: BookingService!

    override func setUp() async throws {
        try await super.setUp()
        // Use real backend (nil = SupabaseBookingBackend), but mock notifications
        // to prevent NotificationManager.shared crash in test host.
        service = BookingService(
            backend: nil,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )
    }

    override func tearDown() async throws {
        service = nil
        try await super.tearDown()
    }

    // MARK: - Create Booking

    func testCreateBooking_insertsAndReturns() async throws {
        let booking = try await service.createBooking(
            customerId: TestUser.id,
            location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            locationName: "Integration Test Location",
            scheduledDate: nil,
            specialization: .realEstate,
            description: "Integration test booking",
            paymentAmount: 50,
            estimatedFlightHours: 1.0
        )

        trackForCleanup(table: "bookings", id: booking.id)

        XCTAssertEqual(booking.customerId, TestUser.id)
        XCTAssertEqual(booking.locationName, "Integration Test Location")
        XCTAssertEqual(booking.status, .available)
        XCTAssertEqual(booking.specialization, .realEstate)
        XCTAssertFalse(service.isLoading)
        XCTAssertNil(service.errorMessage)
    }

    func testCreateBooking_coordinatesAreStored() async throws {
        let booking = try await service.createBooking(
            customerId: TestUser.id,
            location: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            locationName: "NYC Test",
            scheduledDate: nil,
            specialization: nil,
            description: "Coordinate test",
            paymentAmount: 100,
            estimatedFlightHours: 2.0
        )

        trackForCleanup(table: "bookings", id: booking.id)

        XCTAssertEqual(booking.locationLat, 40.7128, accuracy: 0.001)
        XCTAssertEqual(booking.locationLng, -74.0060, accuracy: 0.001)
    }

    func testCreateSearchRescueBooking_storesCorrectFields() async throws {
        let booking = try await service.createSearchRescueBooking(
            customerId: TestUser.id,
            location: CLLocationCoordinate2D(latitude: 35.0, longitude: -120.0),
            locationName: "SAR Test Location",
            scheduledDate: nil,
            description: "SAR integration test",
            isVoluntary: false,
            hourlyRate: 30,
            estimatedFlightHours: 3.0,
            assignmentType: .airSearch,
            governmentAgency: .fireDepartment,
            usesBeaconProgram: true,
            requiredMinimumRank: 1,
            numberOfPilots: 2
        )

        trackForCleanup(table: "bookings", id: booking.id)

        XCTAssertEqual(booking.specialization, .searchRescue)
        XCTAssertEqual(booking.status, .available)
        XCTAssertFalse(service.isLoading)
    }

    // MARK: - Expiration Field Integration

    func testCreateBooking_setsExpiresAtField() async throws {
        let beforeCreate = Date()
        let booking = try await service.createBooking(
            customerId: TestUser.id,
            location: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0),
            locationName: "Expiry Integration Test",
            scheduledDate: nil,
            specialization: .realEstate,
            description: "Test expiration",
            paymentAmount: 50,
            estimatedFlightHours: 1.0
        )

        trackForCleanup(table: "bookings", id: booking.id)

        // Fetch back and verify expires_at is set
        let fetched: Booking = try await supabase
            .from("bookings")
            .select()
            .eq("id", value: booking.id.uuidString)
            .single()
            .execute()
            .value

        XCTAssertNotNil(fetched.expiresAt, "expires_at should be set on creation")
        XCTAssertEqual(fetched.expirationNotified, false, "expiration_notified should be false")

        // Without scheduledDate, expires_at should be ~7 days from creation
        if let expiresAt = fetched.expiresAt {
            let expectedExpiry = beforeCreate.addingTimeInterval(7 * 24 * 60 * 60)
            let diff = abs(expiresAt.timeIntervalSince(expectedExpiry))
            XCTAssertLessThan(diff, 10.0, "expires_at should be ~7 days from creation")
        }
    }

    func testCreateBookingWithScheduledDate_setsExpiresAtToScheduledDate() async throws {
        let scheduledDate = Date().addingTimeInterval(3 * 24 * 60 * 60) // 3 days from now
        let booking = try await service.createBooking(
            customerId: TestUser.id,
            location: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0),
            locationName: "Scheduled Expiry Integration",
            scheduledDate: scheduledDate,
            specialization: .realEstate,
            description: "Test scheduled expiration",
            paymentAmount: 50,
            estimatedFlightHours: 1.0
        )

        trackForCleanup(table: "bookings", id: booking.id)

        let fetched: Booking = try await supabase
            .from("bookings")
            .select()
            .eq("id", value: booking.id.uuidString)
            .single()
            .execute()
            .value

        XCTAssertNotNil(fetched.expiresAt, "expires_at should be set")
        // expires_at should match scheduledDate (within a few seconds of precision)
        if let expiresAt = fetched.expiresAt {
            let diff = abs(expiresAt.timeIntervalSince(scheduledDate))
            XCTAssertLessThan(diff, 5.0, "expires_at should match scheduledDate")
        }
    }

    // MARK: - State Transition Integration

    func testBookingStatusTransition_availableToAccepted() async throws {
        // Create a booking
        let booking = try await service.createBooking(
            customerId: TestUser.id,
            location: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0),
            locationName: "State Transition Test",
            scheduledDate: Date().addingTimeInterval(86400),
            specialization: .realEstate,
            description: "Accept flow test",
            paymentAmount: 50,
            estimatedFlightHours: 1.0
        )
        trackForCleanup(table: "bookings", id: booking.id)
        XCTAssertEqual(booking.status, .available)

        // Accept the booking
        try await service.acceptBooking(bookingId: booking.id, pilotId: TestUser.id)

        let fetched: Booking = try await supabase
            .from("bookings")
            .select()
            .eq("id", value: booking.id.uuidString)
            .single()
            .execute()
            .value

        XCTAssertEqual(fetched.status, .accepted)
        XCTAssertEqual(fetched.pilotId, TestUser.id)
    }

    func testBookingStatusTransition_acceptedToInProgress() async throws {
        // Create and accept a booking
        let booking = try await service.createBooking(
            customerId: TestUser.id,
            location: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0),
            locationName: "In Progress Test",
            scheduledDate: Date().addingTimeInterval(86400),
            specialization: .realEstate,
            description: "In progress flow test",
            paymentAmount: 50,
            estimatedFlightHours: 1.0
        )
        trackForCleanup(table: "bookings", id: booking.id)

        try await service.acceptBooking(bookingId: booking.id, pilotId: TestUser.id)

        // Transition to in_progress
        try await service.startBookingInProgress(bookingId: booking.id)

        let fetched: Booking = try await supabase
            .from("bookings")
            .select()
            .eq("id", value: booking.id.uuidString)
            .single()
            .execute()
            .value

        XCTAssertEqual(fetched.status, .inProgress)
    }

    func testExtendBooking_updatesExpiresAt() async throws {
        let booking = try await service.createBooking(
            customerId: TestUser.id,
            location: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0),
            locationName: "Extend Test",
            scheduledDate: nil,
            specialization: .realEstate,
            description: "Extend booking test",
            paymentAmount: 50,
            estimatedFlightHours: 1.0
        )
        trackForCleanup(table: "bookings", id: booking.id)

        // Extend with a new date 14 days from now
        let newDate = Date().addingTimeInterval(14 * 24 * 60 * 60)
        try await service.extendBooking(bookingId: booking.id, newScheduledDate: newDate, newEndDate: nil)

        let fetched: Booking = try await supabase
            .from("bookings")
            .select()
            .eq("id", value: booking.id.uuidString)
            .single()
            .execute()
            .value

        XCTAssertNotNil(fetched.expiresAt)
        XCTAssertEqual(fetched.expirationNotified, false, "expiration_notified should be reset")
        if let expiresAt = fetched.expiresAt {
            let diff = abs(expiresAt.timeIntervalSince(newDate))
            XCTAssertLessThan(diff, 5.0, "expires_at should match newScheduledDate")
        }
    }

    // MARK: - Original Tests

    func testCreateBooking_fetchBackVerifiesMatch() async throws {
        let booking = try await service.createBooking(
            customerId: TestUser.id,
            location: CLLocationCoordinate2D(latitude: 33.0, longitude: -117.0),
            locationName: "Fetch Back Test",
            scheduledDate: nil,
            specialization: .inspections,
            description: "Verify round-trip",
            paymentAmount: 75,
            estimatedFlightHours: 1.5
        )

        trackForCleanup(table: "bookings", id: booking.id)

        // Fetch the same booking directly from Supabase to verify it was persisted
        let fetched: Booking = try await supabase
            .from("bookings")
            .select()
            .eq("id", value: booking.id.uuidString)
            .single()
            .execute()
            .value

        XCTAssertEqual(fetched.id, booking.id)
        XCTAssertEqual(fetched.customerId, TestUser.id)
        XCTAssertEqual(fetched.locationName, "Fetch Back Test")
        XCTAssertEqual(fetched.specialization, .inspections)
    }
}
