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

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let userType: UserType
    let firstName: String?
    let lastName: String?
    let callSign: String?
    let email: String?
    let phone: String?
    let profilePictureUrl: String?
    let communicationPreference: CommunicationPreference?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userType = "user_type"
        case firstName = "first_name"
        case lastName = "last_name"
        case callSign = "call_sign"
        case email
        case phone
        case profilePictureUrl = "profile_picture_url"
        case communicationPreference = "communication_preference"
        case createdAt = "created_at"
    }
    
    var fullName: String {
        let components = [firstName, lastName].compactMap { $0 }
        return components.isEmpty ? "User" : components.joined(separator: " ")
    }
}

