//
//  PilotStatsModelTests.swift
//  BuzzTests
//
//  Tests for PilotStats model, tier calculation, and tier naming.
//

import XCTest
@testable import Buzz

final class PilotStatsModelTests: XCTestCase {

    // MARK: - Tier Calculation

    func testCalculateTier_ensign() {
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 0), 0)
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 10), 0)
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 24.99), 0)
    }

    func testCalculateTier_subLieutenant() {
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 25), 1)
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 50), 1)
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 74.99), 1)
    }

    func testCalculateTier_lieutenant() {
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 75), 2)
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 150), 2)
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 199.99), 2)
    }

    func testCalculateTier_commander() {
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 200), 3)
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 350), 3)
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 499.99), 3)
    }

    func testCalculateTier_captain() {
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 500), 4)
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 1000), 4)
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 10000), 4)
    }

    func testCalculateTier_boundaryValues() {
        // Right at the boundary transitions
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 24.999), 0)
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 25.0), 1)
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 74.999), 1)
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 75.0), 2)
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 199.999), 2)
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 200.0), 3)
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 499.999), 3)
        XCTAssertEqual(PilotStats.calculateTier(flightHours: 500.0), 4)
    }

    // MARK: - Tier Names

    func testTierName_allTiers() {
        let expected: [(Int, String)] = [
            (0, "Ensign"),
            (1, "Sub Lieutenant"),
            (2, "Lieutenant"),
            (3, "Commander"),
            (4, "Captain")
        ]
        for (tier, name) in expected {
            let stats = PilotStats(pilotId: UUID(), totalFlightHours: 0, completedBookings: 0, tier: tier)
            XCTAssertEqual(stats.tierName, name, "Tier \(tier) should be \(name)")
        }
    }

    func testTierName_unknownTier() {
        let stats = PilotStats(pilotId: UUID(), totalFlightHours: 0, completedBookings: 0, tier: 5)
        XCTAssertEqual(stats.tierName, "Unknown")

        let negStats = PilotStats(pilotId: UUID(), totalFlightHours: 0, completedBookings: 0, tier: -1)
        XCTAssertEqual(negStats.tierName, "Unknown")
    }

    // MARK: - Identity

    func testIdMatchesPilotId() {
        let pilotId = UUID()
        let stats = PilotStats(pilotId: pilotId, totalFlightHours: 100, completedBookings: 5, tier: 2)
        XCTAssertEqual(stats.id, pilotId)
    }
}
