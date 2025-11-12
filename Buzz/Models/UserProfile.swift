//
//  UserProfile.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import Foundation

enum UserType: String, Codable {
    case pilot
    case customer
}

enum CommunicationPreference: String, Codable {
    case email = "email"
    case text = "text"
    case both = "both"
    
    var displayName: String {
        switch self {
        case .email: return "Email"
        case .text: return "Text Message"
        case .both: return "Both"
        }
    }
}

enum Gender: String, Codable, CaseIterable {
    case male = "male"
    case female = "female"
    case other = "other"
    case preferNotToSay = "prefer_not_to_say"
    
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

enum CustomerRole: String, Codable, CaseIterable {
    case individual = "individual"
    case manager = "manager"
    case employee = "employee"
    case businessOwner = "business_owner"
    
    var displayName: String {
        switch self {
        case .individual: return "Individual"
        case .manager: return "Manager"
        case .employee: return "Employee"
        case .businessOwner: return "Business owner"
        }
    }
    
    var icon: String {
        switch self {
        case .individual: return "person.fill"
        case .manager: return "person.2.fill"
        case .employee: return "person.badge.plus.fill"
        case .businessOwner: return "building.2.fill"
        }
    }
}

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let userType: UserType
    let firstName: String?
    let lastName: String?
    let callSign: String?
    let email: String?
    let phone: String?
    let gender: Gender?
    let profilePictureUrl: String?
    let communicationPreference: CommunicationPreference?
    let role: CustomerRole? // Customer role (only for customers)
    let specialization: BookingSpecialization? // Customer specialization preference (only for customers)
    let createdAt: Date
    let balance: Decimal? // Pilot balance (earnings + tips)
    let stripeAccountId: String? // Stripe Connect account ID for pilots
    
    enum CodingKeys: String, CodingKey {
        case id
        case userType = "user_type"
        case firstName = "first_name"
        case lastName = "last_name"
        case callSign = "call_sign"
        case email
        case phone
        case gender
        case profilePictureUrl = "profile_picture_url"
        case communicationPreference = "communication_preference"
        case role
        case specialization
        case createdAt = "created_at"
        case balance
        case stripeAccountId = "stripe_account_id"
    }
    
    var fullName: String {
        let components = [firstName, lastName].compactMap { $0 }
        return components.isEmpty ? "User" : components.joined(separator: " ")
    }
}

