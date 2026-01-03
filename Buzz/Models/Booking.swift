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

/// Search & Rescue assignment type
enum SARAssignmentType: String, Codable, CaseIterable {
    case groundSearch = "ground_search"
    case airSearch = "air_search"
    case waterRescue = "water_rescue"
    case medicalEmergency = "medical_emergency"
    case fireEmergency = "fire_emergency"
    case disasterResponse = "disaster_response"
    case missingPerson = "missing_person"
    
    var displayName: String {
        switch self {
        case .groundSearch: return "Ground Search"
        case .airSearch: return "Air Search"
        case .waterRescue: return "Water Rescue"
        case .medicalEmergency: return "Medical Emergency"
        case .fireEmergency: return "Fire Emergency"
        case .disasterResponse: return "Disaster Response"
        case .missingPerson: return "Missing Person"
        }
    }
    
    var icon: String {
        switch self {
        case .groundSearch: return "figure.walk"
        case .airSearch: return "airplane"
        case .waterRescue: return "drop.fill"
        case .medicalEmergency: return "cross.case.fill"
        case .fireEmergency: return "flame.fill"
        case .disasterResponse: return "exclamationmark.triangle.fill"
        case .missingPerson: return "person.fill.questionmark"
        }
    }
}

/// Government agency for S&R missions
enum GovernmentAgency: String, Codable, CaseIterable {
    case policeDepartment = "police_department"
    case fireDepartment = "fire_department"
    case sheriffOffice = "sheriff_office"
    case stateEmergencyManagement = "state_emergency_management"
    
    var displayName: String {
        switch self {
        case .policeDepartment: return "Police Department"
        case .fireDepartment: return "Fire Department"
        case .sheriffOffice: return "Sheriff's Office"
        case .stateEmergencyManagement: return "State Emergency Management"
        }
    }
    
    var icon: String {
        switch self {
        case .policeDepartment: return "shield.fill"
        case .fireDepartment: return "flame.fill"
        case .sheriffOffice: return "star.circle.fill"
        case .stateEmergencyManagement: return "building.columns.fill"
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
    
    // Search & Rescue specific fields
    var isVoluntary: Bool? // True if this is a voluntary mission with no payment
    var hourlyRate: Decimal? // Hourly rate per pilot for S&R missions ($25)
    var finalHoursWorked: Double? // Actual hours worked, entered by client after completion
    var assignmentType: SARAssignmentType? // Type of S&R assignment
    var governmentAgency: GovernmentAgency? // Government agency (for government clients)
    var usesBeaconProgram: Bool? // True if using Beacon volunteer pilots (government clients only)
    var numberOfPilots: Int? // Number of pilots requested for S&R mission
    
    // Internal testing field
    var isInternalTest: Bool? // True if this is an internal test booking (hidden from non-Buzz pilots)
    
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
        case isVoluntary = "is_voluntary"
        case hourlyRate = "hourly_rate"
        case finalHoursWorked = "final_hours_worked"
        case assignmentType = "assignment_type"
        case governmentAgency = "government_agency"
        case usesBeaconProgram = "uses_beacon_program"
        case numberOfPilots = "number_of_pilots"
        case isInternalTest = "is_internal_test"
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
    
    /// Returns true if this is a Search & Rescue booking that uses the crew system
    var isSearchRescueCrewBooking: Bool {
        specialization == .searchRescue
    }
    
    /// Returns true if this booking uses a multi-pilot crew system
    var isCrewBooking: Bool {
        isAutomotiveCrewBooking || isSearchRescueCrewBooking
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
    let isSearchRescue: Bool?
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
        case isSearchRescue = "is_search_rescue"
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
    
    /// Returns true if this is a crew-based booking (automotive or S&R)
    var isCrewBooking: Bool {
        isAutomotive || (isSearchRescue ?? false)
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

