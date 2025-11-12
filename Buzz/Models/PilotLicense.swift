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

struct PilotLicense: Codable, Identifiable {
    let id: UUID
    let pilotId: UUID
    let fileUrl: String
    let fileType: LicenseFileType
    let uploadedAt: Date
    
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
        case name = "name"
        case courseCompleted = "course_completed"
        case completionDate = "completion_date"
        case certificateNumber = "certificate_number"
    }
}

