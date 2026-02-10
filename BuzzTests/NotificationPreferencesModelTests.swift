//
//  NotificationPreferencesModelTests.swift
//  BuzzTests
//
//  Tests for NotificationPreferences and NotificationDeliveryOptions.
//

import XCTest
@testable import Buzz

final class NotificationPreferencesModelTests: XCTestCase {

    // MARK: - Default Preferences

    func testDefaultPreferences_allSystemEnabled() {
        let prefs = NotificationPreferences()

        XCTAssertTrue(prefs.bookingReminders.system)
        XCTAssertTrue(prefs.bookingCancellations.system)
        XCTAssertTrue(prefs.weatherUpdates.system)
        XCTAssertTrue(prefs.receivedReviews.system)
        XCTAssertTrue(prefs.bookingUpdates.system)
        XCTAssertTrue(prefs.messages.system)
        XCTAssertTrue(prefs.tipReceived.system)
        XCTAssertTrue(prefs.payoutConfirmation.system)
        XCTAssertTrue(prefs.beaconAccepted.system)
        XCTAssertTrue(prefs.beaconResolved.system)
        XCTAssertTrue(prefs.hangerTalkLikes.system)
        XCTAssertTrue(prefs.hangerTalkReplies.system)
        XCTAssertTrue(prefs.hangerTalkMentions.system)
        XCTAssertTrue(prefs.hangerTalkFollows.system)
        XCTAssertTrue(prefs.hangerTalkNewPosts.system)
    }

    func testDefaultPreferences_emailAndTextDisabled() {
        let prefs = NotificationPreferences()

        XCTAssertFalse(prefs.bookingReminders.email)
        XCTAssertFalse(prefs.bookingReminders.text)
        XCTAssertFalse(prefs.weatherUpdates.email)
        XCTAssertFalse(prefs.weatherUpdates.text)
        XCTAssertFalse(prefs.messages.email)
        XCTAssertFalse(prefs.messages.text)
        XCTAssertFalse(prefs.bookingCancellations.email)
        XCTAssertFalse(prefs.bookingCancellations.text)
        XCTAssertFalse(prefs.tipReceived.email)
        XCTAssertFalse(prefs.tipReceived.text)
        XCTAssertFalse(prefs.payoutConfirmation.email)
        XCTAssertFalse(prefs.payoutConfirmation.text)
        XCTAssertFalse(prefs.beaconAccepted.email)
        XCTAssertFalse(prefs.beaconAccepted.text)
        XCTAssertFalse(prefs.beaconResolved.email)
        XCTAssertFalse(prefs.beaconResolved.text)
        XCTAssertFalse(prefs.hangerTalkNewPosts.email)
        XCTAssertFalse(prefs.hangerTalkNewPosts.text)
    }

    // MARK: - Mutability

    func testPreferences_canToggleNewTypes() {
        var prefs = NotificationPreferences()

        prefs.bookingCancellations.system = false
        XCTAssertFalse(prefs.bookingCancellations.system)
        XCTAssertFalse(prefs.bookingCancellations.isEnabled)

        prefs.tipReceived.email = true
        XCTAssertTrue(prefs.tipReceived.isEnabled)

        prefs.payoutConfirmation.text = true
        XCTAssertTrue(prefs.payoutConfirmation.isEnabled)

        prefs.beaconAccepted.system = false
        prefs.beaconAccepted.email = true
        XCTAssertTrue(prefs.beaconAccepted.isEnabled)

        prefs.beaconResolved = NotificationDeliveryOptions(system: false, email: false, text: false)
        XCTAssertFalse(prefs.beaconResolved.isEnabled)

        prefs.hangerTalkNewPosts.system = false
        XCTAssertFalse(prefs.hangerTalkNewPosts.isEnabled)
    }

    // MARK: - NotificationDeliveryOptions isEnabled

    func testDeliveryOptions_isEnabled_someTrue() {
        let options = NotificationDeliveryOptions(system: true, email: false, text: false)
        XCTAssertTrue(options.isEnabled)
    }

    func testDeliveryOptions_isEnabled_allFalse() {
        let options = NotificationDeliveryOptions(system: false, email: false, text: false)
        XCTAssertFalse(options.isEnabled)
    }

    func testDeliveryOptions_isEnabled_allTrue() {
        let options = NotificationDeliveryOptions(system: true, email: true, text: true)
        XCTAssertTrue(options.isEnabled)
    }

    func testDeliveryOptions_isEnabled_onlyEmail() {
        let options = NotificationDeliveryOptions(system: false, email: true, text: false)
        XCTAssertTrue(options.isEnabled)
    }

    func testDeliveryOptions_isEnabled_onlyText() {
        let options = NotificationDeliveryOptions(system: false, email: false, text: true)
        XCTAssertTrue(options.isEnabled)
    }

    // MARK: - Defaults

    func testDeliveryOptions_defaultInit() {
        let options = NotificationDeliveryOptions()
        XCTAssertFalse(options.system)
        XCTAssertFalse(options.email)
        XCTAssertFalse(options.text)
        XCTAssertFalse(options.isEnabled)
    }

    // MARK: - Codable Round-Trip

    func testPreferences_codableRoundTrip() throws {
        var prefs = NotificationPreferences()
        prefs.bookingCancellations.system = false
        prefs.tipReceived.email = true
        prefs.beaconAccepted.text = true
        prefs.hangerTalkNewPosts.system = false

        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(NotificationPreferences.self, from: data)

        XCTAssertFalse(decoded.bookingCancellations.system)
        XCTAssertTrue(decoded.tipReceived.email)
        XCTAssertTrue(decoded.beaconAccepted.text)
        XCTAssertFalse(decoded.hangerTalkNewPosts.system)
        // Unchanged fields preserved
        XCTAssertTrue(decoded.bookingReminders.system)
        XCTAssertTrue(decoded.messages.system)
    }

    func testPreferences_forwardCompatibleDecoding_missingNewKeys() throws {
        // Simulate data from before the new fields existed
        let oldJSON: [String: Any] = [
            "booking_reminders": ["system": true, "email": false, "text": false],
            "weather_updates": ["system": true, "email": false, "text": false],
            "received_reviews": ["system": true, "email": false, "text": false],
            "booking_updates": ["system": true, "email": false, "text": false],
            "messages": ["system": true, "email": false, "text": false],
            "hanger_talk_likes": ["system": false, "email": false, "text": false],
            "hanger_talk_replies": ["system": true, "email": false, "text": false],
            "hanger_talk_mentions": ["system": true, "email": false, "text": false],
            "hanger_talk_follows": ["system": true, "email": false, "text": false]
        ]

        let data = try JSONSerialization.data(withJSONObject: oldJSON)
        let decoded = try JSONDecoder().decode(NotificationPreferences.self, from: data)

        // Old fields preserved
        XCTAssertTrue(decoded.bookingReminders.system)
        XCTAssertFalse(decoded.hangerTalkLikes.system)

        // New fields default to system=true
        XCTAssertTrue(decoded.bookingCancellations.system)
        XCTAssertTrue(decoded.tipReceived.system)
        XCTAssertTrue(decoded.payoutConfirmation.system)
        XCTAssertTrue(decoded.beaconAccepted.system)
        XCTAssertTrue(decoded.beaconResolved.system)
        XCTAssertTrue(decoded.hangerTalkNewPosts.system)

        // New fields default email/text to false
        XCTAssertFalse(decoded.bookingCancellations.email)
        XCTAssertFalse(decoded.tipReceived.text)
    }
}
