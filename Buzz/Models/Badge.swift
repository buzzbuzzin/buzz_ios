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
    let courseId: UUID
    let courseTitle: String
    let courseCategory: String
    let earnedAt: Date
    let provider: CourseProvider
    let expiresAt: Date? // Expiration date for recurrent training badges
    let isRecurrent: Bool // Whether this badge requires recurrent training
    
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
        case amazon = "Amazon"
        case tmobile = "T-Mobile"
        case other = "Other"
        
        var color: Color {
            switch self {
            case .buzz:
                return .blue
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
            case .amazon:
                return "a.circle.fill"
            case .tmobile:
                return "t.circle.fill"
            case .other:
                return "building.2.fill"
            }
        }
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
    }
}

