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

    func testBookingStatusDisplayNames_newCases() {
        XCTAssertEqual(BookingStatus.staffed.displayName, "Staffed")
        XCTAssertEqual(BookingStatus.inProgress.displayName, "In Progress")
        XCTAssertEqual(BookingStatus.expired.displayName, "Expired")
    }

    func testBookingStatusRawValues() {
        XCTAssertEqual(BookingStatus.available.rawValue, "available")
        XCTAssertEqual(BookingStatus.accepted.rawValue, "accepted")
        XCTAssertEqual(BookingStatus.completed.rawValue, "completed")
        XCTAssertEqual(BookingStatus.cancelled.rawValue, "cancelled")
    }

    func testBookingStatusRawValues_newCases() {
        XCTAssertEqual(BookingStatus.staffed.rawValue, "staffed")
        XCTAssertEqual(BookingStatus.inProgress.rawValue, "in_progress")
        XCTAssertEqual(BookingStatus.expired.rawValue, "expired")
    }

    func testBookingStatusHasAll7Cases() {
        let allCases: [BookingStatus] = [
            .available, .accepted, .staffed, .inProgress,
            .completed, .expired, .cancelled
        ]
        XCTAssertEqual(allCases.count, 7)
        // Verify each decodes from its raw value
        for status in allCases {
            let decoded = BookingStatus(rawValue: status.rawValue)
            XCTAssertEqual(decoded, status, "\(status.rawValue) should decode back to \(status)")
        }
    }

    func testBookingStatusDecodesFromJSON() throws {
        let testCases: [(String, BookingStatus)] = [
            ("\"available\"", .available),
            ("\"accepted\"", .accepted),
            ("\"staffed\"", .staffed),
            ("\"in_progress\"", .inProgress),
            ("\"completed\"", .completed),
            ("\"expired\"", .expired),
            ("\"cancelled\"", .cancelled)
        ]

        let decoder = JSONDecoder()
        for (json, expected) in testCases {
            let data = json.data(using: .utf8)!
            let decoded = try decoder.decode(BookingStatus.self, from: data)
            XCTAssertEqual(decoded, expected, "JSON \(json) should decode to \(expected)")
        }
    }

    // MARK: - DisputeStatus Enum

    func testDisputeStatusRawValues() {
        XCTAssertEqual(DisputeStatus.open.rawValue, "open")
        XCTAssertEqual(DisputeStatus.underReview.rawValue, "under_review")
        XCTAssertEqual(DisputeStatus.resolved.rawValue, "resolved")
        XCTAssertEqual(DisputeStatus.dismissed.rawValue, "dismissed")
    }

    func testDisputeStatusDecodesFromJSON() throws {
        let testCases: [(String, DisputeStatus)] = [
            ("\"open\"", .open),
            ("\"under_review\"", .underReview),
            ("\"resolved\"", .resolved),
            ("\"dismissed\"", .dismissed)
        ]

        let decoder = JSONDecoder()
        for (json, expected) in testCases {
            let data = json.data(using: .utf8)!
            let decoded = try decoder.decode(DisputeStatus.self, from: data)
            XCTAssertEqual(decoded, expected, "JSON \(json) should decode to \(expected)")
        }
    }

    // MARK: - DisputeReason Enum

    func testDisputeReasonRawValues() {
        XCTAssertEqual(DisputeReason.incorrectCharge.rawValue, "incorrect_charge")
        XCTAssertEqual(DisputeReason.serviceNotProvided.rawValue, "service_not_provided")
        XCTAssertEqual(DisputeReason.qualityIssue.rawValue, "quality_issue")
        XCTAssertEqual(DisputeReason.safetyConcern.rawValue, "safety_concern")
        XCTAssertEqual(DisputeReason.other.rawValue, "other")
    }

    func testDisputeReasonDecodesFromJSON() throws {
        let testCases: [(String, DisputeReason)] = [
            ("\"incorrect_charge\"", .incorrectCharge),
            ("\"service_not_provided\"", .serviceNotProvided),
            ("\"quality_issue\"", .qualityIssue),
            ("\"safety_concern\"", .safetyConcern),
            ("\"other\"", .other)
        ]

        let decoder = JSONDecoder()
        for (json, expected) in testCases {
            let data = json.data(using: .utf8)!
            let decoded = try decoder.decode(DisputeReason.self, from: data)
            XCTAssertEqual(decoded, expected, "JSON \(json) should decode to \(expected)")
        }
    }

    // MARK: - BookingDispute Model

    func testBookingDisputeCodableRoundtrip() throws {
        let disputeId = UUID()
        let bookingId = UUID()
        let userId = UUID()
        let now = Date()

        let dispute = BookingDispute(
            id: disputeId,
            bookingId: bookingId,
            initiatedBy: userId,
            reason: "quality_issue",
            description: "Poor footage quality",
            status: .open,
            resolution: nil,
            createdAt: now,
            resolvedAt: nil,
            resolvedBy: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dispute)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BookingDispute.self, from: data)

        XCTAssertEqual(decoded.id, disputeId)
        XCTAssertEqual(decoded.bookingId, bookingId)
        XCTAssertEqual(decoded.initiatedBy, userId)
        XCTAssertEqual(decoded.reason, "quality_issue")
        XCTAssertEqual(decoded.description, "Poor footage quality")
        XCTAssertEqual(decoded.status, .open)
        XCTAssertNil(decoded.resolution)
        XCTAssertNil(decoded.resolvedAt)
        XCTAssertNil(decoded.resolvedBy)
    }

    func testBookingDisputeCodingKeys_snakeCaseMapping() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "booking_id": "22222222-2222-2222-2222-222222222222",
            "initiated_by": "33333333-3333-3333-3333-333333333333",
            "reason": "safety_concern",
            "description": "Safety issue during flight",
            "status": "under_review",
            "resolution": null,
            "created_at": "2026-01-15T10:00:00Z",
            "resolved_at": null,
            "resolved_by": null
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dispute = try decoder.decode(BookingDispute.self, from: json)

        XCTAssertEqual(dispute.id, UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        XCTAssertEqual(dispute.bookingId, UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        XCTAssertEqual(dispute.initiatedBy, UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        XCTAssertEqual(dispute.reason, "safety_concern")
        XCTAssertEqual(dispute.status, .underReview)
    }

    func testBookingDisputeResolvedFields() throws {
        let resolverId = UUID()
        let now = Date()
        var dispute = MockBackend.sampleDispute(status: .open)
        dispute.status = .resolved
        dispute.resolution = "Refund issued"
        dispute.resolvedAt = now
        dispute.resolvedBy = resolverId

        XCTAssertEqual(dispute.status, .resolved)
        XCTAssertEqual(dispute.resolution, "Refund issued")
        XCTAssertNotNil(dispute.resolvedAt)
        XCTAssertEqual(dispute.resolvedBy, resolverId)
    }

    // MARK: - Booking Expiration Fields

    func testBookingWithExpirationFields() {
        let expiresAt = Date().addingTimeInterval(7 * 24 * 60 * 60)
        let booking = MockBackend.sampleBooking(
            expiresAt: expiresAt,
            expirationNotified: false
        )
        XCTAssertEqual(booking.expiresAt, expiresAt)
        XCTAssertEqual(booking.expirationNotified, false)
    }

    func testBookingWithNilExpirationFields() {
        let booking = MockBackend.sampleBooking()
        XCTAssertNil(booking.expiresAt)
        XCTAssertNil(booking.expirationNotified)
    }

    func testBookingExpirationFieldsCodable() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "customer_id": "22222222-2222-2222-2222-222222222222",
            "location_lat": 37.7749,
            "location_lng": -122.4194,
            "location_name": "Test",
            "payment_amount": 100,
            "status": "available",
            "created_at": "2026-01-15T10:00:00Z",
            "estimated_flight_hours": 2.0,
            "expires_at": "2026-01-22T10:00:00Z",
            "expiration_notified": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let booking = try decoder.decode(Booking.self, from: json)

        XCTAssertNotNil(booking.expiresAt)
        XCTAssertEqual(booking.expirationNotified, false)
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
