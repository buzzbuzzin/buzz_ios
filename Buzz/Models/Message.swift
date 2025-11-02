//
//  Message.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation

struct Message: Codable, Identifiable {
    let id: UUID
    let bookingId: UUID
    let fromUserId: UUID
    let toUserId: UUID
    let text: String
    let createdAt: Date
    var isRead: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case bookingId = "booking_id"
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case text
        case createdAt = "created_at"
        case isRead = "is_read"
    }
}

