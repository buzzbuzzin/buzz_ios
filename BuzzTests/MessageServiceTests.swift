//
//  MessageServiceTests.swift
//  BuzzTests
//
//  Tests for MessageService pure/static methods that don't require network.
//

import XCTest
@testable import Buzz

@MainActor
final class MessageServiceTests: XCTestCase {

    // MARK: - conversationId Static Method

    func testConversationId_isConsistentRegardlessOfOrder() {
        let userA = UUID()
        let userB = UUID()

        let id1 = MessageService.conversationId(fromUserId: userA, toUserId: userB)
        let id2 = MessageService.conversationId(fromUserId: userB, toUserId: userA)

        XCTAssertEqual(id1, id2, "conversationId should be the same regardless of parameter order")
    }

    func testConversationId_differentPairsProduceDifferentIds() {
        let userA = UUID()
        let userB = UUID()
        let userC = UUID()

        let idAB = MessageService.conversationId(fromUserId: userA, toUserId: userB)
        let idAC = MessageService.conversationId(fromUserId: userA, toUserId: userC)

        XCTAssertNotEqual(idAB, idAC, "Different user pairs should produce different conversation IDs")
    }

    func testConversationId_sameInputsProduceSameOutput() {
        let userA = UUID()
        let userB = UUID()

        let id1 = MessageService.conversationId(fromUserId: userA, toUserId: userB)
        let id2 = MessageService.conversationId(fromUserId: userA, toUserId: userB)

        XCTAssertEqual(id1, id2, "Same inputs should always produce the same conversation ID")
    }

    func testConversationId_returnsValidUUID() {
        let userA = UUID()
        let userB = UUID()

        let id = MessageService.conversationId(fromUserId: userA, toUserId: userB)

        // UUID should have valid format (not nil)
        XCTAssertNotNil(UUID(uuidString: id.uuidString))
    }

    func testDirectConversationFilter_matchesBothDirections() {
        let userA = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let userB = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        let filter = MessageService.directConversationFilter(userAId: userA, userBId: userB)

        XCTAssertEqual(
            filter,
            "and(from_user_id.eq.00000000-0000-0000-0000-000000000001,to_user_id.eq.00000000-0000-0000-0000-000000000002),and(from_user_id.eq.00000000-0000-0000-0000-000000000002,to_user_id.eq.00000000-0000-0000-0000-000000000001)"
        )
    }

    func testDirectConversationFilter_isOrderSymmetric() {
        let userA = UUID()
        let userB = UUID()

        let filterAB = MessageService.directConversationFilter(userAId: userA, userBId: userB)
        let filterBA = MessageService.directConversationFilter(userAId: userB, userBId: userA)

        XCTAssertEqual(filterAB, filterBA)
    }
}
