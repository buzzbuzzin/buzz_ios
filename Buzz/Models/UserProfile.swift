//
//  UserProfile.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import Foundation

// Typealias to avoid circular imports with TrainingCourse
typealias UserCourseRegion = String

enum UserType: String, Codable {
    case pilot
    case customer
}

enum CommunicationPreference: String, Codable {
    case email = "email"
    case text = "text"
    case both = "both"
    
    var displayName: String {
        switch self {
        case .email: return "Email"
        case .text: return "Text Message"
        case .both: return "Both"
        }
    }
}

enum Gender: String, Codable, CaseIterable {
    case male = "male"
    case female = "female"
    case other = "other"
    case preferNotToSay = "prefer_not_to_say"
    
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

enum CustomerRole: String, Codable, CaseIterable {
    case individual = "individual"
    case company = "company"
    case government = "government"
    case nonProfit = "non_profit"
    
    var displayName: String {
        switch self {
        case .individual: return "Individual"
        case .company: return "Company"
        case .government: return "Government"
        case .nonProfit: return "Non-profit"
        }
    }
    
    var icon: String {
        switch self {
        case .individual: return "person.fill"
        case .company: return "building.2.fill"
        case .government: return "building.columns.fill"
        case .nonProfit: return "heart.fill"
        }
    }
}

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let userType: UserType
    let firstName: String?
    let lastName: String?
    let callSign: String?
    let email: String?
    let phone: String?
    let gender: Gender?
    let profilePictureUrl: String?
    let communicationPreference: CommunicationPreference?
    let role: CustomerRole? // Customer role (only for customers)
    let specialization: BookingSpecialization? // Customer specialization preference (only for customers)
    let createdAt: Date
    let balance: Decimal? // Pilot balance (earnings + tips)
    let stripeAccountId: String? // Stripe Connect account ID for pilots
    let isExMilitary: Bool? // Ex-military status (awards Ex-Military badge)
    let isGovernmentEmployee: Bool? // Government employee status (awards Government Employee badge)
    let hasFaaCertification: Bool? // FAA certification status (awards FAA badge)
    let isBuzzAffiliate: Bool? // Buzz affiliate status (awards Buzz badge)
    let veteranServiceName: String? // Full name on service/veteran card
    let veteranServiceCountry: String? // Service country
    let veteranMilitaryBranch: String? // Military branch (Army, Navy, Air Force, etc.)
    let veteranServiceNumber: String? // Service number
    let lastLocationLat: Double? // Last known latitude
    let lastLocationLng: Double? // Last known longitude
    let lastLocationUpdate: Date? // Last location update timestamp
    let referralCredits: Decimal? // Available referral credits (for customers)
    let referredBy: UUID? // UUID of user who referred this user
    let isBeaconVolunteer: Bool? // Beacon emergency response volunteer status
    let selectedRegion: UserCourseRegion? // User's selected region for course filtering
    let isVerified: Bool? // Manual identity verification override (fallback when no government_ids record)
    
    enum CodingKeys: String, CodingKey {
        case id
        case userType = "user_type"
        case firstName = "first_name"
        case lastName = "last_name"
        case callSign = "call_sign"
        case email
        case phone
        case gender
        case profilePictureUrl = "profile_picture_url"
        case communicationPreference = "communication_preference"
        case role
        case specialization
        case createdAt = "created_at"
        case balance
        case stripeAccountId = "stripe_account_id"
        case isExMilitary = "is_ex_military"
        case isGovernmentEmployee = "is_government_employee"
        case hasFaaCertification = "has_faa_certification"
        case isBuzzAffiliate = "is_buzz_affiliate"
        case veteranServiceName = "veteran_service_name"
        case veteranServiceCountry = "veteran_service_country"
        case veteranMilitaryBranch = "veteran_military_branch"
        case veteranServiceNumber = "veteran_service_number"
        case lastLocationLat = "last_location_lat"
        case lastLocationLng = "last_location_lng"
        case lastLocationUpdate = "last_location_update"
        case referralCredits = "referral_credits"
        case referredBy = "referred_by"
        case isBeaconVolunteer = "is_beacon_volunteer"
        case selectedRegion = "selected_region"
        case isVerified = "is_verified"
    }
    
    var fullName: String {
        let components = [firstName, lastName].compactMap { $0 }
        return components.isEmpty ? "User" : components.joined(separator: " ")
    }

    private var normalizedCallSign: String? {
        guard let callSign else { return nil }
        let trimmed = callSign.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var publicPilotName: String {
        normalizedCallSign ?? "Pilot"
    }

    var publicDisplayName: String {
        userType == .pilot ? publicPilotName : fullName
    }

    func visibleDisplayName(to viewerUserId: UUID?) -> String {
        if userType == .pilot && viewerUserId != id {
            return publicPilotName
        }
        return fullName
    }
}
