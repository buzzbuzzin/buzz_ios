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
    let callSign: String?
    let email: String?
    let phone: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userType = "user_type"
        case callSign = "call_sign"
        case email
        case phone
        case createdAt = "created_at"
    }
}

