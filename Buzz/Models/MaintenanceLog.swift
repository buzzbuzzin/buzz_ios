//
//  MaintenanceLog.swift
//  Buzz
//
//  Created for maintenance log electronic form
//

import Foundation

struct MaintenanceLog: Codable, Identifiable {
    let id: UUID
    let pilotId: UUID
    
    // Aircraft Info
    let aircraftNumber: String
    let sheetNumber: Int
    
    // Maintenance Entry
    let date: Date
    let repairs: String
    let replacementParts: String?
    let comments: String?
    
    // Signature Data
    let initialsData: String // Base64 encoded PNG
    
    // Metadata
    let createdAt: Date
    let isLocked: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case aircraftNumber = "aircraft_number"
        case sheetNumber = "sheet_number"
        case date
        case repairs
        case replacementParts = "replacement_parts"
        case comments
        case initialsData = "initials_data"
        case createdAt = "created_at"
        case isLocked = "is_locked"
    }
}

struct MaintenanceLogInsert: Codable {
    let pilotId: UUID
    let aircraftNumber: String
    let sheetNumber: Int
    let date: Date
    let repairs: String
    let replacementParts: String?
    let comments: String?
    let initialsData: String
    let isLocked: Bool
    
    enum CodingKeys: String, CodingKey {
        case pilotId = "pilot_id"
        case aircraftNumber = "aircraft_number"
        case sheetNumber = "sheet_number"
        case date
        case repairs
        case replacementParts = "replacement_parts"
        case comments
        case initialsData = "initials_data"
        case isLocked = "is_locked"
    }
}

