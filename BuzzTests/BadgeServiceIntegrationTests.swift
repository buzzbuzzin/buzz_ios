//
//  BadgeServiceIntegrationTests.swift
//  BuzzTests
//
//  Integration tests for BadgeService calling real Supabase.
//

import XCTest
@testable import Buzz

@MainActor
final class BadgeServiceIntegrationTests: IntegrationTestCase {

    private var service: BadgeService!

    override func setUp() async throws {
        try await super.setUp()
        service = BadgeService()
    }

    override func tearDown() async throws {
        service = nil
        try await super.tearDown()
    }

    // MARK: - Fetch Badges

    func testFetchPilotBadges_completesWithoutError() async throws {
        // Should complete without throwing, even if the pilot has no badges
        try await service.fetchPilotBadges(pilotId: TestUser.id)
        XCTAssertFalse(service.isLoading, "isLoading should be false after fetch completes")
        XCTAssertNil(service.errorMessage, "errorMessage should be nil on success")
    }

    func testFetchPilotBadges_returnsValidArray() async throws {
        try await service.fetchPilotBadges(pilotId: TestUser.id)
        // May be empty, but should be a valid array
        XCTAssertNotNil(service.badges)
        // If badges exist, verify each has required fields
        for badge in service.badges {
            XCTAssertNotNil(badge.id)
            XCTAssertNotNil(badge.badgeType)
        }
    }

    func testFetchAvailableBadges_completesWithoutError() async throws {
        try await service.fetchAvailableBadges(pilotId: TestUser.id)
        // Should not crash; may be empty
        XCTAssertNotNil(service.availableBadges)
    }
}
