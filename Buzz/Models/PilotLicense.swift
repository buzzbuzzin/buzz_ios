//
//  PilotLicense.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import Foundation

enum LicenseFileType: String, Codable {
    case pdf
    case image
}

enum LicenseType: String, Codable, CaseIterable {
    case part107 = "Part 107"
    case part107Recurrent = "Part 107 recurrent"
    case part108 = "Part 108"
    case transportCanada = "Transport Canada"
    case custom = "Custom"
    
    var displayName: String {
        switch self {
        case .custom:
            return "Other (Enter license type)"
        default:
            return self.rawValue
        }
    }
}

struct PilotLicense: Codable, Identifiable {
    let id: UUID
    let pilotId: UUID
    let fileUrl: String
    let fileType: LicenseFileType
    let uploadedAt: Date
    
    // License type
    let licenseType: String?
    
    // OCR extracted fields
    let name: String?
    let courseCompleted: String?
    let completionDate: String?
    let certificateNumber: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case fileUrl = "file_url"
        case fileType = "file_type"
        case uploadedAt = "uploaded_at"
        case licenseType = "license_type"
        case name = "name"
        case courseCompleted = "course_completed"
        case completionDate = "completion_date"
        case certificateNumber = "certificate_number"
    }
}

