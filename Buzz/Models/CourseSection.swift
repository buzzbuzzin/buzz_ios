//
//  CourseSection.swift
//  Buzz
//
//  Created by Xinyu Fang on 12/2/25.
//

import Foundation

struct CourseSection: Identifiable, Codable {
    let id: UUID
    let courseId: UUID
    let name: String
    let displayOrder: Int
    let description: String?
    let sectionType: String  // 'units', 'test', 'recurrent', 'exam'
    let requiresSubscription: Bool
    let requiresTestPassed: Bool
    let prerequisiteSectionId: UUID?
    let isActive: Bool
    let examType: String?  // For 'exam' sections: 'flight_review' or 'roc_a'
    
    enum CodingKeys: String, CodingKey {
        case id
        case courseId = "course_id"
        case name
        case displayOrder = "display_order"
        case description
        case sectionType = "section_type"
        case requiresSubscription = "requires_subscription"
        case requiresTestPassed = "requires_test_passed"
        case prerequisiteSectionId = "prerequisite_section_id"
        case isActive = "is_active"
        case examType = "exam_type"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        courseId = try container.decode(UUID.self, forKey: .courseId)
        name = try container.decode(String.self, forKey: .name)
        displayOrder = try container.decode(Int.self, forKey: .displayOrder)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        sectionType = try container.decodeIfPresent(String.self, forKey: .sectionType) ?? "units"
        requiresSubscription = try container.decodeIfPresent(Bool.self, forKey: .requiresSubscription) ?? false
        requiresTestPassed = try container.decodeIfPresent(Bool.self, forKey: .requiresTestPassed) ?? false
        prerequisiteSectionId = try container.decodeIfPresent(UUID.self, forKey: .prerequisiteSectionId)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        examType = try container.decodeIfPresent(String.self, forKey: .examType)
    }
}

