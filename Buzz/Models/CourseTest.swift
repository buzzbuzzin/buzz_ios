//
//  CourseTest.swift
//  Buzz
//
//  Model for course tests
//

import Foundation

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
    }
}

