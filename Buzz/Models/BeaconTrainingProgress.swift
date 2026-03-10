//
//  BeaconTrainingProgress.swift
//  Buzz
//
//  Created by Xinyu Fang on 12/31/24.
//

import Foundation

// MARK: - Training Type

enum BeaconTrainingType: String, Codable, CaseIterable {
    case cpr = "cpr"
    case firefighting = "firefighting"
    case cert = "cert"
    
    var displayName: String {
        switch self {
        case .cpr:
            return "First Aid/CPR Training"
        case .firefighting:
            return "Basic Firefighting Training"
        case .cert:
            return "Disaster Response Training"
        }
    }
    
    var icon: String {
        switch self {
        case .cpr:
            return "heart.fill"
        case .firefighting:
            return "flame.fill"
        case .cert:
            return "shield.checkered"
        }
    }
    
    var description: String {
        switch self {
        case .cpr:
            return "Learn life-saving first aid and CPR techniques to assist in emergency situations"
        case .firefighting:
            return "Basic firefighting safety and response procedures"
        case .cert:
            return "Disaster response and community emergency preparedness training"
        }
    }
    
    var color: String {
        switch self {
        case .cpr:
            return "red"
        case .firefighting:
            return "orange"
        case .cert:
            return "green"
        }
    }
}

// MARK: - Training Progress Model

struct BeaconTrainingProgress: Codable, Identifiable {
    let id: UUID
    let pilotId: UUID
    let trainingType: BeaconTrainingType
    let certificateUrl: String
    let uploadedAt: Date
    let expiresAt: Date?
    let verified: Bool
    let verifiedAt: Date?
    let verifiedBy: UUID?

    var needsExpiration: Bool {
        expiresAt == nil
    }

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }

    var isCurrent: Bool {
        guard let expiresAt else { return false }
        return expiresAt >= Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case trainingType = "training_type"
        case certificateUrl = "certificate_url"
        case uploadedAt = "uploaded_at"
        case expiresAt = "expires_at"
        case verified
        case verifiedAt = "verified_at"
        case verifiedBy = "verified_by"
    }
}

// MARK: - Beacon Volunteer Model

struct BeaconVolunteer: Codable, Identifiable {
    let id: UUID
    let pilotId: UUID
    let enrolledAt: Date
    var isAvailable: Bool
    var lastLocationLat: Double?
    var lastLocationLng: Double?
    var lastLocationUpdate: Date?
    var notificationRadiusMiles: Int
    var totalMissionsCompleted: Int
    var totalHoursVolunteered: Double
    var peopleHelped: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case enrolledAt = "enrolled_at"
        case isAvailable = "is_available"
        case lastLocationLat = "last_location_lat"
        case lastLocationLng = "last_location_lng"
        case lastLocationUpdate = "last_location_update"
        case notificationRadiusMiles = "notification_radius_miles"
        case totalMissionsCompleted = "total_missions_completed"
        case totalHoursVolunteered = "total_hours_volunteered"
        case peopleHelped = "people_helped"
    }
}

// MARK: - Onboarding Step

enum BeaconOnboardingStep: Int, CaseIterable {
    case cprTraining = 0
    case firefightingTraining = 1
    case certTraining = 2
    case badgeAward = 3
    
    var title: String {
        switch self {
        case .cprTraining:
            return "First Aid/CPR"
        case .firefightingTraining:
            return "Firefighting"
        case .certTraining:
            return "Disaster Response"
        case .badgeAward:
            return "Beacon Badge"
        }
    }
    
    var description: String {
        switch self {
        case .cprTraining:
            return "Upload your First Aid/CPR certification"
        case .firefightingTraining:
            return "Upload your firefighting certification"
        case .certTraining:
            return "Upload your disaster response certification"
        case .badgeAward:
            return "Congratulations! You're now a Beacon volunteer"
        }
    }
    
    var icon: String {
        switch self {
        case .cprTraining:
            return "heart.fill"
        case .firefightingTraining:
            return "flame.fill"
        case .certTraining:
            return "shield.checkered"
        case .badgeAward:
            return "checkmark.seal.fill"
        }
    }
    
    var trainingType: BeaconTrainingType? {
        switch self {
        case .cprTraining:
            return .cpr
        case .firefightingTraining:
            return .firefighting
        case .certTraining:
            return .cert
        case .badgeAward:
            return nil
        }
    }
}

// MARK: - Badge Type to Training Type Mapping

extension Badge.BadgeType {
    /// Maps badge types to their corresponding beacon training types
    /// Used for certificate-based badges that can be earned independently
    var beaconTrainingType: BeaconTrainingType? {
        switch self {
        case .firstAid:
            return .cpr
        case .basicFirefighter:
            return .firefighting
        case .cert:
            return .cert
        default:
            return nil
        }
    }
    
    /// Whether this badge type requires a certificate upload
    var requiresCertificateUpload: Bool {
        return beaconTrainingType != nil
    }
}
