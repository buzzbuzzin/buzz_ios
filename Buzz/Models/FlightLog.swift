//
//  FlightLog.swift
//  Buzz
//
//  Created for flight log electronic form
//

import Foundation

struct FlightLog: Codable, Identifiable {
    let id: UUID
    let pilotId: UUID
    
    // Aircraft Info
    let aircraftNumber: String
    let sheetNumber: Int
    
    // Flight Entry
    let descriptionOfFlight: String
    let date: Date
    let timeOut: Date
    let timeIn: Date
    let totalAirtimeMinutes: Int
    let comments: String?
    
    // Signature Data
    let signatureData: String // Base64 encoded PNG
    
    // Metadata
    let createdAt: Date
    let isLocked: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case aircraftNumber = "aircraft_number"
        case sheetNumber = "sheet_number"
        case descriptionOfFlight = "description_of_flight"
        case date
        case timeOut = "time_out"
        case timeIn = "time_in"
        case totalAirtimeMinutes = "total_airtime_minutes"
        case comments
        case signatureData = "signature_data"
        case createdAt = "created_at"
        case isLocked = "is_locked"
    }
    
    // Helper computed property
    var formattedTotalAirtime: String {
        let hours = totalAirtimeMinutes / 60
        let minutes = totalAirtimeMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct FlightLogInsert: Codable {
    let pilotId: UUID
    let aircraftNumber: String
    let sheetNumber: Int
    let descriptionOfFlight: String
    let date: Date
    let timeOut: Date
    let timeIn: Date
    let totalAirtimeMinutes: Int
    let comments: String?
    let signatureData: String
    let isLocked: Bool
    
    enum CodingKeys: String, CodingKey {
        case pilotId = "pilot_id"
        case aircraftNumber = "aircraft_number"
        case sheetNumber = "sheet_number"
        case descriptionOfFlight = "description_of_flight"
        case date
        case timeOut = "time_out"
        case timeIn = "time_in"
        case totalAirtimeMinutes = "total_airtime_minutes"
        case comments
        case signatureData = "signature_data"
        case isLocked = "is_locked"
    }
}

