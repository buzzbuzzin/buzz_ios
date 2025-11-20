//
//  ExpressPromotionApplication.swift
//  Buzz
//
//  Created for Express Promotion feature
//

import Foundation

struct ExpressPromotionApplication: Codable, Identifiable {
    let id: UUID
    let pilotId: UUID
    let promotionType: PromotionType
    let documentType: DocumentType
    let documentUrls: [String]
    let status: Status
    let targetTier: Int
    let submittedAt: Date
    let reviewedAt: Date?
    let reviewedBy: UUID?
    let rejectionReason: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum PromotionType: String, Codable {
        case lieutenant = "lieutenant"
        case commander = "commander"
        
        var displayName: String {
            switch self {
            case .lieutenant: return "Lieutenant"
            case .commander: return "Commander"
            }
        }
    }
    
    enum DocumentType: String, Codable {
        case aviationDegree = "aviation_degree"
        case ppl = "ppl"
        case groundSchoolTest = "ground_school_test"
        
        var displayName: String {
            switch self {
            case .aviationDegree: return "Aviation Degree"
            case .ppl: return "Private Pilot License (PPL)"
            case .groundSchoolTest: return "Ground School Test Certificate"
            }
        }
    }
    
    enum Status: String, Codable {
        case pending = "pending"
        case inReview = "in_review"
        case verified = "verified"
        case rejected = "rejected"
        
        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .inReview: return "In Review"
            case .verified: return "Verified"
            case .rejected: return "Rejected"
            }
        }
        
        var color: String {
            switch self {
            case .pending: return "orange"
            case .inReview: return "blue"
            case .verified: return "green"
            case .rejected: return "red"
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case promotionType = "promotion_type"
        case documentType = "document_type"
        case documentUrls = "document_urls"
        case status
        case targetTier = "target_tier"
        case submittedAt = "submitted_at"
        case reviewedAt = "reviewed_at"
        case reviewedBy = "reviewed_by"
        case rejectionReason = "rejection_reason"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

