//
//  Badge.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import SwiftUI

struct Badge: Identifiable, Codable {
    let id: UUID
    let courseId: UUID? // Optional for criteria-based badges
    let courseTitle: String? // Optional for criteria-based badges
    let courseCategory: String? // Optional for criteria-based badges
    let earnedAt: Date
    let provider: CourseProvider
    let expiresAt: Date? // Expiration date for recurrent training badges
    let isRecurrent: Bool // Whether this badge requires recurrent training
    let badgeType: BadgeType? // Type of badge: course or criteria-based
    
    var daysUntilExpiration: Int? {
        guard let expiresAt = expiresAt else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day
    }
    
    var isExpiringSoon: Bool {
        guard let daysUntilExpiration = daysUntilExpiration else { return false }
        return daysUntilExpiration <= 7 && daysUntilExpiration > 0
    }
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt < Date()
    }
    
    enum CourseProvider: String, Codable {
        case buzz = "Buzz"
        case redCross = "Red Cross"
        case usfa = "USFA"
        case amazon = "Amazon"
        case tmobile = "T-Mobile"
        case other = "Other"
        
        var color: Color {
            switch self {
            case .buzz:
                return .blue
            case .redCross:
                return .red
            case .usfa:
                return .yellow
            case .amazon:
                return .orange
            case .tmobile:
                return .pink
            case .other:
                return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .buzz:
                return "airplane.circle.fill"
            case .redCross:
                return "cross.circle.fill"
            case .usfa:
                return "flame.circle.fill"
            case .amazon:
                return "a.circle.fill"
            case .tmobile:
                return "t.circle.fill"
            case .other:
                return "building.2.fill"
            }
        }
    }
    
    enum BadgeType: String, Codable {
        case course = "course"
        case exMilitary = "ex_military"
        case buzz = "buzz"
        case governmentEmployee = "government_employee"
        case faa = "faa"
        case flightReviewer = "flight_reviewer"
        case rocaExaminer = "roc_a_examiner"
        case beaconVolunteer = "beacon_volunteer"
        
        var displayName: String {
            switch self {
            case .course: return "Course Badge"
            case .exMilitary: return "Ex-Military"
            case .buzz: return "Buzz"
            case .governmentEmployee: return "Government"
            case .faa: return "FAA"
            case .flightReviewer: return "Flight Reviewer"
            case .rocaExaminer: return "ROC-A Examiner"
            case .beaconVolunteer: return "Beacon Volunteer"
            }
        }
        
        var icon: String {
            switch self {
            case .course: return "book.fill"
            case .exMilitary: return "shield.fill"
            case .buzz: return "airplane.circle.fill" // Not used - we use image asset instead
            case .governmentEmployee: return "building.columns.fill"
            case .faa: return "checkmark.seal.fill"
            case .flightReviewer: return "person.text.rectangle.fill"
            case .rocaExaminer: return "antenna.radiowaves.left.and.right"
            case .beaconVolunteer: return "antenna.radiowaves.left.and.right"
            }
        }
        
        var imageAssetName: String? {
            switch self {
            case .buzz: return "Logo"
            default: return nil
            }
        }
        
        var color: Color {
            switch self {
            case .course: return .blue
            case .exMilitary: return .purple
            case .buzz: return Color(red: 0x28 / 255.0, green: 0x2C / 255.0, blue: 0x35 / 255.0) // Navy blue #282C35
            case .governmentEmployee: return .green
            case .faa: return .red
            case .flightReviewer: return .teal
            case .rocaExaminer: return .indigo
            case .beaconVolunteer: return .orange
            }
        }
    }
    
    // Computed property to get display title
    var displayTitle: String {
        if let badgeType = badgeType, badgeType != .course {
            return badgeType.displayName
        }
        return courseTitle ?? "Unknown Badge"
    }
    
    // Computed property to get display category
    var displayCategory: String {
        if let badgeType = badgeType, badgeType != .course {
            switch badgeType {
            case .exMilitary, .governmentEmployee:
                return "Service Recognition"
            case .buzz:
                return "Partnership"
            case .faa:
                return "Certification"
            case .flightReviewer, .rocaExaminer:
                return "Permits"
            default:
                return "Badge"
            }
        }
        return courseCategory ?? "Course"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case courseId = "course_id"
        case courseTitle = "course_title"
        case courseCategory = "course_category"
        case earnedAt = "earned_at"
        case provider
        case expiresAt = "expires_at"
        case isRecurrent = "is_recurrent"
        case badgeType = "badge_type"
    }
}

// MARK: - Badge Catalog (Badge definition from backend)

struct BadgeCatalog: Identifiable, Codable {
    let id: UUID
    let badgeType: String
    let title: String
    let category: String?
    let courseId: UUID?
    let iconName: String
    let colorName: String
    let provider: String
    let isRecurrent: Bool
    let isActive: Bool
    let displayOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case badgeType = "badge_type"
        case title
        case category
        case courseId = "course_id"
        case iconName = "icon_name"
        case colorName = "color_name"
        case provider
        case isRecurrent = "is_recurrent"
        case isActive = "is_active"
        case displayOrder = "display_order"
    }
    
    var badgeTypeEnum: Badge.BadgeType? {
        Badge.BadgeType(rawValue: badgeType)
    }
    
    var providerColor: Color {
        if let badgeTypeEnum = badgeTypeEnum, badgeTypeEnum != .course {
            return badgeTypeEnum.color
        }
        return Badge.CourseProvider(rawValue: provider)?.color ?? .blue
    }
    
    var providerIcon: String {
        if let badgeTypeEnum = badgeTypeEnum, badgeTypeEnum != .course {
            return badgeTypeEnum.icon
        }
        return Badge.CourseProvider(rawValue: provider)?.icon ?? "airplane.circle.fill"
    }
    
    var imageAssetName: String? {
        if let badgeTypeEnum = badgeTypeEnum, badgeTypeEnum != .course {
            return badgeTypeEnum.imageAssetName
        }
        return nil
    }
}

// MARK: - Available Badge (Badge that can be earned)

struct AvailableBadge: Identifiable {
    let id: UUID
    let courseId: UUID? // Optional for criteria-based badges
    let courseTitle: String
    let courseCategory: String
    let provider: Badge.CourseProvider
    let isRecurrent: Bool
    let badgeType: Badge.BadgeType? // Type of badge: course or criteria-based
    
    var providerColor: Color {
        if let badgeType = badgeType, badgeType != .course {
            return badgeType.color
        }
        return provider.color
    }
    
    var providerIcon: String {
        if let badgeType = badgeType, badgeType != .course {
            return badgeType.icon
        }
        return provider.icon
    }
    
    var imageAssetName: String? {
        if let badgeType = badgeType, badgeType != .course {
            return badgeType.imageAssetName
        }
        return nil
    }
}

