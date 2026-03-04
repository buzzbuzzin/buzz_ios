//
//  BookingServiceSARTests.swift
//  BuzzTests
//
//  Unit tests for BookingService Search & Rescue methods.
//

import XCTest
@testable import Buzz

@MainActor
final class BookingServiceSARTests: XCTestCase {

    // MARK: - Join Search & Rescue

    func testJoinSearchRescueBooking_success() async throws {
        let bookingId = UUID()
        let pilotId = UUID()
        let backend = MockBackend()
        backend.joinSARResponse = JoinCrewResponse(
            success: true, message: "Joined mission — 1 of 3 pilots",
            crewMember: nil, crewStatus: nil, error: nil
        )
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        let response = try await service.joinSearchRescueBooking(bookingId: bookingId, pilotId: pilotId)

        XCTAssertTrue(backend.joinSARCalled)
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.message, "Joined mission — 1 of 3 pilots")
    }

    func testJoinSearchRescueBooking_error_propagated() async throws {
        let backend = MockBackend()
        backend.shouldThrowOnJoinSAR = true
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        do {
            _ = try await service.joinSearchRescueBooking(bookingId: UUID(), pilotId: UUID())
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(backend.joinSARCalled)
        }
    }

    func testJoinSearchRescueBooking_setsLoadingStateFalseAfterCompletion() async throws {
        let backend = MockBackend()
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        _ = try await service.joinSearchRescueBooking(bookingId: UUID(), pilotId: UUID())

        XCTAssertFalse(service.isLoading)
    }

    func testJoinSearchRescueBooking_setsErrorMessageOnFailure() async throws {
        let backend = MockBackend()
        backend.shouldThrowOnJoinSAR = true
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        do {
            _ = try await service.joinSearchRescueBooking(bookingId: UUID(), pilotId: UUID())
            XCTFail("Expected error")
        } catch {
            XCTAssertNotNil(service.errorMessage)
            XCTAssertFalse(service.isLoading)
        }
    }

    // MARK: - Leave Search & Rescue

    func testLeaveSearchRescueBooking_success() async throws {
        let backend = MockBackend()
        backend.leaveSARResponse = JoinCrewResponse(
            success: true, message: "Left mission",
            crewMember: nil, crewStatus: nil, error: nil
        )
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        let response = try await service.leaveSearchRescueBooking(bookingId: UUID(), pilotId: UUID())

        XCTAssertTrue(backend.leaveSARCalled)
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.message, "Left mission")
    }

    func testLeaveSearchRescueBooking_error_propagated() async throws {
        let backend = MockBackend()
        backend.shouldThrowOnLeaveSAR = true
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        do {
            _ = try await service.leaveSearchRescueBooking(bookingId: UUID(), pilotId: UUID())
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(backend.leaveSARCalled)
        }
    }

    func testLeaveSearchRescueBooking_setsErrorMessage() async throws {
        let backend = MockBackend()
        backend.shouldThrowOnLeaveSAR = true
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        do {
            _ = try await service.leaveSearchRescueBooking(bookingId: UUID(), pilotId: UUID())
            XCTFail("Expected error")
        } catch {
            XCTAssertNotNil(service.errorMessage)
        }
    }

    // MARK: - Mark Search & Rescue as Staffed

    func testMarkSearchRescueAsStaffed_success() async throws {
        let bookingId = UUID()
        let sarBooking = MockBackend.sampleBooking(
            id: bookingId,
            specialization: .searchRescue,
            status: .available,
            numberOfPilots: 2
        )
        let backend = MockBackend(fetchBookingResult: sarBooking)
        backend.crewMembers = [
            MockBackend.sampleCrewMember(bookingId: bookingId),
            MockBackend.sampleCrewMember(bookingId: bookingId)
        ]
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        try await service.markSearchRescueAsStaffed(bookingId: bookingId)

        XCTAssertTrue(backend.updateCalled)
        XCTAssertTrue(backend.fetchCrewCalled)
        XCTAssertEqual(backend.lastUpdatedValues?["status"]?.stringValue, BookingStatus.staffed.rawValue)
    }

    func testMarkSearchRescueAsStaffed_notSAR_throws() async throws {
        let bookingId = UUID()
        let nonSARBooking = MockBackend.sampleBooking(
            id: bookingId,
            specialization: .realEstate,
            status: .available
        )
        let backend = MockBackend(fetchBookingResult: nonSARBooking)
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        do {
            try await service.markSearchRescueAsStaffed(bookingId: bookingId)
            XCTFail("Expected error for non-S&R booking")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Search & Rescue"))
        }
    }

    func testMarkSearchRescueAsStaffed_notAvailable_throws() async throws {
        let bookingId = UUID()
        let staffedBooking = MockBackend.sampleBooking(
            id: bookingId,
            specialization: .searchRescue,
            status: .staffed
        )
        let backend = MockBackend(fetchBookingResult: staffedBooking)
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        do {
            try await service.markSearchRescueAsStaffed(bookingId: bookingId)
            XCTFail("Expected error for non-available booking")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("available"))
        }
    }

    func testMarkSearchRescueAsStaffed_insufficientCrew_throws() async throws {
        let bookingId = UUID()
        let sarBooking = MockBackend.sampleBooking(
            id: bookingId,
            specialization: .searchRescue,
            status: .available,
            numberOfPilots: 3
        )
        let backend = MockBackend(fetchBookingResult: sarBooking)
        backend.crewMembers = [
            MockBackend.sampleCrewMember(bookingId: bookingId)
        ]
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        do {
            try await service.markSearchRescueAsStaffed(bookingId: bookingId)
            XCTFail("Expected error for insufficient crew")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Not enough pilots"))
        }
    }

    // MARK: - Complete Voluntary Mission

    func testCompleteVoluntaryMission_updatesStatus() async throws {
        let bookingId = UUID()
        let sarBooking = MockBackend.sampleBooking(
            id: bookingId,
            specialization: .searchRescue,
            status: .staffed,
            estimatedFlightHours: 2.0
        )
        let backend = MockBackend(fetchBookingResult: sarBooking)
        backend.crewMembers = [
            MockBackend.sampleCrewMember(bookingId: bookingId)
        ]
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        try await service.completeVoluntaryMission(bookingId: bookingId)

        XCTAssertTrue(backend.updateCalled)
        XCTAssertEqual(backend.lastUpdatedValues?["status"]?.stringValue, BookingStatus.completed.rawValue)
    }

    func testCompleteVoluntaryMission_fetchesCrew() async throws {
        let bookingId = UUID()
        let sarBooking = MockBackend.sampleBooking(
            id: bookingId,
            specialization: .searchRescue,
            status: .staffed,
            estimatedFlightHours: 2.0
        )
        let backend = MockBackend(fetchBookingResult: sarBooking)
        backend.crewMembers = [
            MockBackend.sampleCrewMember(bookingId: bookingId)
        ]
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        try await service.completeVoluntaryMission(bookingId: bookingId)

        XCTAssertTrue(backend.fetchCrewCalled)
    }

    func testCompleteVoluntaryMission_notifiesBeaconResolved() async throws {
        let bookingId = UUID()
        let sarBooking = MockBackend.sampleBooking(
            id: bookingId,
            specialization: .searchRescue,
            status: .staffed,
            estimatedFlightHours: 2.0
        )
        let backend = MockBackend(fetchBookingResult: sarBooking)
        backend.crewMembers = []
        let mockNotifications = MockNotificationManager()
        let service = BookingService(
            backend: backend,
            notificationManager: mockNotifications,
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: false
        )

        try await service.completeVoluntaryMission(bookingId: bookingId)

        // Allow background Task to execute
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockNotifications.beaconResolvedCalls, 1)
    }

    func testCompleteVoluntaryMission_skipsNotificationInSkipMode() async throws {
        let bookingId = UUID()
        let sarBooking = MockBackend.sampleBooking(
            id: bookingId,
            specialization: .searchRescue,
            status: .staffed,
            estimatedFlightHours: 2.0
        )
        let backend = MockBackend(fetchBookingResult: sarBooking)
        backend.crewMembers = []
        let mockNotifications = MockNotificationManager()
        let service = BookingService(
            backend: backend,
            notificationManager: mockNotifications,
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        try await service.completeVoluntaryMission(bookingId: bookingId)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockNotifications.beaconResolvedCalls, 0)
    }
}
