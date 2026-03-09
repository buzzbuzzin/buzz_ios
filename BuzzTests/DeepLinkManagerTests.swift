//
//  DeepLinkManagerTests.swift
//  BuzzTests
//
//  Tests for DeepLinkManager notification-to-destination routing and
//  the NotificationManager → DeepLinkManager integration path.
//

import XCTest
@testable import Buzz

// MARK: - DeepLinkDestination Equatable Sanity

@MainActor
final class DeepLinkDestinationTests: XCTestCase {

    func testEquatable_simpleCase_weather() {
        XCTAssertEqual(DeepLinkDestination.weather, DeepLinkDestination.weather)
    }

    func testEquatable_simpleCase_flightRadar() {
        XCTAssertEqual(DeepLinkDestination.flightRadar, DeepLinkDestination.flightRadar)
    }

    func testEquatable_simpleCase_jobs() {
        XCTAssertEqual(DeepLinkDestination.jobs, DeepLinkDestination.jobs)
    }

    func testEquatable_simpleCase_profile() {
        XCTAssertEqual(DeepLinkDestination.profile, DeepLinkDestination.profile)
    }

    func testEquatable_simpleCase_hangerTalkInbox() {
        XCTAssertEqual(DeepLinkDestination.hangerTalkInbox, DeepLinkDestination.hangerTalkInbox)
    }

    func testEquatable_associatedValue_sameId() {
        let id = UUID()
        XCTAssertEqual(
            DeepLinkDestination.hangerTalkPost(postId: id),
            DeepLinkDestination.hangerTalkPost(postId: id)
        )
    }

    func testEquatable_associatedValue_differentIds() {
        XCTAssertNotEqual(
            DeepLinkDestination.hangerTalkPost(postId: UUID()),
            DeepLinkDestination.hangerTalkPost(postId: UUID())
        )
    }

    func testEquatable_differentCases() {
        XCTAssertNotEqual(DeepLinkDestination.weather, DeepLinkDestination.flightRadar)
        XCTAssertNotEqual(DeepLinkDestination.jobs, DeepLinkDestination.profile)
    }
}

// MARK: - DeepLinkManager.handleNotificationTap

@MainActor
final class DeepLinkManagerTests: XCTestCase {

    private var manager: DeepLinkManager!

    override func setUp() {
        super.setUp()
        manager = DeepLinkManager.shared
        manager.pendingDestination = nil
    }

    override func tearDown() {
        manager.pendingDestination = nil
        super.tearDown()
    }

    // MARK: - Booking Notifications

    func testBookingAccepted_setsBookingDetail() {
        let bookingId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "booking_accepted",
            "bookingId": bookingId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .bookingDetail(bookingId: bookingId))
    }

    func testBookingReminder_setsBookingDetail() {
        let bookingId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "booking_reminder",
            "bookingId": bookingId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .bookingDetail(bookingId: bookingId))
    }

    func testBookingCancelled_setsBookingDetail() {
        let bookingId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "booking_cancelled",
            "bookingId": bookingId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .bookingDetail(bookingId: bookingId))
    }

    func testCrewBookingAccepted_setsBookingDetail() {
        let bookingId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "crew_booking_accepted",
            "bookingId": bookingId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .bookingDetail(bookingId: bookingId))
    }

    func testCrewBookingCompleted_setsBookingDetail() {
        let bookingId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "crew_booking_completed",
            "bookingId": bookingId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .bookingDetail(bookingId: bookingId))
    }

    func testBookingAccepted_missingBookingId_doesNotSetDestination() {
        manager.handleNotificationTap(userInfo: [
            "type": "booking_accepted"
        ])
        XCTAssertNil(manager.pendingDestination)
    }

    func testBookingAccepted_invalidBookingId_doesNotSetDestination() {
        manager.handleNotificationTap(userInfo: [
            "type": "booking_accepted",
            "bookingId": "not-a-uuid"
        ])
        XCTAssertNil(manager.pendingDestination)
    }

    // MARK: - Financial Notifications

    func testTipReceived_setsBookingDetail() {
        let bookingId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "tip_received",
            "bookingId": bookingId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .bookingDetail(bookingId: bookingId))
    }

    func testPayoutConfirmation_setsBookingDetail() {
        let bookingId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "payout_confirmation",
            "bookingId": bookingId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .bookingDetail(bookingId: bookingId))
    }

    // MARK: - Message Notifications

    func testNewMessage_setsMessages() {
        let conversationId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "new_message",
            "conversationId": conversationId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .messages(conversationId: conversationId))
    }

    func testNewMessage_missingConversationId_doesNotSetDestination() {
        manager.handleNotificationTap(userInfo: [
            "type": "new_message"
        ])
        XCTAssertNil(manager.pendingDestination)
    }

    func testNewMessage_invalidConversationId_doesNotSetDestination() {
        manager.handleNotificationTap(userInfo: [
            "type": "new_message",
            "conversationId": "invalid"
        ])
        XCTAssertNil(manager.pendingDestination)
    }

    // MARK: - Nearby Booking

    func testNearbyBooking_setsJobs() {
        manager.handleNotificationTap(userInfo: [
            "type": "nearby_booking"
        ])
        XCTAssertEqual(manager.pendingDestination, .jobs)
    }

    // MARK: - Drone Activity

    func testDroneActivity_setsFlightRadar() {
        manager.handleNotificationTap(userInfo: [
            "type": "drone_activity"
        ])
        XCTAssertEqual(manager.pendingDestination, .flightRadar)
    }

    // MARK: - Weather Notifications

    func testWeatherChange_setsWeather() {
        manager.handleNotificationTap(userInfo: [
            "type": "weather_change"
        ])
        XCTAssertEqual(manager.pendingDestination, .weather)
    }

    func testNWSWeatherAlert_setsWeather() {
        manager.handleNotificationTap(userInfo: [
            "type": "nws_weather_alert",
            "alertId": "NWS-ALERT-123",
            "event": "Tornado Warning",
            "severity": "extreme"
        ])
        XCTAssertEqual(manager.pendingDestination, .weather)
    }

    // MARK: - Review Notifications

    func testReceivedReview_setsProfile() {
        manager.handleNotificationTap(userInfo: [
            "type": "received_review"
        ])
        XCTAssertEqual(manager.pendingDestination, .profile)
    }

    // MARK: - Hanger Talk Like

    func testHangerTalkLike_setsHangerTalkPost() {
        let postId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "hanger_talk_like",
            "postId": postId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .hangerTalkPost(postId: postId))
    }

    func testHangerTalkLike_missingPostId_doesNotSetDestination() {
        manager.handleNotificationTap(userInfo: [
            "type": "hanger_talk_like"
        ])
        XCTAssertNil(manager.pendingDestination)
    }

    // MARK: - Hanger Talk Mention

    func testHangerTalkMention_setsHangerTalkPost() {
        let postId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "hanger_talk_mention",
            "postId": postId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .hangerTalkPost(postId: postId))
    }

    // MARK: - Hanger Talk New Post

    func testHangerTalkNewPost_setsHangerTalkPost() {
        let postId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "hanger_talk_new_post",
            "postId": postId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .hangerTalkPost(postId: postId))
    }

    // MARK: - Hanger Talk Reply

    func testHangerTalkReply_withParentPostId_navigatesToParent() {
        let postId = UUID()
        let parentPostId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "hanger_talk_reply",
            "postId": postId.uuidString,
            "parentPostId": parentPostId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .hangerTalkPost(postId: parentPostId))
    }

    func testHangerTalkReply_withoutParentPostId_fallsBackToPostId() {
        let postId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "hanger_talk_reply",
            "postId": postId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .hangerTalkPost(postId: postId))
    }

    func testHangerTalkReply_noIds_doesNotSetDestination() {
        manager.handleNotificationTap(userInfo: [
            "type": "hanger_talk_reply"
        ])
        XCTAssertNil(manager.pendingDestination)
    }

    // MARK: - Hanger Talk Follow

    func testHangerTalkFollow_setsHangerTalkInbox() {
        manager.handleNotificationTap(userInfo: [
            "type": "hanger_talk_follow"
        ])
        XCTAssertEqual(manager.pendingDestination, .hangerTalkInbox)
    }

    // MARK: - Beacon / Emergency Notifications

    func testEmergencyBeacon_setsBookingDetail() {
        let bookingId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "emergency_beacon",
            "bookingId": bookingId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .bookingDetail(bookingId: bookingId))
    }

    func testEmergencyBeaconUrgent_setsBookingDetail() {
        let bookingId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "emergency_beacon_urgent",
            "bookingId": bookingId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .bookingDetail(bookingId: bookingId))
    }

    func testBeaconAccepted_setsBookingDetail() {
        let bookingId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "beacon_accepted",
            "bookingId": bookingId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .bookingDetail(bookingId: bookingId))
    }

    func testBeaconResolved_setsBookingDetail() {
        let bookingId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "beacon_resolved",
            "bookingId": bookingId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .bookingDetail(bookingId: bookingId))
    }

    func testLicenseApproved_setsLicenseManagement() {
        manager.handleNotificationTap(userInfo: [
            "type": "license_approved"
        ])
        XCTAssertEqual(manager.pendingDestination, .licenseManagement)
    }

    func testLicenseRejected_setsLicenseManagement() {
        manager.handleNotificationTap(userInfo: [
            "type": "license_rejected"
        ])
        XCTAssertEqual(manager.pendingDestination, .licenseManagement)
    }

    func testEmergencyBeacon_missingBookingId_doesNotSetDestination() {
        manager.handleNotificationTap(userInfo: [
            "type": "emergency_beacon"
        ])
        XCTAssertNil(manager.pendingDestination)
    }

    // MARK: - Edge Cases

    func testMissingType_doesNotSetDestination() {
        manager.handleNotificationTap(userInfo: [
            "bookingId": UUID().uuidString
        ])
        XCTAssertNil(manager.pendingDestination)
    }

    func testEmptyUserInfo_doesNotSetDestination() {
        manager.handleNotificationTap(userInfo: [:])
        XCTAssertNil(manager.pendingDestination)
    }

    func testUnknownType_doesNotSetDestination() {
        manager.handleNotificationTap(userInfo: [
            "type": "some_unknown_type"
        ])
        XCTAssertNil(manager.pendingDestination)
    }

    func testTypeAsNonString_doesNotSetDestination() {
        manager.handleNotificationTap(userInfo: [
            "type": 42
        ])
        XCTAssertNil(manager.pendingDestination)
    }

    func testConsecutiveTaps_overwritesPendingDestination() {
        let bookingId1 = UUID()
        let bookingId2 = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "booking_accepted",
            "bookingId": bookingId1.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .bookingDetail(bookingId: bookingId1))

        // Second tap overwrites
        manager.handleNotificationTap(userInfo: [
            "type": "booking_accepted",
            "bookingId": bookingId2.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .bookingDetail(bookingId: bookingId2))
    }

    func testClearingDestination_resetsToNil() {
        manager.handleNotificationTap(userInfo: [
            "type": "weather_change"
        ])
        XCTAssertNotNil(manager.pendingDestination)

        manager.pendingDestination = nil
        XCTAssertNil(manager.pendingDestination)
    }
}

// MARK: - Remote Push Payload Integration Tests

/// Tests that the NotificationManager correctly resolves the nested "data"
/// key from remote push payloads before forwarding to DeepLinkManager.
@MainActor
final class DeepLinkRemotePushTests: XCTestCase {

    private var manager: DeepLinkManager!

    override func setUp() {
        super.setUp()
        manager = DeepLinkManager.shared
        manager.pendingDestination = nil
    }

    override func tearDown() {
        manager.pendingDestination = nil
        super.tearDown()
    }

    /// Simulates the resolution logic from NotificationManager.handleNotificationTap
    /// that merges the nested "data" dictionary into the top level.
    private func resolveAndHandle(userInfo: [AnyHashable: Any]) {
        var resolvedInfo = userInfo
        if let data = userInfo["data"] as? [String: Any] {
            for (key, value) in data {
                resolvedInfo[key] = value
            }
        }
        manager.handleNotificationTap(userInfo: resolvedInfo)
    }

    // MARK: - Remote Push Payloads (nested under "data" key)

    func testRemotePush_hangerTalkLike_resolvedFromNestedData() {
        let postId = UUID()
        // Remote push payloads nest custom data under "data" key
        resolveAndHandle(userInfo: [
            "aps": ["alert": ["title": "New Like", "body": "Someone liked your post"]],
            "data": [
                "type": "hanger_talk_like",
                "postId": postId.uuidString
            ]
        ])
        XCTAssertEqual(manager.pendingDestination, .hangerTalkPost(postId: postId))
    }

    func testRemotePush_hangerTalkReply_resolvedFromNestedData() {
        let postId = UUID()
        let parentPostId = UUID()
        resolveAndHandle(userInfo: [
            "aps": ["alert": ["title": "New Reply", "body": "Someone replied"]],
            "data": [
                "type": "hanger_talk_reply",
                "postId": postId.uuidString,
                "parentPostId": parentPostId.uuidString
            ]
        ])
        XCTAssertEqual(manager.pendingDestination, .hangerTalkPost(postId: parentPostId))
    }

    func testRemotePush_hangerTalkMention_resolvedFromNestedData() {
        let postId = UUID()
        resolveAndHandle(userInfo: [
            "aps": ["alert": ["title": "Mentioned", "body": "You were mentioned"]],
            "data": [
                "type": "hanger_talk_mention",
                "postId": postId.uuidString
            ]
        ])
        XCTAssertEqual(manager.pendingDestination, .hangerTalkPost(postId: postId))
    }

    func testRemotePush_hangerTalkFollow_resolvedFromNestedData() {
        resolveAndHandle(userInfo: [
            "aps": ["alert": ["title": "New Follower", "body": "Someone followed you"]],
            "data": [
                "type": "hanger_talk_follow"
            ]
        ])
        XCTAssertEqual(manager.pendingDestination, .hangerTalkInbox)
    }

    func testRemotePush_hangerTalkNewPost_resolvedFromNestedData() {
        let postId = UUID()
        resolveAndHandle(userInfo: [
            "aps": ["alert": ["title": "New Post", "body": "Someone posted"]],
            "data": [
                "type": "hanger_talk_new_post",
                "postId": postId.uuidString
            ]
        ])
        XCTAssertEqual(manager.pendingDestination, .hangerTalkPost(postId: postId))
    }

    func testRemotePush_licenseApproved_resolvedFromNestedData() {
        resolveAndHandle(userInfo: [
            "aps": ["alert": ["title": "License Approved", "body": "Your credential was approved"]],
            "data": [
                "type": "license_approved",
                "license_id": UUID().uuidString
            ]
        ])
        XCTAssertEqual(manager.pendingDestination, .licenseManagement)
    }

    func testRemotePush_licenseRejected_resolvedFromNestedData() {
        resolveAndHandle(userInfo: [
            "aps": ["alert": ["title": "License Needs Attention", "body": "Please re-upload"]],
            "data": [
                "type": "license_rejected",
                "license_id": UUID().uuidString
            ]
        ])
        XCTAssertEqual(manager.pendingDestination, .licenseManagement)
    }

    // MARK: - Local Notification Payloads (top-level keys, no "data" wrapper)

    func testLocalNotification_weatherChange_topLevelKeys() {
        resolveAndHandle(userInfo: [
            "type": "weather_change",
            "condition": "Rain",
            "location": "San Francisco"
        ])
        XCTAssertEqual(manager.pendingDestination, .weather)
    }

    func testLocalNotification_bookingAccepted_topLevelKeys() {
        let bookingId = UUID()
        resolveAndHandle(userInfo: [
            "type": "booking_accepted",
            "bookingId": bookingId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .bookingDetail(bookingId: bookingId))
    }

    func testLocalNotification_droneActivity_topLevelKeys() {
        resolveAndHandle(userInfo: [
            "type": "drone_activity",
            "location": "Airport",
            "altitude": 400
        ])
        XCTAssertEqual(manager.pendingDestination, .flightRadar)
    }

    func testLocalNotification_nwsWeatherAlert_topLevelKeys() {
        resolveAndHandle(userInfo: [
            "type": "nws_weather_alert",
            "alertId": "NWS-ALERT-456",
            "event": "Severe Thunderstorm Warning",
            "severity": "severe"
        ])
        XCTAssertEqual(manager.pendingDestination, .weather)
    }

    func testLocalNotification_receivedReview_topLevelKeys() {
        let bookingId = UUID()
        resolveAndHandle(userInfo: [
            "type": "received_review",
            "bookingId": bookingId.uuidString,
            "rating": 5
        ])
        XCTAssertEqual(manager.pendingDestination, .profile)
    }

    func testLocalNotification_nearbyBooking_topLevelKeys() {
        resolveAndHandle(userInfo: [
            "type": "nearby_booking",
            "bookingId": UUID().uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .jobs)
    }

    func testLocalNotification_newMessage_topLevelKeys() {
        let conversationId = UUID()
        resolveAndHandle(userInfo: [
            "type": "new_message",
            "conversationId": conversationId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .messages(conversationId: conversationId))
    }

    func testLocalNotification_emergencyBeacon_topLevelKeys() {
        let bookingId = UUID()
        resolveAndHandle(userInfo: [
            "type": "emergency_beacon",
            "bookingId": bookingId.uuidString,
            "location": "Mountain Trail",
            "distanceMiles": 3.5,
            "missionType": "Search & Rescue"
        ])
        XCTAssertEqual(manager.pendingDestination, .bookingDetail(bookingId: bookingId))
    }

    // MARK: - Mixed / Edge Cases

    func testRemotePush_emptyDataDict_doesNotSetDestination() {
        resolveAndHandle(userInfo: [
            "aps": ["alert": ["title": "Test", "body": "Test"]],
            "data": [String: Any]()
        ])
        XCTAssertNil(manager.pendingDestination)
    }

    func testRemotePush_dataDictWithMissingType_doesNotSetDestination() {
        resolveAndHandle(userInfo: [
            "aps": ["alert": ["title": "Test", "body": "Test"]],
            "data": [
                "postId": UUID().uuidString
            ]
        ])
        XCTAssertNil(manager.pendingDestination)
    }

    func testRemotePush_noDataKey_noTopLevelType_doesNotSetDestination() {
        resolveAndHandle(userInfo: [
            "aps": ["alert": ["title": "Test", "body": "Test"]]
        ])
        XCTAssertNil(manager.pendingDestination)
    }
}

// MARK: - All Notification Types Coverage

/// Verifies that every notification type string dispatched by the app
/// is handled by DeepLinkManager and produces a non-nil destination
/// (when valid associated data is present).
@MainActor
final class DeepLinkAllTypesTests: XCTestCase {

    private var manager: DeepLinkManager!
    private let sampleBookingId = UUID()
    private let samplePostId = UUID()
    private let sampleConversationId = UUID()

    override func setUp() {
        super.setUp()
        manager = DeepLinkManager.shared
        manager.pendingDestination = nil
    }

    override func tearDown() {
        manager.pendingDestination = nil
        super.tearDown()
    }

    /// All notification types that require a bookingId
    func testAllBookingTypes_produceBookingDetail() {
        let bookingTypes = [
            "booking_accepted",
            "booking_reminder",
            "booking_cancelled",
            "crew_booking_accepted",
            "crew_booking_completed",
            "tip_received",
            "payout_confirmation",
            "emergency_beacon",
            "emergency_beacon_urgent",
            "beacon_accepted",
            "beacon_resolved"
        ]

        for type in bookingTypes {
            manager.pendingDestination = nil
            manager.handleNotificationTap(userInfo: [
                "type": type,
                "bookingId": sampleBookingId.uuidString
            ])
            XCTAssertEqual(
                manager.pendingDestination,
                .bookingDetail(bookingId: sampleBookingId),
                "Type '\(type)' should produce .bookingDetail"
            )
        }
    }

    /// All notification types that require a postId
    func testAllPostTypes_produceHangerTalkPost() {
        let postTypes = [
            "hanger_talk_like",
            "hanger_talk_mention",
            "hanger_talk_new_post"
        ]

        for type in postTypes {
            manager.pendingDestination = nil
            manager.handleNotificationTap(userInfo: [
                "type": type,
                "postId": samplePostId.uuidString
            ])
            XCTAssertEqual(
                manager.pendingDestination,
                .hangerTalkPost(postId: samplePostId),
                "Type '\(type)' should produce .hangerTalkPost"
            )
        }
    }

    /// Simple destination types with no associated data
    func testSimpleTypes_produceCorrectDestinations() {
        let typeToDestination: [(String, DeepLinkDestination)] = [
            ("nearby_booking", .jobs),
            ("drone_activity", .flightRadar),
            ("weather_change", .weather),
            ("nws_weather_alert", .weather),
            ("received_review", .profile),
            ("license_approved", .licenseManagement),
            ("license_rejected", .licenseManagement),
            ("hanger_talk_follow", .hangerTalkInbox)
        ]

        for (type, expected) in typeToDestination {
            manager.pendingDestination = nil
            manager.handleNotificationTap(userInfo: ["type": type])
            XCTAssertEqual(
                manager.pendingDestination,
                expected,
                "Type '\(type)' should produce \(expected)"
            )
        }
    }

    /// Message type requires conversationId
    func testNewMessage_producesMessages() {
        manager.handleNotificationTap(userInfo: [
            "type": "new_message",
            "conversationId": sampleConversationId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .messages(conversationId: sampleConversationId))
    }

    /// Reply with parentPostId should navigate to parent
    func testHangerTalkReply_producesHangerTalkPostWithParent() {
        let parentId = UUID()
        manager.handleNotificationTap(userInfo: [
            "type": "hanger_talk_reply",
            "postId": samplePostId.uuidString,
            "parentPostId": parentId.uuidString
        ])
        XCTAssertEqual(manager.pendingDestination, .hangerTalkPost(postId: parentId))
    }
}
