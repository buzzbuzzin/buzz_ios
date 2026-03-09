//
//  NotificationManagerTests.swift
//  BuzzTests
//
//  Tests for NotificationManager.isNotificationEnabled preference mapping.
//

import XCTest
@testable import Buzz

@MainActor
final class NotificationManagerTests: XCTestCase {

    // Uses the shared singleton, which is safe here because isNotificationEnabled
    // is a pure function: it reads only from the passed-in preferences struct and
    // never mutates manager state, so tests remain independent.
    private let manager = NotificationManager.shared

    // MARK: - Booking Categories

    func testIsEnabled_bookingAccepted_mapsToBookingReminders() {
        var prefs = NotificationPreferences()
        XCTAssertTrue(manager.isNotificationEnabled(preferences: prefs, type: .bookingAccepted))

        prefs.bookingReminders.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .bookingAccepted))
    }

    func testIsEnabled_bookingReminder_mapsToBookingReminders() {
        var prefs = NotificationPreferences()
        prefs.bookingReminders.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .bookingReminder))
    }

    func testIsEnabled_bookingCancelled_mapsToBookingCancellations() {
        var prefs = NotificationPreferences()
        XCTAssertTrue(manager.isNotificationEnabled(preferences: prefs, type: .bookingCancelled))

        prefs.bookingCancellations.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .bookingCancelled))
    }

    func testIsEnabled_nearbyBooking_mapsToBookingUpdates() {
        var prefs = NotificationPreferences()
        prefs.bookingUpdates.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .nearbyBooking))
    }

    func testIsEnabled_crewBookingAccepted_mapsToBookingReminders() {
        var prefs = NotificationPreferences()
        prefs.bookingReminders.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .crewBookingAccepted))
    }

    func testIsEnabled_crewBookingCompleted_mapsToBookingReminders() {
        var prefs = NotificationPreferences()
        prefs.bookingReminders.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .crewBookingCompleted))
    }

    // MARK: - Financial Categories

    func testIsEnabled_tipReceived_mapsToTipReceived() {
        var prefs = NotificationPreferences()
        XCTAssertTrue(manager.isNotificationEnabled(preferences: prefs, type: .tipReceived))

        prefs.tipReceived.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .tipReceived))
    }

    func testIsEnabled_payoutConfirmation_mapsToPayoutConfirmation() {
        var prefs = NotificationPreferences()
        XCTAssertTrue(manager.isNotificationEnabled(preferences: prefs, type: .payoutConfirmation))

        prefs.payoutConfirmation.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .payoutConfirmation))
    }

    // MARK: - Communication Categories

    func testIsEnabled_newMessage_mapsToMessages() {
        var prefs = NotificationPreferences()
        prefs.messages.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .newMessage))
    }

    func testIsEnabled_receivedReview_mapsToReceivedReviews() {
        var prefs = NotificationPreferences()
        prefs.receivedReviews.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .receivedReview))
    }

    // MARK: - Weather & Drone Categories

    func testIsEnabled_weatherChange_mapsToWeatherUpdates() {
        var prefs = NotificationPreferences()
        prefs.weatherUpdates.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .weatherChange))
    }

    func testIsEnabled_droneActivity_mapsToWeatherUpdates() {
        var prefs = NotificationPreferences()
        prefs.weatherUpdates.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .droneActivity))
    }

    // MARK: - Beacon Categories

    func testIsEnabled_emergencyBeacon_alwaysEnabled() {
        var prefs = NotificationPreferences()
        // Emergency beacons bypass all user preferences
        prefs.beaconAccepted.system = false
        prefs.beaconResolved.system = false
        XCTAssertTrue(manager.isNotificationEnabled(preferences: prefs, type: .emergencyBeacon))
        XCTAssertTrue(manager.isNotificationEnabled(preferences: prefs, type: .emergencyBeaconUrgent))
    }

    func testIsEnabled_beaconAccepted_mapsToBeaconAccepted() {
        var prefs = NotificationPreferences()
        XCTAssertTrue(manager.isNotificationEnabled(preferences: prefs, type: .beaconAccepted))

        prefs.beaconAccepted.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .beaconAccepted))
    }

    func testIsEnabled_beaconResolved_mapsToBeaconResolved() {
        var prefs = NotificationPreferences()
        XCTAssertTrue(manager.isNotificationEnabled(preferences: prefs, type: .beaconResolved))

        prefs.beaconResolved.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .beaconResolved))
    }

    func testIsEnabled_licenseApproved_alwaysEnabled() {
        var prefs = NotificationPreferences()
        prefs.messages.system = false
        XCTAssertTrue(manager.isNotificationEnabled(preferences: prefs, type: .licenseApproved))
    }

    func testIsEnabled_licenseRejected_alwaysEnabled() {
        var prefs = NotificationPreferences()
        prefs.bookingUpdates.system = false
        XCTAssertTrue(manager.isNotificationEnabled(preferences: prefs, type: .licenseRejected))
    }

    // MARK: - Hanger Talk Categories

    func testIsEnabled_hangerTalkLike_mapsToHangerTalkLikes() {
        var prefs = NotificationPreferences()
        prefs.hangerTalkLikes.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .hangerTalkLike))
    }

    func testIsEnabled_hangerTalkReply_mapsToHangerTalkReplies() {
        var prefs = NotificationPreferences()
        prefs.hangerTalkReplies.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .hangerTalkReply))
    }

    func testIsEnabled_hangerTalkMention_mapsToHangerTalkMentions() {
        var prefs = NotificationPreferences()
        prefs.hangerTalkMentions.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .hangerTalkMention))
    }

    func testIsEnabled_hangerTalkFollow_mapsToHangerTalkFollows() {
        var prefs = NotificationPreferences()
        prefs.hangerTalkFollows.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .hangerTalkFollow))
    }

    func testIsEnabled_hangerTalkNewPost_mapsToHangerTalkNewPosts() {
        var prefs = NotificationPreferences()
        XCTAssertTrue(manager.isNotificationEnabled(preferences: prefs, type: .hangerTalkNewPost))

        prefs.hangerTalkNewPosts.system = false
        XCTAssertFalse(manager.isNotificationEnabled(preferences: prefs, type: .hangerTalkNewPost))
    }

    // MARK: - All Categories Default Enabled

    func testIsEnabled_allCategories_enabledByDefault() {
        let prefs = NotificationPreferences()
        let allCategories: [NotificationManager.NotificationCategory] = [
            .bookingAccepted, .bookingReminder, .bookingCancelled,
            .newMessage, .nearbyBooking, .droneActivity, .weatherChange,
            .receivedReview, .crewBookingAccepted, .crewBookingCompleted,
            .tipReceived, .payoutConfirmation,
            .emergencyBeacon, .emergencyBeaconUrgent,
            .beaconAccepted, .beaconResolved,
            .licenseApproved, .licenseRejected,
            .hangerTalkLike, .hangerTalkReply, .hangerTalkMention,
            .hangerTalkFollow, .hangerTalkNewPost
        ]

        for category in allCategories {
            XCTAssertTrue(
                manager.isNotificationEnabled(preferences: prefs, type: category),
                "\(category.rawValue) should be enabled by default"
            )
        }
    }
}
