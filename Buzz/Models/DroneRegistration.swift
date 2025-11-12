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
    
    // OCR extracted fields
    let registeredOwner: String?
    let manufacturer: String?
    let model: String?
    let serialNumber: String?
    let registrationNumber: String?
    let issued: String?
    let expires: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case fileUrl = "file_url"
        case fileType = "file_type"
        case uploadedAt = "uploaded_at"
        case registeredOwner = "registered_owner"
        case manufacturer = "manufacturer"
        case model = "model"
        case serialNumber = "serial_number"
        case registrationNumber = "registration_number"
        case issued = "issued"
        case expires = "expires"
    }
}

enum RegistrationFileType: String, Codable {
    case pdf
    case image
}

