//
//  GovernmentID.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation

struct GovernmentID: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let fileUrl: String?
    let fileType: IDFileType?
    let uploadedAt: Date
    let verificationStatus: VerificationStatus
    let stripeSessionId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case fileUrl = "file_url"
        case fileType = "file_type"
        case uploadedAt = "uploaded_at"
        case verificationStatus = "verification_status"
        case stripeSessionId = "stripe_session_id"
    }
    
    init(id: UUID, userId: UUID, fileUrl: String? = nil, fileType: IDFileType? = nil, uploadedAt: Date, verificationStatus: VerificationStatus, stripeSessionId: String? = nil) {
        self.id = id
        self.userId = userId
        self.fileUrl = fileUrl
        self.fileType = fileType
        self.uploadedAt = uploadedAt
        self.verificationStatus = verificationStatus
        self.stripeSessionId = stripeSessionId
    }
}

enum IDFileType: String, Codable {
    case pdf
    case image
}

enum VerificationStatus: String, Codable {
    case pending = "pending"
    case verified = "verified"
    case rejected = "rejected"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .verified: return "Verified"
        case .rejected: return "Rejected"
        }
    }
}

