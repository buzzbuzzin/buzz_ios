//
//  DroneRegistration.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation

struct DroneRegistration: Codable, Identifiable {
    let id: UUID
    let pilotId: UUID
    let fileUrl: String
    let fileType: RegistrationFileType
    let uploadedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case fileUrl = "file_url"
        case fileType = "file_type"
        case uploadedAt = "uploaded_at"
    }
}

enum RegistrationFileType: String, Codable {
    case pdf
    case image
}

