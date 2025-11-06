//
//  NotificationPreferences.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation

struct NotificationPreferences: Codable {
    var bookingReminders: NotificationDeliveryOptions
    var weatherUpdates: NotificationDeliveryOptions
    var receivedReviews: NotificationDeliveryOptions
    var rankImprovements: NotificationDeliveryOptions
    var bookingUpdates: NotificationDeliveryOptions
    var messages: NotificationDeliveryOptions
    
    init() {
        // Default: system notifications ON for all types
        self.bookingReminders = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.weatherUpdates = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.receivedReviews = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.rankImprovements = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.bookingUpdates = NotificationDeliveryOptions(system: true, email: false, text: false)
        self.messages = NotificationDeliveryOptions(system: true, email: false, text: false)
    }
    
    enum CodingKeys: String, CodingKey {
        case bookingReminders = "booking_reminders"
        case weatherUpdates = "weather_updates"
        case receivedReviews = "received_reviews"
        case rankImprovements = "rank_improvements"
        case bookingUpdates = "booking_updates"
        case messages
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

