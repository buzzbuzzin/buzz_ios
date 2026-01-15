//
//  ExamTypeConfig.swift
//  Buzz
//
//  Model for exam type configuration fetched from the backend
//

import Foundation
import SwiftUI

/// Configuration for an exam type fetched from the backend
/// This replaces the hardcoded properties in ExamType enum
struct ExamTypeConfig: Codable, Identifiable {
    let examType: String
    let displayName: String
    let shortDescription: String
    let fullDescription: String
    let icon: String
    let durationMinutes: Int
    let allowsOnline: Bool
    let stripeProductId: String
    let prerequisites: [String]
    let createdAt: Date
    let updatedAt: Date
    
    var id: String { examType }
    
    enum CodingKeys: String, CodingKey {
        case examType = "exam_type"
        case displayName = "display_name"
        case shortDescription = "short_description"
        case fullDescription = "full_description"
        case icon
        case durationMinutes = "duration_minutes"
        case allowsOnline = "allows_online"
        case stripeProductId = "stripe_product_id"
        case prerequisites
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Custom decoder to handle date and prerequisites
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        examType = try container.decode(String.self, forKey: .examType)
        displayName = try container.decode(String.self, forKey: .displayName)
        shortDescription = try container.decode(String.self, forKey: .shortDescription)
        fullDescription = try container.decode(String.self, forKey: .fullDescription)
        icon = try container.decode(String.self, forKey: .icon)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        allowsOnline = try container.decode(Bool.self, forKey: .allowsOnline)
        stripeProductId = try container.decode(String.self, forKey: .stripeProductId)
        
        // Handle prerequisites as JSON array
        if let prereqArray = try? container.decode([String].self, forKey: .prerequisites) {
            prerequisites = prereqArray
        } else {
            prerequisites = []
        }
        
        // Handle date decoding
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let createdString = try? container.decode(String.self, forKey: .createdAt),
           let date = dateFormatter.date(from: createdString) {
            createdAt = date
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        if let updatedString = try? container.decode(String.self, forKey: .updatedAt),
           let date = dateFormatter.date(from: updatedString) {
            updatedAt = date
        } else {
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        }
    }
    
    // Manual initializer for testing/preview
    init(
        examType: String,
        displayName: String,
        shortDescription: String,
        fullDescription: String,
        icon: String,
        durationMinutes: Int,
        allowsOnline: Bool,
        stripeProductId: String,
        prerequisites: [String],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.examType = examType
        self.displayName = displayName
        self.shortDescription = shortDescription
        self.fullDescription = fullDescription
        self.icon = icon
        self.durationMinutes = durationMinutes
        self.allowsOnline = allowsOnline
        self.stripeProductId = stripeProductId
        self.prerequisites = prerequisites
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Default/fallback configurations used when backend is unavailable
    static let defaultFlightReview = ExamTypeConfig(
        examType: "flight_review",
        displayName: "Flight Review",
        shortDescription: "In-person hands-on flight assessment",
        fullDescription: "The Flight Review is an in-person, hands-on assessment that evaluates your ability to plan and execute a drone flight safely. An examiner will observe your pre-flight procedures, flight execution, and post-flight protocols.",
        icon: "person.text.rectangle.fill",
        durationMinutes: 30,
        allowsOnline: false,
        stripeProductId: "prod_TW3nHwTNX9Xtec",
        prerequisites: ["Passed Ground School Test", "Completed Unit 4 of UAS Pilot Course"]
    )
    
    static let defaultRocA = ExamTypeConfig(
        examType: "roc_a",
        displayName: "ROC-A",
        shortDescription: "Radio communication competency exam",
        fullDescription: "A Restricted Operator Certificate with Aeronautical Qualification (ROC-A) exam demonstrates your competence in operating aeronautical radio equipment. It ensures you understand and can use proper radiotelephone communication procedures with air traffic control.",
        icon: "antenna.radiowaves.left.and.right",
        durationMinutes: 30,
        allowsOnline: true,
        stripeProductId: "prod_TW3nnJ9zKy3tC3",
        prerequisites: ["Passed Ground School Test", "Completed Unit 4 of UAS Pilot Course"]
    )
    
    static let defaultGroundSchoolTest = ExamTypeConfig(
        examType: "ground_school_test",
        displayName: "Ground School Test",
        shortDescription: "Essential knowledge assessment for UAS operations",
        fullDescription: "The Ground School Test evaluates your understanding of fundamental UAS pilot training covering airspace, regulations, weather, and safety protocols. Passing this test is required to unlock advanced training units and certification exams.",
        icon: "pencil.line",
        durationMinutes: 60,
        allowsOnline: true,
        stripeProductId: "",
        prerequisites: ["Completed Units 1-3 of UAS Pilot Course"]
    )
    
    /// Get default config for an exam type
    static func defaultConfig(for examType: ExamType) -> ExamTypeConfig {
        switch examType {
        case .flightReview:
            return defaultFlightReview
        case .rocA:
            return defaultRocA
        case .groundSchoolTest:
            return defaultGroundSchoolTest
        }
    }
}

