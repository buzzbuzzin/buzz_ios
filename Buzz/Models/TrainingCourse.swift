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
    var requiresUasGroundSchool: Bool // Whether this course requires passing UAS Pilot Ground School Test
    var requiresFlightReviewPassed: Bool // Whether this course requires passing Flight Review test
    var requiresRocAPassed: Bool // Whether this course requires passing ROC-A test
    
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
        case mandatory = "Mandatory"
        case extensions = "Extension"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        case specialized = "Specialized"
        
        var icon: String {
            switch self {
            case .mandatory: return "star.fill"
            case .extensions: return "square.grid.2x2.fill"
            case .intermediate: return "chart.bar.fill"
            case .advanced: return "trophy.fill"
            case .specialized: return "sparkles"
            }
        }
    }
    
    enum CourseProvider: String {
        case buzz = "Buzz"
        case redCross = "Red Cross"
        case usfa = "USFA"
        case fema = "FEMA"
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
            case .fema:
                return .green
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
            case .fema:
                return "shield.checkered"
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

