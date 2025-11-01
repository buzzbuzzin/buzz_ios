//
//  Booking.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import Foundation
import CoreLocation

enum BookingStatus: String, Codable {
    case available
    case accepted
    case completed
    case cancelled
}

struct Booking: Codable, Identifiable {
    let id: UUID
    let customerId: UUID
    var pilotId: UUID?
    let locationLat: Double
    let locationLng: Double
    let locationName: String
    let description: String
    let paymentAmount: Decimal
    var status: BookingStatus
    let createdAt: Date
    var estimatedFlightHours: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case customerId = "customer_id"
        case pilotId = "pilot_id"
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case locationName = "location_name"
        case description
        case paymentAmount = "payment_amount"
        case status
        case createdAt = "created_at"
        case estimatedFlightHours = "estimated_flight_hours"
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: locationLat, longitude: locationLng)
    }
}

