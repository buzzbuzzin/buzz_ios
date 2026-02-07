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
        XCTAssertTrue(prefs.weatherUpdates.system)
        XCTAssertTrue(prefs.receivedReviews.system)
        XCTAssertTrue(prefs.rankImprovements.system)
        XCTAssertTrue(prefs.bookingUpdates.system)
        XCTAssertTrue(prefs.messages.system)
    }

    func testDefaultPreferences_emailAndTextDisabled() {
        let prefs = NotificationPreferences()

        XCTAssertFalse(prefs.bookingReminders.email)
        XCTAssertFalse(prefs.bookingReminders.text)
        XCTAssertFalse(prefs.weatherUpdates.email)
        XCTAssertFalse(prefs.weatherUpdates.text)
        XCTAssertFalse(prefs.messages.email)
        XCTAssertFalse(prefs.messages.text)
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
}
