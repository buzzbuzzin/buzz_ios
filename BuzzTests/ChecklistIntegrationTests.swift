//
//  ChecklistIntegrationTests.swift
//  BuzzTests
//
//  Integration tests that exercise the booking checklist lifecycle against
//  production Supabase: create a test booking, toggle checklist items,
//  verify persistence, and clean up.
//

import XCTest
import Supabase
@testable import Buzz

@MainActor
final class ChecklistIntegrationTests: IntegrationTestCase {

    // MARK: - Helpers

    /// Creates a test booking owned by the test user and returns its ID.
    private func createTestBooking() async throws -> UUID {
        let bookingId = UUID()

        let booking: [String: AnyJSON] = [
            "id": .string(bookingId.uuidString),
            "customer_id": .string(TestUser.id.uuidString),
            "pilot_id": .string(TestUser.id.uuidString),
            "location_lat": .double(37.7749),
            "location_lng": .double(-122.4194),
            "location_name": .string("Checklist Test Location, CA"),
            "description": .string("Integration test booking for checklist"),
            "payment_amount": .double(100),
            "status": .string("accepted"),
            "is_internal_test": .bool(true)
        ]

        try await supabase
            .from("bookings")
            .insert(booking)
            .execute()

        // Schedule cleanup — delete booking (cascades to booking_checklists)
        addTeardownBlock { [supabase] in
            try? await supabase
                .from("bookings")
                .delete()
                .eq("id", value: bookingId.uuidString)
                .execute()
        }

        return bookingId
    }

    // =========================================================
    // MARK: - Checklist CRUD Tests
    // =========================================================

    func testChecklist_insertAndRead() async throws {
        let bookingId = try await createTestBooking()

        // Insert a checklist via upsert (same as ChecklistService.saveBookingChecklist)
        let checklistData: [String: AnyJSON] = [
            "booking_id": .string(bookingId.uuidString),
            "has_insurance": .bool(true),
            "has_flight_plan": .bool(false),
            "has_faa_waiver": .bool(true)
        ]

        try await supabase
            .from("booking_checklists")
            .upsert(checklistData, onConflict: "booking_id")
            .execute()

        // Read it back
        let checklist: BookingChecklist = try await supabase
            .from("booking_checklists")
            .select()
            .eq("booking_id", value: bookingId.uuidString)
            .single()
            .execute()
            .value

        XCTAssertEqual(checklist.hasInsurance, true)
        XCTAssertEqual(checklist.hasFlightPlan, false)
        XCTAssertEqual(checklist.hasFAAWaiver, true)
    }

    func testChecklist_upsertUpdatesExisting() async throws {
        let bookingId = try await createTestBooking()

        // Insert initial state
        let initialData: [String: AnyJSON] = [
            "booking_id": .string(bookingId.uuidString),
            "has_insurance": .bool(false),
            "has_flight_plan": .bool(false),
            "has_faa_waiver": .bool(false)
        ]
        try await supabase
            .from("booking_checklists")
            .upsert(initialData, onConflict: "booking_id")
            .execute()

        // Upsert with updated values
        let updatedData: [String: AnyJSON] = [
            "booking_id": .string(bookingId.uuidString),
            "has_insurance": .bool(true),
            "has_flight_plan": .bool(true),
            "has_faa_waiver": .bool(false),
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        try await supabase
            .from("booking_checklists")
            .upsert(updatedData, onConflict: "booking_id")
            .execute()

        // Verify the update took effect
        let checklist: BookingChecklist = try await supabase
            .from("booking_checklists")
            .select()
            .eq("booking_id", value: bookingId.uuidString)
            .single()
            .execute()
            .value

        XCTAssertEqual(checklist.hasInsurance, true, "Insurance should be updated to true")
        XCTAssertEqual(checklist.hasFlightPlan, true, "Flight plan should be updated to true")
        XCTAssertEqual(checklist.hasFAAWaiver, false, "FAA waiver should remain false")
    }

    // =========================================================
    // MARK: - ChecklistService Round-Trip Tests
    // =========================================================

    func testChecklistService_toggleInsurance() async throws {
        let bookingId = try await createTestBooking()
        let service = ChecklistService(bookingId: bookingId)

        // Initial state should be false
        XCTAssertFalse(service.hasInsurance)

        // Toggle on
        await service.toggleInsurance()
        XCTAssertTrue(service.hasInsurance)

        // Verify it persisted by creating a fresh service and loading
        let freshService = ChecklistService(bookingId: bookingId)
        freshService.hasLoadedData = false
        await freshService.loadChecklistStatus(pilotId: TestUser.id, currentUser: nil)

        XCTAssertTrue(freshService.hasInsurance, "Insurance toggle should persist across service instances")
    }

    func testChecklistService_toggleFlightPlan() async throws {
        let bookingId = try await createTestBooking()
        let service = ChecklistService(bookingId: bookingId)

        XCTAssertFalse(service.hasFlightPlan)

        await service.toggleFlightPlan()
        XCTAssertTrue(service.hasFlightPlan)

        // Verify persistence
        let freshService = ChecklistService(bookingId: bookingId)
        await freshService.loadChecklistStatus(pilotId: TestUser.id, currentUser: nil)
        XCTAssertTrue(freshService.hasFlightPlan, "Flight plan toggle should persist")
    }

    func testChecklistService_toggleFAAWaiver() async throws {
        let bookingId = try await createTestBooking()
        let service = ChecklistService(bookingId: bookingId)

        XCTAssertFalse(service.hasFAAWaiver)

        await service.toggleFAAWaiver()
        XCTAssertTrue(service.hasFAAWaiver)

        // Toggle off
        await service.toggleFAAWaiver()
        XCTAssertFalse(service.hasFAAWaiver)

        // Verify the off state persisted
        let freshService = ChecklistService(bookingId: bookingId)
        await freshService.loadChecklistStatus(pilotId: TestUser.id, currentUser: nil)
        XCTAssertFalse(freshService.hasFAAWaiver, "FAA waiver toggle-off should persist")
    }

    func testChecklistService_loadChecklistStatus() async throws {
        let bookingId = try await createTestBooking()

        // Pre-populate checklist in DB
        let checklistData: [String: AnyJSON] = [
            "booking_id": .string(bookingId.uuidString),
            "has_insurance": .bool(true),
            "has_flight_plan": .bool(true),
            "has_faa_waiver": .bool(false)
        ]
        try await supabase
            .from("booking_checklists")
            .upsert(checklistData, onConflict: "booking_id")
            .execute()

        // Load via service
        let service = ChecklistService(bookingId: bookingId)
        await service.loadChecklistStatus(pilotId: TestUser.id, currentUser: nil)

        XCTAssertTrue(service.hasInsurance, "Should load insurance = true from DB")
        XCTAssertTrue(service.hasFlightPlan, "Should load flight plan = true from DB")
        XCTAssertFalse(service.hasFAAWaiver, "Should load FAA waiver = false from DB")
        XCTAssertTrue(service.hasLoadedData, "hasLoadedData should be true after load")
    }

    func testChecklistService_loadSkipsDuplicateCalls() async throws {
        let bookingId = try await createTestBooking()
        let service = ChecklistService(bookingId: bookingId)

        // First load
        await service.loadChecklistStatus(pilotId: TestUser.id, currentUser: nil)
        XCTAssertTrue(service.hasLoadedData)

        // Toggle insurance
        await service.toggleInsurance()
        XCTAssertTrue(service.hasInsurance)

        // Second load should skip (hasLoadedData = true) and NOT reset values
        await service.loadChecklistStatus(pilotId: TestUser.id, currentUser: nil)
        XCTAssertTrue(service.hasInsurance, "Second load should be skipped, insurance stays true")
    }

    func testChecklistService_refreshReloadsData() async throws {
        let bookingId = try await createTestBooking()
        let service = ChecklistService(bookingId: bookingId)

        // Load initial state
        await service.loadChecklistStatus(pilotId: TestUser.id, currentUser: nil)
        XCTAssertFalse(service.hasInsurance)

        // Modify DB directly (simulating another device/session)
        let updatedData: [String: AnyJSON] = [
            "booking_id": .string(bookingId.uuidString),
            "has_insurance": .bool(true),
            "has_flight_plan": .bool(false),
            "has_faa_waiver": .bool(false)
        ]
        try await supabase
            .from("booking_checklists")
            .upsert(updatedData, onConflict: "booking_id")
            .execute()

        // Regular load should skip (cached)
        await service.loadChecklistStatus(pilotId: TestUser.id, currentUser: nil)
        XCTAssertFalse(service.hasInsurance, "Regular load should use cached state")

        // Refresh should pick up the DB change
        await service.refreshChecklistStatus(pilotId: TestUser.id, currentUser: nil)
        XCTAssertTrue(service.hasInsurance, "Refresh should reload from DB and show updated insurance")
    }

    // =========================================================
    // MARK: - RLS Cross-User Isolation
    // =========================================================

    func testChecklist_cannotAccessOtherPilotsBooking() async throws {
        // Try to insert a checklist for a booking that doesn't belong to the test user
        // (using a random UUID that won't match any booking)
        let fakeBookingId = UUID()

        let checklistData: [String: AnyJSON] = [
            "booking_id": .string(fakeBookingId.uuidString),
            "has_insurance": .bool(true),
            "has_flight_plan": .bool(true),
            "has_faa_waiver": .bool(true)
        ]

        do {
            try await supabase
                .from("booking_checklists")
                .upsert(checklistData, onConflict: "booking_id")
                .execute()
            // If it somehow succeeded, check that nothing was actually inserted
            // (RLS silently filters + FK constraint should block)
        } catch {
            // Expected — RLS or FK constraint blocked the insert
        }

        // Verify nothing was inserted
        struct CountRow: Decodable { let count: Int }
        let result: [CountRow] = try await supabase
            .from("booking_checklists")
            .select("id", head: false, count: .exact)
            .eq("booking_id", value: fakeBookingId.uuidString)
            .execute()
            .value
        XCTAssertTrue(result.isEmpty, "Should not be able to create checklist for non-owned booking")
    }
}
