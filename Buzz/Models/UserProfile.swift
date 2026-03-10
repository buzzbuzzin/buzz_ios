//
//  UserProfile.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import Foundation

// Typealias to avoid circular imports with TrainingCourse
typealias UserCourseRegion = String

enum MeasurementSystem: String, Codable, CaseIterable {
    case imperial
    case metric

    var displayName: String {
        switch self {
        case .imperial: return "Imperial"
        case .metric: return "Metric"
        }
    }

    var temperatureUnit: String {
        switch self {
        case .imperial: return "°F"
        case .metric: return "°C"
        }
    }

    var windSpeedUnit: String {
        switch self {
        case .imperial: return "mph"
        case .metric: return "km/h"
        }
    }

    var visibilityUnit: String {
        switch self {
        case .imperial: return "mi"
        case .metric: return "km"
        }
    }

    static func regionalDefault(for region: UserCourseRegion?) -> MeasurementSystem {
        switch region {
        case "Canada", "UK", "Australia", "New Zealand", "South Africa":
            return .metric
        default:
            return .imperial
        }
    }
}

enum MeasurementFormatter {
    static func fahrenheitValue(fromTemperature value: Double, system: MeasurementSystem) -> Double {
        switch system {
        case .imperial:
            return value
        case .metric:
            return (value * 9.0 / 5.0) + 32.0
        }
    }

    static func temperatureValue(fromFahrenheit fahrenheit: Double, system: MeasurementSystem) -> Double {
        switch system {
        case .imperial:
            return fahrenheit
        case .metric:
            return (fahrenheit - 32.0) * 5.0 / 9.0
        }
    }

    static func temperatureDeltaValue(fromFahrenheit delta: Double, system: MeasurementSystem) -> Double {
        switch system {
        case .imperial:
            return delta
        case .metric:
            return delta * 5.0 / 9.0
        }
    }

    static func windSpeedValue(fromMilesPerHour milesPerHour: Double, system: MeasurementSystem) -> Double {
        switch system {
        case .imperial:
            return milesPerHour
        case .metric:
            return milesPerHour * 1.609344
        }
    }

    static func milesPerHourValue(fromWindSpeed value: Double, system: MeasurementSystem) -> Double {
        switch system {
        case .imperial:
            return value
        case .metric:
            return value / 1.609344
        }
    }

    static func distanceValue(fromMiles miles: Double, system: MeasurementSystem) -> Double {
        switch system {
        case .imperial:
            return miles
        case .metric:
            return miles * 1.609344
        }
    }

    static func milesValue(fromDistance value: Double, system: MeasurementSystem) -> Double {
        switch system {
        case .imperial:
            return value
        case .metric:
            return value / 1.609344
        }
    }

    static func temperature(_ fahrenheit: Double, system: MeasurementSystem, decimals: Int = 0, includeUnit: Bool = true) -> String {
        format(
            temperatureValue(fromFahrenheit: fahrenheit, system: system),
            decimals: decimals,
            unit: includeUnit ? system.temperatureUnit : nil
        )
    }

    static func windSpeed(_ milesPerHour: Double, system: MeasurementSystem, decimals: Int = 0, includeUnit: Bool = true) -> String {
        format(
            windSpeedValue(fromMilesPerHour: milesPerHour, system: system),
            decimals: decimals,
            unit: includeUnit ? system.windSpeedUnit : nil
        )
    }

    static func distance(_ miles: Double, system: MeasurementSystem, decimals: Int = 1, includeUnit: Bool = true) -> String {
        format(
            distanceValue(fromMiles: miles, system: system),
            decimals: decimals,
            unit: includeUnit ? system.visibilityUnit : nil
        )
    }

    private static func format(_ value: Double, decimals: Int, unit: String?) -> String {
        let number = String(format: "%.\(decimals)f", value)
        guard let unit else { return number }
        return "\(number) \(unit)"
    }
}

enum UserType: String, Codable {
    case pilot
    case customer
    case admin
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
    var preferredMeasurementSystem: MeasurementSystem? = nil // Nil means "use the region default"
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
        case preferredMeasurementSystem = "preferred_measurement_system"
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

    var effectiveMeasurementSystem: MeasurementSystem {
        preferredMeasurementSystem ?? MeasurementSystem.regionalDefault(for: selectedRegion)
    }

    func visibleDisplayName(to viewerUserId: UUID?) -> String {
        if userType == .pilot && viewerUserId != id {
            return publicPilotName
        }
        return fullName
    }
}
