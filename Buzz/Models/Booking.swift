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
    
    var displayName: String {
        switch self {
        case .available:
            return "standby"
        case .accepted:
            return "Active"
        case .completed:
            return "completed"
        case .cancelled:
            return "cancelled"
        }
    }
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
    case mappingSurveying = "mapping_surveying"
    
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
        case .mappingSurveying: return "Mapping & Surveying"
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
        case .mappingSurveying: return "map.fill"
        }
    }
    
    var backgroundImage: String {
        switch self {
        case .automotive: return "Specialization_automotive_bg"
        case .motionPicture: return "Specialization_motion_picture_bg"
        case .realEstate: return "Specialization_real_estate_bg"
        case .agriculture: return "Specialization_agriculture_bg"
        case .inspections: return "Specialization_inspections_bg"
        case .searchRescue: return "Specialization_search_rescue_bg"
        case .logistics: return "Specialization_logistics_bg"
        case .droneArt: return "Specialization_drone_art_bg"
        case .surveillanceSecurity: return "Specialization_surveillance_security_bg"
        case .mappingSurveying: return "Specialization_mapping_surveying_bg"
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
    let endDate: Date?
    let specialization: BookingSpecialization?
    let description: String?
    let paymentAmount: Decimal
    var tipAmount: Decimal?
    var status: BookingStatus
    let createdAt: Date
    var estimatedFlightHours: Double?
    var pilotRated: Bool?
    var customerRated: Bool?
    var requiredMinimumRank: Int? // 0-4: Ensign, Sub Lieutenant, Lieutenant, Commander, Captain
    var paymentIntentId: String?
    var transferId: String?
    var chargeId: String?
    var customerCompleted: Bool? // Customer has marked booking as finished
    var pilotCompleted: Bool? // Pilot has marked booking as finished
    var completedAt: Date? // Timestamp when booking was officially completed
    
    enum CodingKeys: String, CodingKey {
        case id
        case customerId = "customer_id"
        case pilotId = "pilot_id"
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case locationName = "location_name"
        case scheduledDate = "scheduled_date"
        case endDate = "end_date"
        case specialization
        case description
        case paymentAmount = "payment_amount"
        case tipAmount = "tip_amount"
        case status
        case createdAt = "created_at"
        case estimatedFlightHours = "estimated_flight_hours"
        case pilotRated = "pilot_rated"
        case customerRated = "customer_rated"
        case requiredMinimumRank = "required_minimum_rank"
        case paymentIntentId = "payment_intent_id"
        case transferId = "transfer_id"
        case chargeId = "charge_id"
        case customerCompleted = "customer_completed"
        case pilotCompleted = "pilot_completed"
        case completedAt = "completed_at"
    }
    
    var rankName: String {
        guard let rank = requiredMinimumRank else { return "Any Rank" }
        return PilotStats(pilotId: UUID(), totalFlightHours: 0, completedBookings: 0, tier: rank).tierName
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: locationLat, longitude: locationLng)
    }
    
    /// Returns true if this is an automotive booking that uses the crew system
    var isAutomotiveCrewBooking: Bool {
        specialization == .automotive
    }
}

// MARK: - Booking Crew Models (for automotive bookings)

/// Role of a pilot in an automotive booking crew
enum CrewRole: String, Codable {
    case lead
    case crew
    
    var displayName: String {
        switch self {
        case .lead: return "Lead Pilot"
        case .crew: return "Crew Member"
        }
    }
}

/// Represents a crew member in an automotive booking
struct BookingCrewMember: Codable, Identifiable {
    let id: UUID
    let bookingId: UUID
    let pilotId: UUID
    let role: CrewRole
    let rankAtAcceptance: Int
    let payoutAmount: Decimal
    let joinedAtString: String  // ISO 8601 string from edge function
    var transferId: String?
    
    // Optional profile info (populated when fetched with profile data)
    var pilotName: String?
    var callSign: String?
    var profilePictureUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case bookingId = "booking_id"
        case pilotId = "pilot_id"
        case role
        case rankAtAcceptance = "rank_at_acceptance"
        case payoutAmount = "payout_amount"
        case joinedAtString = "joined_at"
        case transferId = "transfer_id"
        case pilotName = "pilot_name"
        case callSign = "call_sign"
        case profilePictureUrl = "profile_picture_url"
    }
    
    /// Parsed Date from joinedAtString
    var joinedAt: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: joinedAtString) {
            return date
        }
        // Fallback without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: joinedAtString) ?? Date()
    }
    
    /// Returns the rank name for this crew member
    var rankName: String {
        switch rankAtAcceptance {
        case 1: return "Sublieutenant"
        case 2: return "Lieutenant"
        case 3: return "Commander"
        case 4: return "Captain"
        default: return "Unknown"
        }
    }
    
    /// Returns true if this crew member's earnings have been posted to their balance
    /// (transfer completed, available to withdraw)
    var isPosted: Bool {
        transferId != nil
    }
}

/// Response from get-booking-crew edge function
struct BookingCrewResponse: Codable {
    let isAutomotive: Bool
    let crewCount: Int
    let maxCrew: Int
    let status: String?
    let hasQualifiedLead: Bool?
    let isCrewFull: Bool?
    let isReady: Bool?
    let crew: [BookingCrewMember]?
    let leadPilot: BookingCrewLeadInfo?
    let totalPayout: Decimal?
    
    enum CodingKeys: String, CodingKey {
        case isAutomotive = "is_automotive"
        case crewCount = "crew_count"
        case maxCrew = "max_crew"
        case status
        case hasQualifiedLead = "has_qualified_lead"
        case isCrewFull = "is_crew_full"
        case isReady = "is_ready"
        case crew
        case leadPilot = "lead_pilot"
        case totalPayout = "total_payout"
    }
}

/// Lead pilot info (shown to customers)
struct BookingCrewLeadInfo: Codable {
    let pilotId: UUID?
    let pilotName: String?
    let callSign: String?
    let rankName: String?
    let profilePictureUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case pilotId = "pilot_id"
        case pilotName = "pilot_name"
        case callSign = "call_sign"
        case rankName = "rank_name"
        case profilePictureUrl = "profile_picture_url"
    }
}

/// Response from join-automotive-booking edge function
struct JoinCrewResponse: Codable {
    let success: Bool
    let message: String?
    let crewMember: JoinedCrewMemberInfo?
    let crewStatus: CrewStatusInfo?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case crewMember = "crew_member"
        case crewStatus = "crew_status"
        case error
    }
}

struct JoinedCrewMemberInfo: Codable {
    let id: UUID
    let role: String
    let rank: String
    let payoutAmount: Decimal
    
    enum CodingKeys: String, CodingKey {
        case id
        case role
        case rank
        case payoutAmount = "payout_amount"
    }
}

struct CrewStatusInfo: Codable {
    let currentCount: Int
    let maxCount: Int
    let hasQualifiedLead: Bool
    let bookingAccepted: Bool
    
    enum CodingKeys: String, CodingKey {
        case currentCount = "current_count"
        case maxCount = "max_count"
        case hasQualifiedLead = "has_qualified_lead"
        case bookingAccepted = "booking_accepted"
    }
}

