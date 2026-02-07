//
//  BookingModelTests.swift
//  BuzzTests
//
//  Tests for Booking model computed properties and related enums.
//

import XCTest
import CoreLocation
import MapKit
@testable import Buzz

final class BookingModelTests: XCTestCase {

    // MARK: - Booking Computed Properties

    func testIsAutomotiveCrewBooking_automotive() {
        let booking = MockBackend.sampleBooking(specialization: .automotive)
        XCTAssertTrue(booking.isAutomotiveCrewBooking)
    }

    func testIsAutomotiveCrewBooking_realEstate() {
        let booking = MockBackend.sampleBooking(specialization: .realEstate)
        XCTAssertFalse(booking.isAutomotiveCrewBooking)
    }

    func testIsSearchRescueCrewBooking_searchRescue() {
        let booking = MockBackend.sampleBooking(specialization: .searchRescue)
        XCTAssertTrue(booking.isSearchRescueCrewBooking)
    }

    func testIsSearchRescueCrewBooking_other() {
        let booking = MockBackend.sampleBooking(specialization: .inspections)
        XCTAssertFalse(booking.isSearchRescueCrewBooking)
    }

    func testIsCrewBooking_automotive() {
        let booking = MockBackend.sampleBooking(specialization: .automotive)
        XCTAssertTrue(booking.isCrewBooking)
    }

    func testIsCrewBooking_searchRescue() {
        let booking = MockBackend.sampleBooking(specialization: .searchRescue)
        XCTAssertTrue(booking.isCrewBooking)
    }

    func testIsCrewBooking_nonCrew() {
        let booking = MockBackend.sampleBooking(specialization: .realEstate)
        XCTAssertFalse(booking.isCrewBooking)
    }

    func testIsCrewBooking_nilSpecialization() {
        let booking = MockBackend.sampleBooking(specialization: nil)
        XCTAssertFalse(booking.isCrewBooking)
    }

    func testCoordinate() {
        let booking = Booking(
            id: UUID(), customerId: UUID(), pilotId: nil,
            locationLat: 37.7749, locationLng: -122.4194,
            locationName: "SF", scheduledDate: nil, endDate: nil,
            specialization: nil, description: nil, paymentAmount: 100,
            tipAmount: nil, status: .available, createdAt: Date(),
            estimatedFlightHours: 1, pilotRated: nil, customerRated: nil,
            requiredMinimumRank: 0
        )
        XCTAssertEqual(booking.coordinate.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(booking.coordinate.longitude, -122.4194, accuracy: 0.0001)
    }

    func testRankName_withRank() {
        let booking = MockBackend.sampleBooking(requiredMinimumRank: 2)
        XCTAssertEqual(booking.rankName, "Lieutenant")
    }

    func testRankName_nilRank() {
        var booking = MockBackend.sampleBooking()
        // Create a booking with nil requiredMinimumRank
        let nilRankBooking = Booking(
            id: UUID(), customerId: UUID(), pilotId: nil,
            locationLat: 0, locationLng: 0, locationName: "Test",
            scheduledDate: nil, endDate: nil, specialization: nil,
            description: nil, paymentAmount: 100, tipAmount: nil,
            status: .available, createdAt: Date(), estimatedFlightHours: 1,
            pilotRated: nil, customerRated: nil, requiredMinimumRank: nil
        )
        XCTAssertEqual(nilRankBooking.rankName, "Any Rank")
    }

    // MARK: - BookingStatus Enum

    func testBookingStatusDisplayNames() {
        XCTAssertEqual(BookingStatus.available.displayName, "standby")
        XCTAssertEqual(BookingStatus.accepted.displayName, "Active")
        XCTAssertEqual(BookingStatus.completed.displayName, "completed")
        XCTAssertEqual(BookingStatus.cancelled.displayName, "cancelled")
    }

    func testBookingStatusRawValues() {
        XCTAssertEqual(BookingStatus.available.rawValue, "available")
        XCTAssertEqual(BookingStatus.accepted.rawValue, "accepted")
        XCTAssertEqual(BookingStatus.completed.rawValue, "completed")
        XCTAssertEqual(BookingStatus.cancelled.rawValue, "cancelled")
    }

    // MARK: - BookingSpecialization Enum

    func testAllSpecializationsHaveDisplayNames() {
        for spec in BookingSpecialization.allCases {
            XCTAssertFalse(spec.displayName.isEmpty, "\(spec) has empty displayName")
        }
    }

    func testAllSpecializationsHaveIcons() {
        for spec in BookingSpecialization.allCases {
            XCTAssertFalse(spec.icon.isEmpty, "\(spec) has empty icon")
        }
    }

    func testAllSpecializationsHaveBackgroundImages() {
        for spec in BookingSpecialization.allCases {
            XCTAssertFalse(spec.backgroundImage.isEmpty, "\(spec) has empty backgroundImage")
        }
    }

    func testSpecializationRawValues() {
        XCTAssertEqual(BookingSpecialization.automotive.rawValue, "automotive")
        XCTAssertEqual(BookingSpecialization.realEstate.rawValue, "real_estate")
        XCTAssertEqual(BookingSpecialization.searchRescue.rawValue, "search_rescue")
        XCTAssertEqual(BookingSpecialization.motionPicture.rawValue, "motion_picture")
    }

    // MARK: - BookingCrewMember Tests

    func testCrewMemberJoinedAtParsesISO8601WithFractionalSeconds() {
        let member = BookingCrewMember(
            id: UUID(), bookingId: UUID(), pilotId: UUID(),
            role: .crew, rankAtAcceptance: 2, payoutAmount: 100,
            joinedAtString: "2025-01-15T10:30:00.123Z"
        )
        let calendar = Calendar.current
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: member.joinedAt)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 15)
    }

    func testCrewMemberJoinedAtFallbackWithoutFractionalSeconds() {
        let member = BookingCrewMember(
            id: UUID(), bookingId: UUID(), pilotId: UUID(),
            role: .crew, rankAtAcceptance: 2, payoutAmount: 100,
            joinedAtString: "2025-06-20T14:00:00Z"
        )
        let calendar = Calendar.current
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: member.joinedAt)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 6)
    }

    func testCrewMemberRankNames() {
        let ranks: [(Int, String)] = [
            (1, "Sublieutenant"),
            (2, "Lieutenant"),
            (3, "Commander"),
            (4, "Captain"),
            (0, "Unknown"),
            (5, "Unknown")
        ]
        for (rank, expectedName) in ranks {
            let member = BookingCrewMember(
                id: UUID(), bookingId: UUID(), pilotId: UUID(),
                role: .crew, rankAtAcceptance: rank, payoutAmount: 100,
                joinedAtString: "2025-01-01T00:00:00Z"
            )
            XCTAssertEqual(member.rankName, expectedName, "Rank \(rank) should be \(expectedName)")
        }
    }

    func testCrewMemberIsPosted_withTransferId() {
        var member = BookingCrewMember(
            id: UUID(), bookingId: UUID(), pilotId: UUID(),
            role: .crew, rankAtAcceptance: 2, payoutAmount: 100,
            joinedAtString: "2025-01-01T00:00:00Z"
        )
        member.transferId = "tr_12345"
        XCTAssertTrue(member.isPosted)
    }

    func testCrewMemberIsPosted_withoutTransferId() {
        let member = BookingCrewMember(
            id: UUID(), bookingId: UUID(), pilotId: UUID(),
            role: .crew, rankAtAcceptance: 2, payoutAmount: 100,
            joinedAtString: "2025-01-01T00:00:00Z"
        )
        XCTAssertFalse(member.isPosted)
    }

    // MARK: - SARAssignmentType Enum

    func testSARAssignmentTypeDisplayNames() {
        let expected: [(SARAssignmentType, String)] = [
            (.groundSearch, "Ground Search"),
            (.airSearch, "Air Search"),
            (.waterRescue, "Water Rescue"),
            (.medicalEmergency, "Medical Emergency"),
            (.fireEmergency, "Fire Emergency"),
            (.disasterResponse, "Disaster Response"),
            (.missingPerson, "Missing Person")
        ]
        for (type, name) in expected {
            XCTAssertEqual(type.displayName, name)
        }
    }

    func testSARAssignmentTypeHasIcons() {
        for type in SARAssignmentType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "\(type) has empty icon")
        }
    }

    // MARK: - GovernmentAgency Enum

    func testGovernmentAgencyDisplayNames() {
        let expected: [(GovernmentAgency, String)] = [
            (.policeDepartment, "Police Department"),
            (.fireDepartment, "Fire Department"),
            (.sheriffOffice, "Sheriff's Office"),
            (.stateEmergencyManagement, "State Emergency Management")
        ]
        for (agency, name) in expected {
            XCTAssertEqual(agency.displayName, name)
        }
    }

    func testGovernmentAgencyHasIcons() {
        for agency in GovernmentAgency.allCases {
            XCTAssertFalse(agency.icon.isEmpty, "\(agency) has empty icon")
        }
    }

    // MARK: - CrewRole Enum

    func testCrewRoleDisplayNames() {
        XCTAssertEqual(CrewRole.lead.displayName, "Lead Pilot")
        XCTAssertEqual(CrewRole.crew.displayName, "Crew Member")
    }

    // MARK: - BookingCrewResponse

    func testBookingCrewResponseIsCrewBooking() {
        let automotiveResponse = BookingCrewResponse(
            isAutomotive: true, isSearchRescue: nil,
            crewCount: 2, maxCrew: 4, status: nil,
            hasQualifiedLead: nil, isCrewFull: nil, isReady: nil,
            crew: nil, leadPilot: nil, totalPayout: nil
        )
        XCTAssertTrue(automotiveResponse.isCrewBooking)

        let sarResponse = BookingCrewResponse(
            isAutomotive: false, isSearchRescue: true,
            crewCount: 1, maxCrew: 3, status: nil,
            hasQualifiedLead: nil, isCrewFull: nil, isReady: nil,
            crew: nil, leadPilot: nil, totalPayout: nil
        )
        XCTAssertTrue(sarResponse.isCrewBooking)

        let regularResponse = BookingCrewResponse(
            isAutomotive: false, isSearchRescue: false,
            crewCount: 0, maxCrew: 1, status: nil,
            hasQualifiedLead: nil, isCrewFull: nil, isReady: nil,
            crew: nil, leadPilot: nil, totalPayout: nil
        )
        XCTAssertFalse(regularResponse.isCrewBooking)
    }
}
