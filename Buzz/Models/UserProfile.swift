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

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let userType: UserType
    let firstName: String?
    let lastName: String?
    let callSign: String?
    let email: String?
    let phone: String?
    let profilePictureUrl: String?
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
        case createdAt = "created_at"
    }
    
    var fullName: String {
        let components = [firstName, lastName].compactMap { $0 }
        return components.isEmpty ? "User" : components.joined(separator: " ")
    }
}

