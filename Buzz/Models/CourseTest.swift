//
//  CourseTest.swift
//  Buzz
//
//  Model for course tests
//

import Foundation
import SwiftUI

struct CourseTest: Identifiable, Codable {
    let id: UUID
    let courseId: UUID
    let testName: String
    let testDescription: String?
    let testType: String
    let passingScore: Int
    let duration: Int? // Duration in minutes
    let requiredForProgression: Bool
    let requiredUnits: [UUID]
    let orderIndex: Int
    let isActive: Bool
    let sectionId: UUID?
    let needsProctor: Bool
    let priceOfSchedule: Int? // Price in cents (e.g., 9900 for $99.00)
    
    enum CodingKeys: String, CodingKey {
        case id
        case courseId = "course_id"
        case testName = "test_name"
        case testDescription = "test_description"
        case testType = "test_type"
        case passingScore = "passing_score"
        case duration
        case requiredForProgression = "required_for_progression"
        case requiredUnits = "required_units"
        case orderIndex = "order_index"
        case isActive = "is_active"
        case sectionId = "section_id"
        case needsProctor = "needs_proctor"
        case priceOfSchedule = "price_of_schedule"
    }
    
    // Custom decoder to handle null required_units from database
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        courseId = try container.decode(UUID.self, forKey: .courseId)
        testName = try container.decode(String.self, forKey: .testName)
        testDescription = try container.decodeIfPresent(String.self, forKey: .testDescription)
        testType = try container.decode(String.self, forKey: .testType)
        passingScore = try container.decode(Int.self, forKey: .passingScore)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        requiredForProgression = try container.decode(Bool.self, forKey: .requiredForProgression)
        // Handle null required_units by defaulting to empty array
        requiredUnits = (try? container.decode([UUID].self, forKey: .requiredUnits)) ?? []
        orderIndex = try container.decode(Int.self, forKey: .orderIndex)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        sectionId = try container.decodeIfPresent(UUID.self, forKey: .sectionId)
        needsProctor = try container.decode(Bool.self, forKey: .needsProctor)
        priceOfSchedule = try container.decodeIfPresent(Int.self, forKey: .priceOfSchedule)
    }
    
    /// Returns formatted price string (e.g., "$99.00")
    var formattedPrice: String {
        guard let price = priceOfSchedule else { return "Free" }
        if price == 0 { return "Free" }
        
        let amount = Double(price) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

struct TestResult: Identifiable, Codable {
    let id: UUID
    let pilotId: UUID
    let testId: UUID
    let courseId: UUID
    let score: Int
    let passed: Bool
    let answers: [String: Int]?
    let attemptNumber: Int
    let completedAt: Date
    let resultFileUrls: [String]?
    let uploadStatus: String?
    let uploadedAt: Date?
    let reviewedAt: Date?
    let reviewerNotes: String?
    let reviewedBy: UUID?
    let proctorName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case testId = "test_id"
        case courseId = "course_id"
        case score
        case passed
        case answers
        case attemptNumber = "attempt_number"
        case completedAt = "completed_at"
        case resultFileUrls = "result_file_urls"
        case uploadStatus = "upload_status"
        case uploadedAt = "uploaded_at"
        case reviewedAt = "reviewed_at"
        case reviewerNotes = "reviewer_notes"
        case reviewedBy = "reviewed_by"
        case proctorName = "proctor_name"
    }
}

enum TestUploadStatus: String, Codable {
    case notSubmitted = "not_submitted"
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    
    var displayName: String {
        switch self {
        case .notSubmitted: return "Not Submitted"
        case .pending: return "Under Review"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        }
    }
    
    var color: Color {
        switch self {
        case .notSubmitted: return .gray
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }
}

extension TestResult {
    var uploadStatusEnum: TestUploadStatus {
        guard let status = uploadStatus else { return .notSubmitted }
        return TestUploadStatus(rawValue: status) ?? .notSubmitted
    }
}

// MARK: - Test Question Model

struct TestQuestion: Identifiable, Codable, Hashable {
    let id: UUID
    let testId: UUID
    let questionNumber: Int
    let questionArea: String?
    let questionText: String
    let options: [String]
    let correctAnswerIndex: Int
    let explanation: String?
    let imageUrls: [String]
    let problemSets: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case testId = "test_id"
        case questionNumber = "question_number"
        case questionArea = "question_area"
        case questionText = "question_text"
        case options
        case correctAnswerIndex = "correct_answer_index"
        case explanation
        case imageUrls = "image_urls"
        case problemSets = "problem_sets"
    }
    
    // Custom decoder to handle JSONB options field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        testId = try container.decode(UUID.self, forKey: .testId)
        questionNumber = try container.decode(Int.self, forKey: .questionNumber)
        questionArea = try container.decodeIfPresent(String.self, forKey: .questionArea)
        questionText = try container.decode(String.self, forKey: .questionText)
        correctAnswerIndex = try container.decode(Int.self, forKey: .correctAnswerIndex)
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
        imageUrls = (try? container.decode([String].self, forKey: .imageUrls)) ?? []
        problemSets = try? container.decodeIfPresent([Int].self, forKey: .problemSets)
        
        // Handle options - can be JSONB array or string array
        if let optionsArray = try? container.decode([String].self, forKey: .options) {
            options = optionsArray
        } else {
            options = []
        }
    }
    
    // Standard initializer for testing/manual creation
    init(id: UUID, testId: UUID, questionNumber: Int, questionArea: String? = nil, 
         questionText: String, options: [String], correctAnswerIndex: Int, 
         explanation: String? = nil, imageUrls: [String] = [], problemSets: [Int]? = nil) {
        self.id = id
        self.testId = testId
        self.questionNumber = questionNumber
        self.questionArea = questionArea
        self.questionText = questionText
        self.options = options
        self.correctAnswerIndex = correctAnswerIndex
        self.explanation = explanation
        self.imageUrls = imageUrls
        self.problemSets = problemSets
    }
}
