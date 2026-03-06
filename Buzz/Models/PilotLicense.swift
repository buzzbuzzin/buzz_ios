//
//  PilotLicense.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import Foundation
import SwiftUI

enum LicenseApprovalStatus: String, Codable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    case documentDeleted = "document_deleted"

    var displayName: String {
        switch self {
        case .pending: return "Under Review"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .documentDeleted: return "Document Deleted"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        case .documentDeleted: return .gray
        }
    }
}

enum LicenseFileType: String, Codable {
    case pdf
    case image
}

enum LicenseType: String, Codable, CaseIterable {
    case part107 = "Part 107 (US)"
    case part107Recurrent = "Part 107 recurrent (US)"
    case part108 = "Part 108 (US)"
    case rpaPilotCertificate = "RPA Pilot (CAN)"
    case tp15263Advanced = "TP 15263 Advanced (CAN)"
    case tp15263Recency = "TP 15263 Recency (CAN)"
    case tp15530Level1Complex = "TP 15530 Level 1 Complex (CAN)"
    case tp15530Recency = "TP 15530 Recency (CAN)"
    case rocaCertificate = "ROC-A (CAN)"
    case restrictedRadiotelephone = "Restricted Radiotelephone Operator Permit (US)"
    case rpaFlightReviewer = "Flight Reviewer (CAN)"
    case rocaExaminerCertificate = "ROC-A Examiner (CAN)"
    case custom = "Custom"
    
    var displayName: String {
        switch self {
        case .custom:
            return "Other (Enter license type)"
        default:
            return self.rawValue
        }
    }
    
    var category: LicenseCategory {
        switch self {
        case .part107, .part107Recurrent, .part108, .rpaPilotCertificate, .tp15263Advanced, .tp15263Recency, .tp15530Level1Complex, .tp15530Recency:
            return .dronePilot
        case .rocaCertificate, .restrictedRadiotelephone:
            return .radioOperator
        case .rpaFlightReviewer:
            return .flightReviewer
        case .rocaExaminerCertificate:
            return .examiner
        case .custom:
            return .other
        }
    }
}

enum LicenseCategory {
    case dronePilot
    case radioOperator
    case flightReviewer
    case examiner
    case other
    
    var title: String {
        switch self {
        case .dronePilot:
            return "Drone Pilot License"
        case .radioOperator:
            return "Radio Operator Permit Type"
        case .flightReviewer:
            return "Flight Reviewer"
        case .examiner:
            return "Examiner"
        case .other:
            return "Other"
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

    /// Whether this license type requires admin approval
    var needsApproval: Bool {
        guard let type = licenseType else { return false }
        return type == LicenseType.rpaFlightReviewer.rawValue ||
               type == LicenseType.rocaExaminerCertificate.rawValue
    }
}

struct LicenseApprovalRequest: Codable, Identifiable {
    let id: UUID
    let pilotId: UUID
    let licenseId: UUID?
    let licenseType: String
    let fileUrl: String
    let status: String
    let submittedAt: Date
    let reviewedAt: Date?
    let reviewedBy: UUID?
    let reviewerNotes: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case licenseId = "license_id"
        case licenseType = "license_type"
        case fileUrl = "file_url"
        case status
        case submittedAt = "submitted_at"
        case reviewedAt = "reviewed_at"
        case reviewedBy = "reviewed_by"
        case reviewerNotes = "reviewer_notes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var statusEnum: LicenseApprovalStatus? {
        LicenseApprovalStatus(rawValue: status)
    }
}

