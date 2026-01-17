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
    let requiredForProgression: Bool
    let requiredUnits: [Int]
    let orderIndex: Int
    let isActive: Bool
    let sectionId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id
        case courseId = "course_id"
        case testName = "test_name"
        case testDescription = "test_description"
        case testType = "test_type"
        case passingScore = "passing_score"
        case requiredForProgression = "required_for_progression"
        case requiredUnits = "required_units"
        case orderIndex = "order_index"
        case isActive = "is_active"
        case sectionId = "section_id"
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

