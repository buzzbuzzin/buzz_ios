//
//  TrainingCourse.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import SwiftUI

struct TrainingCourse: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let duration: String
    let level: CourseLevel
    let category: CourseCategory
    let instructor: String
    let instructorPictureUrl: String?
    let rating: Double
    let studentsCount: Int
    var isEnrolled: Bool
    var provider: CourseProvider
    var badgeId: UUID? // Badge earned when course is completed
    var isRecurrent: Bool // Whether this is recurrent training
    var recurrentDueDate: Date? // When recurrent training is due
    
    enum CourseLevel: String {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        
        var color: Color {
            switch self {
            case .beginner: return .green
            case .intermediate: return .orange
            case .advanced: return .red
            }
        }
    }
    
    enum CourseCategory: String {
        case safety = "Safety & Regulations"
        case operations = "Flight Operations"
        case photography = "Aerial Photography"
        case cinematography = "Cinematography"
        case inspection = "Inspections"
        case mapping = "Mapping & Surveying"
        
        var icon: String {
            switch self {
            case .safety: return "shield.fill"
            case .operations: return "airplane.departure"
            case .photography: return "camera.fill"
            case .cinematography: return "video.fill"
            case .inspection: return "magnifyingglass"
            case .mapping: return "map.fill"
            }
        }
    }
    
    enum CourseProvider: String {
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
}

struct RecurrentTrainingNotice: Identifiable {
    let id: UUID
    let courseTitle: String
    let courseCategory: String
    let dueDate: Date
    let provider: TrainingCourse.CourseProvider
    
    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
    }
    
    var isOverdue: Bool {
        dueDate < Date()
    }
    
    var urgencyColor: Color {
        if isOverdue {
            return .red
        } else if daysUntilDue <= 30 {
            return .orange
        } else {
            return .blue
        }
    }
}

