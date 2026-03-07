//
//  MessageReaction.swift
//  Buzz
//
//  Shared reaction models for booking and direct messages.
//

import Foundation

enum MessageReactionType: String, Codable, CaseIterable, Identifiable, Hashable {
    case like
    case dislike
    case love
    case haha
    case emphasize
    case question

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .like:
            return "👍"
        case .dislike:
            return "👎"
        case .love:
            return "❤️"
        case .haha:
            return "😂"
        case .emphasize:
            return "‼️"
        case .question:
            return "❓"
        }
    }

    var label: String {
        switch self {
        case .like:
            return "Like"
        case .dislike:
            return "Dislike"
        case .love:
            return "Love"
        case .haha:
            return "Haha"
        case .emphasize:
            return "Emphasize"
        case .question:
            return "Question"
        }
    }
}

struct MessageReactionRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let reaction: MessageReactionType
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case reaction
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct BookingMessageReactionRow: Codable {
    let id: UUID
    let bookingMessageId: UUID
    let userId: UUID
    let reaction: MessageReactionType
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case bookingMessageId = "booking_message_id"
        case userId = "user_id"
        case reaction
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var record: MessageReactionRecord {
        MessageReactionRecord(
            id: id,
            userId: userId,
            reaction: reaction,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct DirectMessageReactionRow: Codable {
    let id: UUID
    let directMessageId: UUID
    let userId: UUID
    let reaction: MessageReactionType
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case directMessageId = "direct_message_id"
        case userId = "user_id"
        case reaction
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var record: MessageReactionRecord {
        MessageReactionRecord(
            id: id,
            userId: userId,
            reaction: reaction,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct BookingMessageReactionUpsert: Encodable {
    let bookingMessageId: UUID
    let userId: UUID
    let reaction: MessageReactionType
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case bookingMessageId = "booking_message_id"
        case userId = "user_id"
        case reaction
        case updatedAt = "updated_at"
    }
}

struct DirectMessageReactionUpsert: Encodable {
    let directMessageId: UUID
    let userId: UUID
    let reaction: MessageReactionType
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case directMessageId = "direct_message_id"
        case userId = "user_id"
        case reaction
        case updatedAt = "updated_at"
    }
}

struct MessageReactionAggregate: Identifiable, Hashable {
    let reaction: MessageReactionType
    let count: Int
    let includesCurrentUser: Bool

    var id: String { reaction.rawValue }
}

extension Array where Element == MessageReactionRecord {
    func currentReaction(for userId: UUID?) -> MessageReactionType? {
        guard let userId else { return nil }
        return first(where: { $0.userId == userId })?.reaction
    }

    func aggregateSummaries(currentUserId: UUID?) -> [MessageReactionAggregate] {
        let grouped = Dictionary(grouping: self, by: \.reaction)

        return MessageReactionType.allCases.compactMap { reaction in
            guard let matches = grouped[reaction], !matches.isEmpty else {
                return nil
            }

            return MessageReactionAggregate(
                reaction: reaction,
                count: matches.count,
                includesCurrentUser: currentUserId.map { userId in
                    matches.contains(where: { $0.userId == userId })
                } ?? false
            )
        }
    }

    func applyingReaction(_ reaction: MessageReactionType, by userId: UUID, reactionId: UUID = UUID(), timestamp: Date = Date()) -> [MessageReactionRecord] {
        let remaining = filter { $0.userId != userId }
        let next = MessageReactionRecord(
            id: reactionId,
            userId: userId,
            reaction: reaction,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        return remaining + [next]
    }

    func removingReaction(by userId: UUID) -> [MessageReactionRecord] {
        filter { $0.userId != userId }
    }
}
