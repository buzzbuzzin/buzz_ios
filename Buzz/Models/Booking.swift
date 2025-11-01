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

enum BookingSpecialization: String, Codable, CaseIterable {
    case automotive = "automotive"
    case motionPicture = "motion_picture"
    case realEstate = "real_estate"
    case agriculture = "agriculture"
    case inspections = "inspections"
    case searchRescue = "search_rescue"
    case logistics = "logistics"
    case droneArt = "drone_art"
    case surveillanceSecurity = "surveillance_security"
    
    var displayName: String {
        switch self {
        case .automotive: return "Automotive"
        case .motionPicture: return "Motion Picture"
        case .realEstate: return "Real Estate"
        case .agriculture: return "Agriculture"
        case .inspections: return "Inspections"
        case .searchRescue: return "Search & Rescue"
        case .logistics: return "Logistics"
        case .droneArt: return "Drone Art"
        case .surveillanceSecurity: return "Surveillance & Security"
        }
    }
    
    var icon: String {
        switch self {
        case .automotive: return "car.fill"
        case .motionPicture: return "film.fill"
        case .realEstate: return "house.fill"
        case .agriculture: return "leaf.fill"
        case .inspections: return "magnifyingglass"
        case .searchRescue: return "cross.fill"
        case .logistics: return "shippingbox.fill"
        case .droneArt: return "paintpalette.fill"
        case .surveillanceSecurity: return "eye.fill"
        }
    }
}

struct Booking: Codable, Identifiable {
    let id: UUID
    let customerId: UUID
    var pilotId: UUID?
    let locationLat: Double
    let locationLng: Double
    let locationName: String
    let scheduledDate: Date?
    let specialization: BookingSpecialization?
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
        case scheduledDate = "scheduled_date"
        case specialization
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

