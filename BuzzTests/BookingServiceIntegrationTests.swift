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
