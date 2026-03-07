//
//  DirectMessage.swift
//  Buzz
//
//  Created for direct messaging between users
//

import Foundation

// MARK: - Rich Message Metadata

struct DirectMessageListingCard: Codable {
    let listingId: UUID
    let title: String
    let price: String
    let imageUrl: String?
    let condition: String?

    enum CodingKeys: String, CodingKey {
        case listingId = "listing_id"
        case title, price
        case imageUrl = "image_url"
        case condition
    }
}

struct DirectMessageMetadata: Codable {
    let type: String
    let listingCard: DirectMessageListingCard?

    enum CodingKeys: String, CodingKey {
        case type
        case listingCard = "listing_card"
    }
}

// MARK: - Direct Message

struct DirectMessage: Codable, Identifiable {
    let id: UUID
    let fromUserId: UUID
    let toUserId: UUID
    let text: String
    let createdAt: Date
    var isRead: Bool
    let metadata: DirectMessageMetadata?
    var reactions: [MessageReactionRecord] = []

    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case text
        case createdAt = "created_at"
        case isRead = "is_read"
        case metadata
    }

    var isListingCard: Bool {
        metadata?.type == "listing_card" && metadata?.listingCard != nil
    }
}

// MARK: - Insert Payload (for Supabase Codable insert)

struct DirectMessageInsert: Encodable {
    let fromUserId: UUID
    let toUserId: UUID
    let text: String
    let isRead: Bool
    let metadata: DirectMessageMetadata?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case text
        case isRead = "is_read"
        case metadata
        case createdAt = "created_at"
    }
}

struct DirectMessageConversation: Identifiable {
    let id: UUID
    let partnerId: UUID
    let lastMessage: DirectMessage
}
