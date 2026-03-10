//
//  BeaconServiceIntegrationTests.swift
//  BuzzTests
//
//  Integration tests for BeaconService hitting real Supabase.
//

import XCTest
@testable import Buzz

@MainActor
final class BeaconServiceIntegrationTests: IntegrationTestCase {

    private var service: BeaconService!

    override func setUp() async throws {
        try await super.setUp()
        service = BeaconService(backend: nil) // real Supabase
    }

    // MARK: - Helpers

    /// Returns the volunteer record if the test user is enrolled, nil otherwise.
    private func requireVolunteerStatus() async throws -> BeaconVolunteer {
        let status = try await service.getVolunteerStatus(userId: TestUser.id)
        try XCTSkipUnless(status != nil, "Test user is not enrolled as a beacon volunteer — skipping volunteer-dependent test")
        return status!
    }

    // MARK: - Training Progress

    func testSyncBadgesToTraining_doesNotThrow() async throws {
        try await service.syncBadgesToTraining(userId: TestUser.id)
    }

    func testGetTrainingProgress_roundTrip() async throws {
        let progress = try await service.getTrainingProgress(userId: TestUser.id)

        // Verify the returned data matches the published property
        XCTAssertEqual(service.trainingProgress.count, progress.count)
    }

    func testGetTrainingProgress_returnsValidRecords() async throws {
        let progress = try await service.getTrainingProgress(userId: TestUser.id)

        for record in progress {
            XCTAssertEqual(record.pilotId, TestUser.id)
            XCTAssertFalse(record.certificateUrl.isEmpty)
            XCTAssertTrue(BeaconTrainingType.allCases.contains(record.trainingType))
        }
    }

    // MARK: - Volunteer Status

    func testIsUserBeaconVolunteer_nonExistentUser_returnsFalse() async throws {
        let fakeUserId = UUID()
        let isVolunteer = try await service.isUserBeaconVolunteer(userId: fakeUserId)

        XCTAssertFalse(isVolunteer)
    }

    func testIsUserBeaconVolunteer_matchesGetVolunteerStatus() async throws {
        let isVolunteer = try await service.isUserBeaconVolunteer(userId: TestUser.id)
        let status = try await service.getVolunteerStatus(userId: TestUser.id)
        let hasCurrentQualifications = try await service.isAllTrainingCompleted(userId: TestUser.id)

        XCTAssertEqual(isVolunteer, status != nil && hasCurrentQualifications)
    }

    func testGetVolunteerStatus_returnsRecord() async throws {
        let status = try await requireVolunteerStatus()

        XCTAssertEqual(status.pilotId, TestUser.id)
        XCTAssertNotNil(service.volunteerStatus)
    }

    func testUpdateAvailability_toggleRoundTrip() async throws {
        let original = try await requireVolunteerStatus()
        let originalAvailability = original.isAvailable

        // Toggle availability
        try await service.updateAvailability(userId: TestUser.id, isAvailable: !originalAvailability)

        // Verify the change
        let updated = try await service.getVolunteerStatus(userId: TestUser.id)
        XCTAssertEqual(updated?.isAvailable, !originalAvailability)

        // Restore original
        try await service.updateAvailability(userId: TestUser.id, isAvailable: originalAvailability)
    }

    func testUpdateLocation_persistsCoordinates() async throws {
        _ = try await requireVolunteerStatus()
        let testLat = 42.4396
        let testLng = -76.4966

        try await service.updateLocation(userId: TestUser.id, lat: testLat, lng: testLng)

        // Fetch and verify
        let status = try await service.getVolunteerStatus(userId: TestUser.id)
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.lastLocationLat ?? 0, testLat, accuracy: 0.001)
        XCTAssertEqual(status?.lastLocationLng ?? 0, testLng, accuracy: 0.001)
    }

    func testUpdateNotificationRadius_persists() async throws {
        let original = try await requireVolunteerStatus()
        let originalRadius = original.notificationRadiusMiles

        // Update to a different value
        let newRadius = originalRadius == 50 ? 30 : 50
        try await service.updateNotificationRadius(userId: TestUser.id, radiusMiles: newRadius)

        // Verify
        let updated = try await service.getVolunteerStatus(userId: TestUser.id)
        XCTAssertEqual(updated?.notificationRadiusMiles, newRadius)

        // Restore original
        try await service.updateNotificationRadius(userId: TestUser.id, radiusMiles: originalRadius)
    }

    // MARK: - Emergency Dispatch

    func testFindNearbyVolunteers_returnsValidStructure() async throws {
        // Search a known location — results may be empty but should not throw
        let volunteers = try await service.findNearbyVolunteers(lat: 42.4396, lng: -76.4966, radiusMiles: 50)

        // Validate structure of any returned records
        for v in volunteers {
            XCTAssertGreaterThanOrEqual(v.distanceMiles, 0)
            XCTAssertGreaterThan(v.notificationRadiusMiles, 0)
        }
    }
}
