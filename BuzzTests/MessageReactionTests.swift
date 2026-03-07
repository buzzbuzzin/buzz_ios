//
//  MessageReactionTests.swift
//  BuzzTests
//

import XCTest
@testable import Buzz

final class MessageReactionTests: XCTestCase {

    func testMessageDecodesWithoutReactionPayload() throws {
        let data = Data(
            """
            {
              "id": "00000000-0000-0000-0000-000000000001",
              "booking_id": "00000000-0000-0000-0000-000000000002",
              "from_user_id": "00000000-0000-0000-0000-000000000003",
              "to_user_id": "00000000-0000-0000-0000-000000000004",
              "text": "Hello",
              "created_at": "2026-03-06T18:00:00Z",
              "is_read": false
            }
            """.utf8
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let message = try decoder.decode(Message.self, from: data)

        XCTAssertTrue(message.reactions.isEmpty)
    }

    func testDirectMessageDecodesWithoutReactionPayload() throws {
        let data = Data(
            """
            {
              "id": "00000000-0000-0000-0000-000000000011",
              "from_user_id": "00000000-0000-0000-0000-000000000012",
              "to_user_id": "00000000-0000-0000-0000-000000000013",
              "text": "Hi there",
              "created_at": "2026-03-06T18:00:00Z",
              "is_read": true,
              "metadata": null
            }
            """.utf8
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let message = try decoder.decode(DirectMessage.self, from: data)

        XCTAssertTrue(message.reactions.isEmpty)
    }

    func testCurrentReactionReturnsUsersReaction() {
        let currentUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
        let otherUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000022")!
        let reactions = [
            makeReaction(id: "00000000-0000-0000-0000-000000000031", userId: otherUserId, reaction: .haha),
            makeReaction(id: "00000000-0000-0000-0000-000000000032", userId: currentUserId, reaction: .love)
        ]

        XCTAssertEqual(reactions.currentReaction(for: currentUserId), .love)
    }

    func testAggregateSummariesCountsAndHighlightsCurrentUserReaction() {
        let currentUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000041")!
        let reactions = [
            makeReaction(id: "00000000-0000-0000-0000-000000000051", userId: currentUserId, reaction: .like),
            makeReaction(id: "00000000-0000-0000-0000-000000000052", userId: UUID(), reaction: .like),
            makeReaction(id: "00000000-0000-0000-0000-000000000053", userId: UUID(), reaction: .question)
        ]

        let summaries = reactions.aggregateSummaries(currentUserId: currentUserId)

        XCTAssertEqual(summaries.map(\.reaction), [.like, .question])
        XCTAssertEqual(summaries.first?.count, 2)
        XCTAssertEqual(summaries.first?.includesCurrentUser, true)
        XCTAssertEqual(summaries.last?.count, 1)
        XCTAssertEqual(summaries.last?.includesCurrentUser, false)
    }

    func testApplyingReactionReplacesExistingReactionForSameUser() {
        let currentUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000061")!
        let otherUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000062")!
        let updated = [
            makeReaction(id: "00000000-0000-0000-0000-000000000071", userId: currentUserId, reaction: .like),
            makeReaction(id: "00000000-0000-0000-0000-000000000072", userId: otherUserId, reaction: .haha)
        ].applyingReaction(.love, by: currentUserId)

        XCTAssertEqual(updated.count, 2)
        XCTAssertEqual(updated.currentReaction(for: currentUserId), .love)
        XCTAssertEqual(updated.currentReaction(for: otherUserId), .haha)
    }

    func testRemovingReactionDeletesOnlyCurrentUsersReaction() {
        let currentUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000081")!
        let otherUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000082")!
        let updated = [
            makeReaction(id: "00000000-0000-0000-0000-000000000091", userId: currentUserId, reaction: .emphasize),
            makeReaction(id: "00000000-0000-0000-0000-000000000092", userId: otherUserId, reaction: .question)
        ].removingReaction(by: currentUserId)

        XCTAssertNil(updated.currentReaction(for: currentUserId))
        XCTAssertEqual(updated.currentReaction(for: otherUserId), .question)
        XCTAssertEqual(updated.count, 1)
    }

    private func makeReaction(id: String, userId: UUID, reaction: MessageReactionType) -> MessageReactionRecord {
        MessageReactionRecord(
            id: UUID(uuidString: id)!,
            userId: userId,
            reaction: reaction,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
