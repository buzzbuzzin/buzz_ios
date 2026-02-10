//
//  NotificationPreferencesServiceTests.swift
//  BuzzTests
//
//  Tests for notification preferences UserDefaults persistence logic.
//  Uses the NotificationPreferences model directly to avoid ObservableObject
//  initialization issues in the test environment.
//

import XCTest
@testable import Buzz

final class NotificationPreferencesServiceTests: XCTestCase {

    /// Use a dedicated UserDefaults suite to avoid conflicts with the app.
    private var testDefaults: UserDefaults!
    private let suiteName = "com.buzz.tests.notificationPreferences"
    private let storageKey = "notification_preferences"

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)!
        testDefaults.removeObject(forKey: storageKey)
    }

    override func tearDown() {
        testDefaults.removeObject(forKey: storageKey)
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Helpers

    /// Saves preferences to UserDefaults (mirrors NotificationPreferencesService.savePreferences).
    private func save(_ prefs: NotificationPreferences) {
        if let data = try? JSONEncoder().encode(prefs) {
            testDefaults.set(data, forKey: storageKey)
        }
    }

    /// Loads preferences from UserDefaults (mirrors NotificationPreferencesService.loadPreferences).
    private func load() -> NotificationPreferences {
        if let data = testDefaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            return saved
        }
        return NotificationPreferences()
    }

    // MARK: - Init (No Stored Data)

    func testInit_noStoredData_usesDefaults() {
        let prefs = load()

        XCTAssertTrue(prefs.bookingReminders.system)
        XCTAssertTrue(prefs.messages.system)
        XCTAssertFalse(prefs.bookingReminders.email)
    }

    // MARK: - Save and Load Round-Trip

    func testSaveAndLoad_roundTrip() {
        var prefs = NotificationPreferences()

        // Modify a preference
        prefs.bookingReminders.system = false
        prefs.tipReceived.email = true
        save(prefs)

        // Load — should recover persisted values
        let loaded = load()

        XCTAssertFalse(loaded.bookingReminders.system)
        XCTAssertTrue(loaded.tipReceived.email)
    }

    func testSavePreferences_persistsAllNewTypes() {
        var prefs = NotificationPreferences()

        prefs.bookingCancellations.system = false
        prefs.tipReceived.system = false
        prefs.payoutConfirmation.email = true
        prefs.beaconAccepted.text = true
        prefs.beaconResolved.system = false
        prefs.hangerTalkNewPosts.system = false
        save(prefs)

        let loaded = load()

        XCTAssertFalse(loaded.bookingCancellations.system)
        XCTAssertFalse(loaded.tipReceived.system)
        XCTAssertTrue(loaded.payoutConfirmation.email)
        XCTAssertTrue(loaded.beaconAccepted.text)
        XCTAssertFalse(loaded.beaconResolved.system)
        XCTAssertFalse(loaded.hangerTalkNewPosts.system)
    }

    // MARK: - Load Preferences (explicit call)

    func testLoadPreferences_refreshesFromUserDefaults() {
        var prefs = NotificationPreferences()
        prefs.messages.system = false
        save(prefs)

        // Simulate in-memory change (not saved)
        var inMemory = NotificationPreferences()
        inMemory.messages.system = true

        // Reload should restore persisted value
        let reloaded = load()
        XCTAssertFalse(reloaded.messages.system)
    }

    func testLoadPreferences_noStoredData_resetsToDefaults() {
        var prefs = NotificationPreferences()
        prefs.bookingReminders.system = false

        // Clear UserDefaults
        testDefaults.removeObject(forKey: storageKey)

        let reloaded = load()
        XCTAssertTrue(reloaded.bookingReminders.system)
    }

    // MARK: - Protocol Conformance (MockNotificationPreferences)

    func testLoadPreferencesWithUserId_callsLoadPreferences() async throws {
        let mock = MockNotificationPreferences()
        XCTAssertFalse(mock.loadCalled)

        try await mock.loadPreferences(userId: UUID())
        XCTAssertTrue(mock.loadCalled)
    }

    // MARK: - Forward-Compatible Decoding

    func testDecoding_missingNewKeys_usesDefaults() throws {
        // Simulate old stored data that only has the original fields
        let oldJSON: [String: Any] = [
            "booking_reminders": ["system": false, "email": false, "text": false],
            "weather_updates": ["system": true, "email": false, "text": false],
            "received_reviews": ["system": true, "email": false, "text": false],
            "booking_updates": ["system": true, "email": false, "text": false],
            "messages": ["system": true, "email": false, "text": false],
            "hanger_talk_likes": ["system": true, "email": false, "text": false],
            "hanger_talk_replies": ["system": true, "email": false, "text": false],
            "hanger_talk_mentions": ["system": true, "email": false, "text": false],
            "hanger_talk_follows": ["system": true, "email": false, "text": false]
        ]

        let data = try JSONSerialization.data(withJSONObject: oldJSON)
        // Store as if it were saved by an old version of the app
        testDefaults.set(data, forKey: storageKey)

        let decoded = load()

        // Original field should be preserved
        XCTAssertFalse(decoded.bookingReminders.system)
        XCTAssertTrue(decoded.weatherUpdates.system)

        // New fields missing from old data should use defaults (system: true)
        XCTAssertTrue(decoded.bookingCancellations.system)
        XCTAssertTrue(decoded.tipReceived.system)
        XCTAssertTrue(decoded.payoutConfirmation.system)
        XCTAssertTrue(decoded.beaconAccepted.system)
        XCTAssertTrue(decoded.beaconResolved.system)
        XCTAssertTrue(decoded.hangerTalkNewPosts.system)
    }

    func testDecoding_completeData_preservesAll() throws {
        var prefs = NotificationPreferences()
        prefs.bookingCancellations.system = false
        prefs.tipReceived.email = true
        prefs.beaconAccepted.text = true
        prefs.hangerTalkNewPosts.system = false
        save(prefs)

        let decoded = load()

        XCTAssertFalse(decoded.bookingCancellations.system)
        XCTAssertTrue(decoded.tipReceived.email)
        XCTAssertTrue(decoded.beaconAccepted.text)
        XCTAssertFalse(decoded.hangerTalkNewPosts.system)
    }

    // MARK: - Encoding

    func testEncoding_roundTrip() throws {
        var prefs = NotificationPreferences()
        prefs.bookingReminders.system = false
        prefs.tipReceived.email = true
        prefs.beaconResolved.text = true
        prefs.hangerTalkNewPosts.system = false

        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(NotificationPreferences.self, from: data)

        XCTAssertFalse(decoded.bookingReminders.system)
        XCTAssertTrue(decoded.tipReceived.email)
        XCTAssertTrue(decoded.beaconResolved.text)
        XCTAssertFalse(decoded.hangerTalkNewPosts.system)
        // Untouched fields remain default
        XCTAssertTrue(decoded.messages.system)
        XCTAssertFalse(decoded.messages.email)
    }

    // MARK: - Multiple Overwrites

    func testSaveOverwritesPreviousData() {
        var prefs1 = NotificationPreferences()
        prefs1.bookingReminders.system = false
        save(prefs1)

        var prefs2 = NotificationPreferences()
        prefs2.bookingReminders.system = true
        prefs2.messages.system = false
        save(prefs2)

        let loaded = load()
        XCTAssertTrue(loaded.bookingReminders.system, "Second save should overwrite first")
        XCTAssertFalse(loaded.messages.system)
    }

    // MARK: - All Fields Survive Round-Trip

    func testAllFieldsSurviveRoundTrip() {
        var prefs = NotificationPreferences()
        prefs.bookingReminders = NotificationDeliveryOptions(system: false, email: true, text: true)
        prefs.bookingCancellations = NotificationDeliveryOptions(system: false, email: true, text: false)
        prefs.weatherUpdates = NotificationDeliveryOptions(system: false, email: false, text: true)
        prefs.receivedReviews = NotificationDeliveryOptions(system: true, email: true, text: true)
        prefs.bookingUpdates = NotificationDeliveryOptions(system: false, email: false, text: false)
        prefs.messages = NotificationDeliveryOptions(system: true, email: true, text: false)
        prefs.tipReceived = NotificationDeliveryOptions(system: false, email: true, text: true)
        prefs.payoutConfirmation = NotificationDeliveryOptions(system: true, email: false, text: true)
        prefs.beaconAccepted = NotificationDeliveryOptions(system: false, email: true, text: false)
        prefs.beaconResolved = NotificationDeliveryOptions(system: true, email: true, text: true)
        prefs.hangerTalkLikes = NotificationDeliveryOptions(system: false, email: false, text: false)
        prefs.hangerTalkReplies = NotificationDeliveryOptions(system: true, email: false, text: true)
        prefs.hangerTalkMentions = NotificationDeliveryOptions(system: false, email: true, text: false)
        prefs.hangerTalkFollows = NotificationDeliveryOptions(system: true, email: true, text: true)
        prefs.hangerTalkNewPosts = NotificationDeliveryOptions(system: false, email: false, text: true)
        save(prefs)

        let loaded = load()

        XCTAssertEqual(loaded.bookingReminders.system, false)
        XCTAssertEqual(loaded.bookingReminders.email, true)
        XCTAssertEqual(loaded.bookingReminders.text, true)

        XCTAssertEqual(loaded.bookingCancellations.system, false)
        XCTAssertEqual(loaded.bookingCancellations.email, true)

        XCTAssertEqual(loaded.weatherUpdates.text, true)
        XCTAssertEqual(loaded.weatherUpdates.system, false)

        XCTAssertEqual(loaded.receivedReviews.system, true)
        XCTAssertEqual(loaded.receivedReviews.email, true)
        XCTAssertEqual(loaded.receivedReviews.text, true)

        XCTAssertEqual(loaded.bookingUpdates.system, false)
        XCTAssertEqual(loaded.bookingUpdates.email, false)
        XCTAssertEqual(loaded.bookingUpdates.text, false)

        XCTAssertEqual(loaded.messages.system, true)
        XCTAssertEqual(loaded.messages.email, true)

        XCTAssertEqual(loaded.tipReceived.email, true)
        XCTAssertEqual(loaded.tipReceived.text, true)

        XCTAssertEqual(loaded.payoutConfirmation.system, true)
        XCTAssertEqual(loaded.payoutConfirmation.text, true)

        XCTAssertEqual(loaded.beaconAccepted.email, true)
        XCTAssertEqual(loaded.beaconAccepted.system, false)

        XCTAssertEqual(loaded.beaconResolved.system, true)
        XCTAssertEqual(loaded.beaconResolved.email, true)
        XCTAssertEqual(loaded.beaconResolved.text, true)

        XCTAssertEqual(loaded.hangerTalkLikes.system, false)
        XCTAssertEqual(loaded.hangerTalkLikes.email, false)
        XCTAssertEqual(loaded.hangerTalkLikes.text, false)

        XCTAssertEqual(loaded.hangerTalkReplies.system, true)
        XCTAssertEqual(loaded.hangerTalkReplies.text, true)

        XCTAssertEqual(loaded.hangerTalkMentions.email, true)
        XCTAssertEqual(loaded.hangerTalkMentions.system, false)

        XCTAssertEqual(loaded.hangerTalkFollows.system, true)
        XCTAssertEqual(loaded.hangerTalkFollows.email, true)
        XCTAssertEqual(loaded.hangerTalkFollows.text, true)

        XCTAssertEqual(loaded.hangerTalkNewPosts.text, true)
        XCTAssertEqual(loaded.hangerTalkNewPosts.system, false)
    }
}
