//
//  DirectMessage.swift
//  Buzz
//
//  Created for direct messaging between users
//

import Foundation

struct DirectMessage: Codable, Identifiable {
    let id: UUID
    let fromUserId: UUID
    let toUserId: UUID
    let text: String
    let createdAt: Date
    var isRead: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case text
        case createdAt = "created_at"
        case isRead = "is_read"
    }
}

struct DirectMessageConversation: Identifiable {
    let id: UUID
    let partnerId: UUID
    let lastMessage: DirectMessage
    
    init(partnerId: UUID, lastMessage: DirectMessage) {
        self.id = partnerId // Use partnerId as ID for uniqueness
        self.partnerId = partnerId
        self.lastMessage = lastMessage
    }
}

