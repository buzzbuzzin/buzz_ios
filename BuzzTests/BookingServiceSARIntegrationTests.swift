//
//  BookingServiceSARIntegrationTests.swift
//  BuzzTests
//
//  Integration tests for Search & Rescue booking flows against real Supabase.
//

import XCTest
import CoreLocation
import Supabase
@testable import Buzz

@MainActor
final class BookingServiceSARIntegrationTests: IntegrationTestCase {

    private var service: BookingService!

    override func setUp() async throws {
        try await super.setUp()
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

    // MARK: - Helpers

    /// Creates an S&R booking and registers it for cleanup.
    private func createSARBooking(numberOfPilots: Int = 1, isVoluntary: Bool = true) async throws -> Booking {
        let booking = try await service.createSearchRescueBooking(
            customerId: TestUser.id,
            location: CLLocationCoordinate2D(latitude: 42.44, longitude: -76.50),
            locationName: "SAR Integration Test",
            scheduledDate: nil,
            description: "SAR integration test booking",
            isVoluntary: isVoluntary,
            hourlyRate: 25,
            estimatedFlightHours: 2.0,
            assignmentType: .airSearch,
            usesBeaconProgram: true,
            numberOfPilots: numberOfPilots
        )
        trackForCleanup(table: "bookings", id: booking.id)
        return booking
    }

    /// Cleans up crew records for a booking.
    private func cleanupCrew(bookingId: UUID) async {
        do {
            let crew: [BookingCrewMember] = try await supabase
                .from("booking_crew")
                .select()
                .eq("booking_id", value: bookingId.uuidString)
                .execute()
                .value
            for member in crew {
                trackForCleanup(table: "booking_crew", id: member.id)
            }
        } catch {
            // Best effort
        }
    }

    // MARK: - Full Lifecycle

    func testSARBooking_joinAndVerifyCrew() async throws {
        let booking = try await createSARBooking(numberOfPilots: 1)
        XCTAssertEqual(booking.status, .available)

        // Join the mission
        let joinResponse = try await service.joinSearchRescueBooking(
            bookingId: booking.id,
            pilotId: TestUser.id
        )
        XCTAssertTrue(joinResponse.success)

        // Clean up crew before booking
        await cleanupCrew(bookingId: booking.id)

        // Verify crew record exists
        let crew: [BookingCrewMember] = try await supabase
            .from("booking_crew")
            .select()
            .eq("booking_id", value: booking.id.uuidString)
            .execute()
            .value

        XCTAssertEqual(crew.count, 1)
        XCTAssertEqual(crew.first?.pilotId, TestUser.id)
    }

    // MARK: - Role Column Validation (catches missing role column bug)

    func testSARBooking_crewRoleIsSetCorrectly() async throws {
        let booking = try await createSARBooking(numberOfPilots: 2)

        let joinResponse = try await service.joinSearchRescueBooking(
            bookingId: booking.id,
            pilotId: TestUser.id
        )
        XCTAssertTrue(joinResponse.success)

        await cleanupCrew(bookingId: booking.id)

        // Verify the role column is populated
        let crew: [BookingCrewMember] = try await supabase
            .from("booking_crew")
            .select()
            .eq("booking_id", value: booking.id.uuidString)
            .execute()
            .value

        XCTAssertEqual(crew.count, 1)
        XCTAssertEqual(crew.first?.role, .crew, "Role should be 'crew' for S&R volunteers")
    }

    // MARK: - Multi-Pilot Status

    func testSARBooking_multiPilotKeepsAvailableUntilFull() async throws {
        let booking = try await createSARBooking(numberOfPilots: 3)

        // Join with 1 pilot (need 3)
        let joinResponse = try await service.joinSearchRescueBooking(
            bookingId: booking.id,
            pilotId: TestUser.id
        )
        XCTAssertTrue(joinResponse.success)

        await cleanupCrew(bookingId: booking.id)

        // Booking should still be available (only 1 of 3 pilots)
        let fetched: Booking = try await supabase
            .from("bookings")
            .select()
            .eq("id", value: booking.id.uuidString)
            .single()
            .execute()
            .value

        XCTAssertEqual(fetched.status, .available, "Status should remain available with only 1 of 3 pilots")
    }

    // MARK: - Double Join Prevention

    func testSARBooking_doubleJoinPrevented() async throws {
        let booking = try await createSARBooking(numberOfPilots: 3)

        // First join should succeed
        let firstJoin = try await service.joinSearchRescueBooking(
            bookingId: booking.id,
            pilotId: TestUser.id
        )
        XCTAssertTrue(firstJoin.success)

        await cleanupCrew(bookingId: booking.id)

        // Second join should fail
        do {
            _ = try await service.joinSearchRescueBooking(
                bookingId: booking.id,
                pilotId: TestUser.id
            )
            XCTFail("Expected error for double join")
        } catch {
            XCTAssertTrue(error.localizedDescription.lowercased().contains("already"),
                          "Error should mention already joined: \(error.localizedDescription)")
        }
    }

    // MARK: - Leave Mission

    func testSARBooking_leaveAfterJoining() async throws {
        let booking = try await createSARBooking(numberOfPilots: 2)

        // Join
        let joinResponse = try await service.joinSearchRescueBooking(
            bookingId: booking.id,
            pilotId: TestUser.id
        )
        XCTAssertTrue(joinResponse.success)

        // Leave
        let leaveResponse = try await service.leaveSearchRescueBooking(
            bookingId: booking.id,
            pilotId: TestUser.id
        )
        XCTAssertTrue(leaveResponse.success)

        await cleanupCrew(bookingId: booking.id)

        // Verify crew is empty
        let crew: [BookingCrewMember] = try await supabase
            .from("booking_crew")
            .select()
            .eq("booking_id", value: booking.id.uuidString)
            .execute()
            .value

        XCTAssertEqual(crew.count, 0, "Crew should be empty after leaving")

        // Verify booking is still available
        let fetched: Booking = try await supabase
            .from("bookings")
            .select()
            .eq("id", value: booking.id.uuidString)
            .single()
            .execute()
            .value

        XCTAssertEqual(fetched.status, .available)
    }

    // MARK: - Crew Limit with Single Pilot

    func testSARBooking_singlePilotFillsCrewAndChangesStatus() async throws {
        let booking = try await createSARBooking(numberOfPilots: 1)

        let joinResponse = try await service.joinSearchRescueBooking(
            bookingId: booking.id,
            pilotId: TestUser.id
        )
        XCTAssertTrue(joinResponse.success)

        await cleanupCrew(bookingId: booking.id)

        // Verify booking status changed (RPC should auto-transition when crew is full)
        let fetched: Booking = try await supabase
            .from("bookings")
            .select()
            .eq("id", value: booking.id.uuidString)
            .single()
            .execute()
            .value

        // When a single-pilot S&R booking is filled, the RPC transitions to accepted
        XCTAssertEqual(fetched.status, .accepted,
                       "Status should change to accepted when single-pilot crew is filled")
    }

    // MARK: - Join Non-S&R Booking Fails

    func testJoinSARBooking_nonSARBookingFails() async throws {
        // Create a regular (non-S&R) booking
        let booking = try await service.createBooking(
            customerId: TestUser.id,
            location: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0),
            locationName: "Non-SAR Test",
            scheduledDate: nil,
            specialization: .realEstate,
            description: "Non-SAR booking",
            paymentAmount: 50,
            estimatedFlightHours: 1.0
        )
        trackForCleanup(table: "bookings", id: booking.id)

        // Attempting to join via S&R RPC should fail
        do {
            _ = try await service.joinSearchRescueBooking(
                bookingId: booking.id,
                pilotId: TestUser.id
            )
            XCTFail("Expected error when joining non-S&R booking via S&R RPC")
        } catch {
            // Expected - the RPC should reject non-S&R bookings
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
}
