//
//  Referral.swift
//  Buzz
//
//  Created for the client referral/loyalty program
//

import Foundation

// MARK: - Referral Code

struct ReferralCode: Codable, Identifiable {
    let id: UUID?
    let userId: UUID
    let code: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case code
        case createdAt = "created_at"
    }
}

// MARK: - Referral Status

enum ReferralStatus: String, Codable {
    case pending = "pending"
    case completed = "completed"
    case expired = "expired"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending Verification"
        case .completed: return "Verified"
        case .expired: return "Expired"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .completed: return "checkmark.circle.fill"
        case .expired: return "xmark.circle.fill"
        }
    }
}

// MARK: - Referral Record

struct Referral: Codable, Identifiable {
    let id: UUID
    let referrerId: UUID
    let refereeId: UUID
    let referralCode: String
    let status: ReferralStatus
    let creditAmount: Decimal
    let creditedAt: Date?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case referrerId = "referrer_id"
        case refereeId = "referee_id"
        case referralCode = "referral_code"
        case status
        case creditAmount = "credit_amount"
        case creditedAt = "credited_at"
        case createdAt = "created_at"
    }
}

// MARK: - Referral Stats Response (from edge function)

struct ReferralStats: Codable {
    let referralCode: String?
    let totalReferrals: Int
    let completedReferrals: Int
    let pendingReferrals: Int
    let totalCreditsEarned: Double
    let availableCredits: Double
    let referralHistory: [ReferralHistoryItem]
    
    enum CodingKeys: String, CodingKey {
        case referralCode = "referral_code"
        case totalReferrals = "total_referrals"
        case completedReferrals = "completed_referrals"
        case pendingReferrals = "pending_referrals"
        case totalCreditsEarned = "total_credits_earned"
        case availableCredits = "available_credits"
        case referralHistory = "referral_history"
    }
}

// MARK: - Referral History Item (from edge function)

struct ReferralHistoryItem: Codable, Identifiable {
    let id: String // UUID comes as string from edge function
    let refereeName: String
    let status: ReferralStatus
    let creditAmount: Double
    let creditedAt: String? // Date comes as string from edge function
    let createdAt: String // Date comes as string from edge function
    
    enum CodingKeys: String, CodingKey {
        case id
        case refereeName = "referee_name"
        case status
        case creditAmount = "credit_amount"
        case creditedAt = "credited_at"
        case createdAt = "created_at"
    }
    
    // Computed property to get Date from string
    var createdAtDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: createdAt) ?? Date()
    }
}

// MARK: - Generate Referral Code Response (from edge function)

struct GenerateReferralCodeResponse: Codable {
    let code: String
    let createdAt: String // Date comes as string from edge function
    let isNew: Bool
    
    enum CodingKeys: String, CodingKey {
        case code
        case createdAt = "created_at"
        case isNew = "is_new"
    }
}

// MARK: - Apply Referral Code Response (from edge function)

struct ApplyReferralCodeResponse: Codable {
    let success: Bool
    let referralId: String? // UUID comes as string from edge function
    let referrerId: String? // UUID comes as string from edge function
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case referralId = "referral_id"
        case referrerId = "referrer_id"
        case message
    }
}
