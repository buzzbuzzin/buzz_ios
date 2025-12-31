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
    
    var displayName: String {
        switch self {
        case .cpr:
            return "CPR Training"
        case .firefighting:
            return "Basic Firefighting Training"
        }
    }
    
    var icon: String {
        switch self {
        case .cpr:
            return "heart.fill"
        case .firefighting:
            return "flame.fill"
        }
    }
    
    var description: String {
        switch self {
        case .cpr:
            return "Learn life-saving CPR techniques to assist in emergency situations"
        case .firefighting:
            return "Basic firefighting safety and response procedures"
        }
    }
    
    var color: String {
        switch self {
        case .cpr:
            return "red"
        case .firefighting:
            return "orange"
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
    let verified: Bool
    let verifiedAt: Date?
    let verifiedBy: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case trainingType = "training_type"
        case certificateUrl = "certificate_url"
        case uploadedAt = "uploaded_at"
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
    case badgeAward = 2
    
    var title: String {
        switch self {
        case .cprTraining:
            return "CPR Training"
        case .firefightingTraining:
            return "Firefighting Training"
        case .badgeAward:
            return "Beacon Badge"
        }
    }
    
    var description: String {
        switch self {
        case .cprTraining:
            return "Upload your CPR certification"
        case .firefightingTraining:
            return "Upload your firefighting certification"
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
        case .badgeAward:
            return nil
        }
    }
}

