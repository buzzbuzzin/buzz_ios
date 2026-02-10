//
//  BookingNotificationTests.swift
//  BuzzTests
//
//  Tests for booking-related notification triggers using mock infrastructure.
//

import XCTest
@testable import Buzz

@MainActor
final class BookingNotificationTests: XCTestCase {

    // MARK: - Accept Booking Notifications

    func testAcceptBooking_notifiesBookingAccepted() async throws {
        let bookingId = UUID()
        let pilotId = UUID()
        let booking = MockBackend.sampleBooking(
            id: bookingId,
            specialization: .realEstate,
            scheduledDate: Date().addingTimeInterval(86400)
        )
        let backend = MockBackend(
            fetchBookingResult: booking,
            userProfileResult: MockBackend.sampleProfile(id: pilotId)
        )
        let notificationManager = MockNotificationManager()
        let service = BookingService(
            backend: backend,
            notificationManager: notificationManager,
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: false
        )

        try await service.acceptBooking(bookingId: bookingId, pilotId: pilotId)

        XCTAssertEqual(notificationManager.acceptedCalls, 1)
    }

    func testAcceptBooking_schedulesReminder_whenFutureDate() async throws {
        let bookingId = UUID()
        let pilotId = UUID()
        let futureDate = Date().addingTimeInterval(48 * 60 * 60) // 48 hours from now
        let booking = MockBackend.sampleBooking(
            id: bookingId,
            specialization: .realEstate,
            scheduledDate: futureDate
        )
        let backend = MockBackend(
            fetchBookingResult: booking,
            userProfileResult: MockBackend.sampleProfile(id: pilotId)
        )
        let notificationManager = MockNotificationManager()
        let service = BookingService(
            backend: backend,
            notificationManager: notificationManager,
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: false
        )

        try await service.acceptBooking(bookingId: bookingId, pilotId: pilotId)

        XCTAssertEqual(notificationManager.reminderCalls, 1)
    }

    func testAcceptBooking_skipNetworkCalls_doesNotNotify() async throws {
        let bookingId = UUID()
        let pilotId = UUID()
        let booking = MockBackend.sampleBooking(
            id: bookingId,
            specialization: .realEstate,
            scheduledDate: Date()
        )
        let backend = MockBackend(
            fetchBookingResult: booking,
            userProfileResult: MockBackend.sampleProfile(id: pilotId)
        )
        let notificationManager = MockNotificationManager()
        let service = BookingService(
            backend: backend,
            notificationManager: notificationManager,
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        try await service.acceptBooking(bookingId: bookingId, pilotId: pilotId)

        XCTAssertEqual(notificationManager.acceptedCalls, 0)
        XCTAssertEqual(notificationManager.reminderCalls, 0)
    }

    // MARK: - Mock Notification Manager Verification

    func testMockNotificationManager_tracksAllCallTypes() async {
        let mock = MockNotificationManager()
        let bookingId = UUID()

        await mock.notifyBookingAccepted(bookingId: bookingId, pilotName: "Pilot", aircraftType: "Drone", departureTime: Date())
        await mock.scheduleBookingReminder(bookingId: bookingId, aircraftType: "Drone", departureTime: Date(), pilotName: "Pilot")
        await mock.notifyNearbyBooking(bookingId: bookingId, aircraftType: "Drone", distance: 5.0, departureTime: Date())
        await mock.notifyCrewBookingCompleted(bookingId: bookingId, payoutAmount: 100, role: "lead")
        await mock.notifyBookingCancelled(bookingId: bookingId, cancelledByName: "Customer", aircraftType: "Drone")
        await mock.notifyTipReceived(bookingId: bookingId, tipAmount: 20, customerName: "Customer")
        await mock.notifyPayoutConfirmation(bookingId: bookingId, payoutAmount: 150)
        await mock.notifyBeaconAccepted(bookingId: bookingId, volunteerCallSign: "Alpha1", missionType: "Search & Rescue")
        await mock.notifyBeaconResolved(bookingId: bookingId, missionType: "Search & Rescue")

        XCTAssertEqual(mock.acceptedCalls, 1)
        XCTAssertEqual(mock.reminderCalls, 1)
        XCTAssertEqual(mock.nearbyCalls, 1)
        XCTAssertEqual(mock.completionCalls, 1)
        XCTAssertEqual(mock.cancelledCalls, 1)
        XCTAssertEqual(mock.tipReceivedCalls, 1)
        XCTAssertEqual(mock.payoutCalls, 1)
        XCTAssertEqual(mock.beaconAcceptedCalls, 1)
        XCTAssertEqual(mock.beaconResolvedCalls, 1)
    }

    func testMockNotificationManager_multipleCalls_accumulate() async {
        let mock = MockNotificationManager()
        let bookingId = UUID()

        await mock.notifyBookingCancelled(bookingId: bookingId, cancelledByName: "A", aircraftType: "Drone")
        await mock.notifyBookingCancelled(bookingId: bookingId, cancelledByName: "B", aircraftType: "Drone")
        await mock.notifyTipReceived(bookingId: bookingId, tipAmount: 10, customerName: "C")
        await mock.notifyTipReceived(bookingId: bookingId, tipAmount: 20, customerName: "D")
        await mock.notifyTipReceived(bookingId: bookingId, tipAmount: 30, customerName: "E")

        XCTAssertEqual(mock.cancelledCalls, 2)
        XCTAssertEqual(mock.tipReceivedCalls, 3)
    }

    func testMockNotificationManager_initialCounts_allZero() {
        let mock = MockNotificationManager()

        XCTAssertEqual(mock.acceptedCalls, 0)
        XCTAssertEqual(mock.reminderCalls, 0)
        XCTAssertEqual(mock.nearbyCalls, 0)
        XCTAssertEqual(mock.completionCalls, 0)
        XCTAssertEqual(mock.cancelledCalls, 0)
        XCTAssertEqual(mock.tipReceivedCalls, 0)
        XCTAssertEqual(mock.payoutCalls, 0)
        XCTAssertEqual(mock.beaconAcceptedCalls, 0)
        XCTAssertEqual(mock.beaconResolvedCalls, 0)
    }

    // MARK: - Mock Notification Preferences

    func testMockNotificationPreferences_defaultsBookingRemindersEnabled() {
        let mock = MockNotificationPreferences()
        XCTAssertTrue(mock.preferences.bookingReminders.system)
    }

    func testMockNotificationPreferences_loadTracksCall() async throws {
        let mock = MockNotificationPreferences()
        XCTAssertFalse(mock.loadCalled)

        try await mock.loadPreferences(userId: UUID())
        XCTAssertTrue(mock.loadCalled)
    }

    func testMockNotificationPreferences_preferencesAreMutable() {
        let mock = MockNotificationPreferences()
        mock.preferences.bookingCancellations.system = false
        mock.preferences.tipReceived.email = true

        XCTAssertFalse(mock.preferences.bookingCancellations.system)
        XCTAssertTrue(mock.preferences.tipReceived.email)
    }

    // MARK: - Notification Preference Gating

    func testAcceptBooking_respectsPreferenceGating() async throws {
        let bookingId = UUID()
        let pilotId = UUID()
        let booking = MockBackend.sampleBooking(
            id: bookingId,
            specialization: .realEstate,
            scheduledDate: Date().addingTimeInterval(86400)
        )
        let backend = MockBackend(
            fetchBookingResult: booking,
            userProfileResult: MockBackend.sampleProfile(id: pilotId)
        )
        let notificationManager = MockNotificationManager()
        let mockPrefs = MockNotificationPreferences()
        // Disable booking reminder notifications
        mockPrefs.preferences.bookingReminders.system = false
        let service = BookingService(
            backend: backend,
            notificationManager: notificationManager,
            notificationPreferencesService: mockPrefs,
            skipNetworkCalls: false
        )

        try await service.acceptBooking(bookingId: bookingId, pilotId: pilotId)

        // Accepted notification should NOT fire since bookingReminders.system is false
        XCTAssertEqual(notificationManager.acceptedCalls, 0)
    }

    // MARK: - Booking Protocol Conformance

    func testBookingNotificationManaging_protocolMethodsExist() {
        // Compile-time check that the protocol covers all required notification methods
        let mock: BookingNotificationManaging = MockNotificationManager()
        XCTAssertNotNil(mock)
    }

    func testNotificationPreferencesProviding_protocolConformance() async throws {
        let mock: NotificationPreferencesProviding = MockNotificationPreferences()
        XCTAssertTrue(mock.preferences.bookingReminders.system)
        try await mock.loadPreferences(userId: UUID())
    }
}
