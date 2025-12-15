//
//  CompletedUnit.swift
//  Buzz
//
//  Model for completed units from unit_completions table
//

import Foundation

struct CompletedUnit: Identifiable, Codable {
    let id: UUID
    let pilotId: UUID
    let unitId: UUID
    let courseId: UUID
    let unitNumber: Int
    let unitTitle: String
    let completedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case unitId = "unit_id"
        case courseId = "course_id"
        case unitNumber = "unit_number"
        case unitTitle = "title"
        case completedAt = "completed_at"
    }
    
    // Computed property to extract display name from title
    // Example: "UNIT 4 - Drone Pilot" becomes "Drone Pilot"
    var displayName: String {
        // Match "UNIT X - Name" pattern (case-insensitive)
        let pattern = "^UNIT\\s+\\d+\\s*-\\s*(.+)$"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: unitTitle, range: NSRange(unitTitle.startIndex..., in: unitTitle)),
           let range = Range(match.range(at: 1), in: unitTitle) {
            return String(unitTitle[range])
        }
        // Fallback to full title if pattern doesn't match
        return unitTitle
    }
}

// Response model for nested Supabase query
struct CompletedUnitResponse: Codable {
    let id: UUID
    let pilotId: UUID
    let unitId: UUID
    let courseId: UUID
    let completedAt: String
    let courseUnits: CourseUnitInfo
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case unitId = "unit_id"
        case courseId = "course_id"
        case completedAt = "completed_at"
        case courseUnits = "course_units"
    }
    
    struct CourseUnitInfo: Codable {
        let unitNumber: Int
        let title: String
        
        enum CodingKeys: String, CodingKey {
            case unitNumber = "unit_number"
            case title
        }
    }
}

