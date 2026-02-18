//
//  AppVersionTracking.swift
//  Buzz
//
//  Created for app version tracking analytics
//

import Foundation

struct AppVersionTracking: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let platform: String
    let appVersion: String
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case platform
        case appVersion = "app_version"
        case lastSeenAt = "last_seen_at"
    }
}

struct AppVersionTrackingUpsert: Encodable {
    let userId: UUID
    let platform: String
    let appVersion: String
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case platform
        case appVersion = "app_version"
        case lastSeenAt = "last_seen_at"
    }
}
