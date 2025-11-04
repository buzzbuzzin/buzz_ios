//
//  Transponder.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import CoreLocation

struct Transponder: Codable, Identifiable, Equatable {
    let id: UUID
    let pilotId: UUID
    let deviceName: String
    let remoteId: String
    let isLocationTrackingEnabled: Bool
    let lastLocationLat: Double?
    let lastLocationLng: Double?
    let lastLocationUpdate: Date?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case deviceName = "device_name"
        case remoteId = "remote_id"
        case isLocationTrackingEnabled = "is_location_tracking_enabled"
        case lastLocationLat = "last_location_lat"
        case lastLocationLng = "last_location_lng"
        case lastLocationUpdate = "last_location_update"
        case createdAt = "created_at"
    }
    
    var lastLocation: CLLocationCoordinate2D? {
        guard let lat = lastLocationLat, let lng = lastLocationLng else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    
    static func == (lhs: Transponder, rhs: Transponder) -> Bool {
        return lhs.id == rhs.id &&
               lhs.pilotId == rhs.pilotId &&
               lhs.deviceName == rhs.deviceName &&
               lhs.remoteId == rhs.remoteId &&
               lhs.isLocationTrackingEnabled == rhs.isLocationTrackingEnabled &&
               lhs.lastLocationLat == rhs.lastLocationLat &&
               lhs.lastLocationLng == rhs.lastLocationLng &&
               lhs.lastLocationUpdate == rhs.lastLocationUpdate &&
               lhs.createdAt == rhs.createdAt
    }
}

