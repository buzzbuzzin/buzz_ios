//
//  FlightHourClaim.swift
//  Buzz
//
//  Created for flight hour claims feature
//

import Foundation

struct FlightHourClaim: Codable, Identifiable {
    let id: UUID
    let pilotId: UUID
    let claimedFlights: Int
    let claimedHours: Double
    let notes: String?
    let evidenceFiles: [String]?
    let status: String
    let submittedAt: Date
    let reviewedAt: Date?
    let reviewedBy: UUID?
    let reviewerNotes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case claimedFlights = "claimed_flights"
        case claimedHours = "claimed_hours"
        case notes
        case evidenceFiles = "evidence_files"
        case status
        case submittedAt = "submitted_at"
        case reviewedAt = "reviewed_at"
        case reviewedBy = "reviewed_by"
        case reviewerNotes = "reviewer_notes"
    }

    var statusDisplay: String {
        switch status {
        case "pending": return "Pending"
        case "approved": return "Approved"
        case "rejected": return "Rejected"
        default: return status.capitalized
        }
    }
}

struct FlightHourClaimInsert: Codable {
    let pilotId: UUID
    let claimedFlights: Int
    let claimedHours: Double
    let notes: String?
    let evidenceFiles: [String]?

    enum CodingKeys: String, CodingKey {
        case pilotId = "pilot_id"
        case claimedFlights = "claimed_flights"
        case claimedHours = "claimed_hours"
        case notes
        case evidenceFiles = "evidence_files"
    }
}
