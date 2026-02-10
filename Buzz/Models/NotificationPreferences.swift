//
//  NotificationPreferences.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation

struct NotificationPreferences: Codable {
    // General
    var bookingReminders: NotificationDeliveryOptions
    var bookingCancellations: NotificationDeliveryOptions
    var weatherUpdates: NotificationDeliveryOptions
    var receivedReviews: NotificationDeliveryOptions
    var bookingUpdates: NotificationDeliveryOptions
    var messages: NotificationDeliveryOptions
    var tipReceived: NotificationDeliveryOptions
    var payoutConfirmation: NotificationDeliveryOptions

    // Beacon
    var beaconAccepted: NotificationDeliveryOptions
    var beaconResolved: NotificationDeliveryOptions

    // Hanger Talk
    var hangerTalkLikes: NotificationDeliveryOptions
    var hangerTalkReplies: NotificationDeliveryOptions
    var hangerTalkMentions: NotificationDeliveryOptions
    var hangerTalkFollows: NotificationDeliveryOptions
    var hangerTalkNewPosts: NotificationDeliveryOptions

    init() {
        // Default: system notifications ON for all types
        self.bookingReminders = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.bookingCancellations = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.weatherUpdates = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.receivedReviews = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.bookingUpdates = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.messages = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.tipReceived = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.payoutConfirmation = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.beaconAccepted = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.beaconResolved = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.hangerTalkLikes = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.hangerTalkReplies = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.hangerTalkMentions = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.hangerTalkFollows = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.hangerTalkNewPosts = NotificationDeliveryOptions(system: true, email: false, text: false)
    }

    enum CodingKeys: String, CodingKey {
        case bookingReminders = "booking_reminders"
        case bookingCancellations = "booking_cancellations"
        case weatherUpdates = "weather_updates"
        case receivedReviews = "received_reviews"
        case bookingUpdates = "booking_updates"
        case messages
        case tipReceived = "tip_received"
        case payoutConfirmation = "payout_confirmation"
        case beaconAccepted = "beacon_accepted"
        case beaconResolved = "beacon_resolved"
        case hangerTalkLikes = "hanger_talk_likes"
        case hangerTalkReplies = "hanger_talk_replies"
        case hangerTalkMentions = "hanger_talk_mentions"
        case hangerTalkFollows = "hanger_talk_follows"
        case hangerTalkNewPosts = "hanger_talk_new_posts"
    }

    /// Decode with forward-compatible defaults for new fields.
    /// This ensures existing UserDefaults data (missing new keys) still loads cleanly.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = NotificationDeliveryOptions(system: true, email: false, text: false)

        bookingReminders = (try? container.decode(NotificationDeliveryOptions.self, forKey: .bookingReminders)) ?? defaults
        bookingCancellations = (try? container.decode(NotificationDeliveryOptions.self, forKey: .bookingCancellations)) ?? defaults
        weatherUpdates = (try? container.decode(NotificationDeliveryOptions.self, forKey: .weatherUpdates)) ?? defaults
        receivedReviews = (try? container.decode(NotificationDeliveryOptions.self, forKey: .receivedReviews)) ?? defaults
        bookingUpdates = (try? container.decode(NotificationDeliveryOptions.self, forKey: .bookingUpdates)) ?? defaults
        messages = (try? container.decode(NotificationDeliveryOptions.self, forKey: .messages)) ?? defaults
        tipReceived = (try? container.decode(NotificationDeliveryOptions.self, forKey: .tipReceived)) ?? defaults
        payoutConfirmation = (try? container.decode(NotificationDeliveryOptions.self, forKey: .payoutConfirmation)) ?? defaults
        beaconAccepted = (try? container.decode(NotificationDeliveryOptions.self, forKey: .beaconAccepted)) ?? defaults
        beaconResolved = (try? container.decode(NotificationDeliveryOptions.self, forKey: .beaconResolved)) ?? defaults
        hangerTalkLikes = (try? container.decode(NotificationDeliveryOptions.self, forKey: .hangerTalkLikes)) ?? defaults
        hangerTalkReplies = (try? container.decode(NotificationDeliveryOptions.self, forKey: .hangerTalkReplies)) ?? defaults
        hangerTalkMentions = (try? container.decode(NotificationDeliveryOptions.self, forKey: .hangerTalkMentions)) ?? defaults
        hangerTalkFollows = (try? container.decode(NotificationDeliveryOptions.self, forKey: .hangerTalkFollows)) ?? defaults
        hangerTalkNewPosts = (try? container.decode(NotificationDeliveryOptions.self, forKey: .hangerTalkNewPosts)) ?? defaults
    }
}

struct NotificationDeliveryOptions: Codable {
    var system: Bool
    var email: Bool
    var text: Bool

    init(system: Bool = false, email: Bool = false, text: Bool = false) {
        self.system = system
        self.email = email
        self.text = text
    }

    var isEnabled: Bool {
        return system || email || text
    }
}
