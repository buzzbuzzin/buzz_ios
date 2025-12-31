//
//  IncidentLog.swift
//  Buzz
//
//  Created for incident log electronic form
//

import Foundation

struct IncidentLog: Codable, Identifiable {
    let id: UUID
    let bookingId: UUID
    let pilotId: UUID
    
    // Basic Information
    let name: String
    let phoneNumber: String
    let dateOfIncident: Date
    let dateOfReport: Date
    let jobTitle: String?
    let operationName: String?
    let organization: String?
    let pic: String? // Pilot in Command
    let region: String?
    let airspaceClass: String?
    let reportedToPolice: Bool
    let reportedToAtc: Bool
    
    // Incident Details
    let locationOfIncident: String
    let descriptionOfIncident: String
    let nameOfWitness: String?
    
    // Signature Data
    let signatureData: String // Base64 encoded PNG
    let signatureDate: Date
    
    // Metadata
    let createdAt: Date
    let isLocked: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case bookingId = "booking_id"
        case pilotId = "pilot_id"
        case name
        case phoneNumber = "phone_number"
        case dateOfIncident = "date_of_incident"
        case dateOfReport = "date_of_report"
        case jobTitle = "job_title"
        case operationName = "operation_name"
        case organization
        case pic
        case region
        case airspaceClass = "airspace_class"
        case reportedToPolice = "reported_to_police"
        case reportedToAtc = "reported_to_atc"
        case locationOfIncident = "location_of_incident"
        case descriptionOfIncident = "description_of_incident"
        case nameOfWitness = "name_of_witness"
        case signatureData = "signature_data"
        case signatureDate = "signature_date"
        case createdAt = "created_at"
        case isLocked = "is_locked"
    }
}

struct IncidentLogInsert: Codable {
    let bookingId: UUID
    let pilotId: UUID
    let name: String
    let phoneNumber: String
    let dateOfIncident: Date
    let dateOfReport: Date
    let jobTitle: String?
    let operationName: String?
    let organization: String?
    let pic: String?
    let region: String?
    let airspaceClass: String?
    let reportedToPolice: Bool
    let reportedToAtc: Bool
    let locationOfIncident: String
    let descriptionOfIncident: String
    let nameOfWitness: String?
    let signatureData: String
    let signatureDate: Date
    let isLocked: Bool
    
    enum CodingKeys: String, CodingKey {
        case bookingId = "booking_id"
        case pilotId = "pilot_id"
        case name
        case phoneNumber = "phone_number"
        case dateOfIncident = "date_of_incident"
        case dateOfReport = "date_of_report"
        case jobTitle = "job_title"
        case operationName = "operation_name"
        case organization
        case pic
        case region
        case airspaceClass = "airspace_class"
        case reportedToPolice = "reported_to_police"
        case reportedToAtc = "reported_to_atc"
        case locationOfIncident = "location_of_incident"
        case descriptionOfIncident = "description_of_incident"
        case nameOfWitness = "name_of_witness"
        case signatureData = "signature_data"
        case signatureDate = "signature_date"
        case isLocked = "is_locked"
    }
}

