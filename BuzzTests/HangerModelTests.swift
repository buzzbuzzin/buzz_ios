//
//  HangerModelTests.swift
//  BuzzTests
//
//  Tests for Hanger Help data models: HangerPost, HangerComment,
//  HangerPostWithAuthor, HangerTopic, Codable conformance, etc.
//

import XCTest
@testable import Buzz

final class HangerModelTests: XCTestCase {

    // MARK: - HangerTopic

    func testTopicCreation() {
        let topic = HangerTestData.sampleTopic(name: "Regulations", colorName: "blue")
        XCTAssertEqual(topic.name, "Regulations")
        XCTAssertEqual(topic.colorName, "blue")
        XCTAssertTrue(topic.isActive)
    }

    func testTopicCodingKeys() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "name": "Weather",
            "description": "Forecasts",
            "icon_name": "cloud.sun.bolt.fill",
            "color_name": "cyan",
            "display_order": 4,
            "is_active": true,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let topic = try decoder.decode(HangerTopic.self, from: data)

        XCTAssertEqual(topic.name, "Weather")
        XCTAssertEqual(topic.iconName, "cloud.sun.bolt.fill")
        XCTAssertEqual(topic.colorName, "cyan")
        XCTAssertEqual(topic.displayOrder, 4)
        XCTAssertTrue(topic.isActive)
    }

    // MARK: - HangerPost

    func testPostCreation() {
        let post = HangerTestData.samplePost(
            title: "My Post",
            body: "Body text",
            likeCount: 5,
            commentCount: 3
        )
        XCTAssertEqual(post.title, "My Post")
        XCTAssertEqual(post.body, "Body text")
        XCTAssertEqual(post.likeCount, 5)
        XCTAssertEqual(post.commentCount, 3)
        XCTAssertFalse(post.isPinned)
    }

    func testPostWithImageUrls() {
        let urls = ["https://example.com/img1.jpg", "https://example.com/img2.jpg"]
        let post = HangerTestData.samplePost(imageUrls: urls)
        XCTAssertEqual(post.imageUrls.count, 2)
        XCTAssertEqual(post.imageUrls[0], "https://example.com/img1.jpg")
    }

    func testPostDefaultImageUrlsEmpty() {
        let post = HangerTestData.samplePost()
        XCTAssertTrue(post.imageUrls.isEmpty)
    }

    func testPostPinnedFlag() {
        let pinned = HangerTestData.samplePost(isPinned: true)
        XCTAssertTrue(pinned.isPinned)

        let unpinned = HangerTestData.samplePost(isPinned: false)
        XCTAssertFalse(unpinned.isPinned)
    }

    func testPostCodableRoundTrip() throws {
        let original = HangerTestData.samplePost(
            title: "Roundtrip",
            body: "Testing encoding",
            likeCount: 10,
            imageUrls: ["https://example.com/a.jpg"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HangerPost.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, "Roundtrip")
        XCTAssertEqual(decoded.body, "Testing encoding")
        XCTAssertEqual(decoded.likeCount, 10)
        XCTAssertEqual(decoded.imageUrls, ["https://example.com/a.jpg"])
    }

    func testPostDecodingWithMissingImageUrls() throws {
        // Simulate a JSON response without image_urls (backwards compatibility)
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "topic_id": UUID().uuidString,
            "author_id": UUID().uuidString,
            "title": "Old Post",
            "body": "No images field",
            "like_count": 0,
            "comment_count": 0,
            "is_pinned": false,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let post = try decoder.decode(HangerPost.self, from: data)

        XCTAssertEqual(post.title, "Old Post")
        XCTAssertTrue(post.imageUrls.isEmpty, "imageUrls should default to empty when missing")
    }

    // MARK: - HangerPostInsert

    func testPostInsertEncoding() throws {
        let insert = HangerPostInsert(
            topicId: UUID(),
            authorId: UUID(),
            title: "New Post",
            body: "Insert body",
            imageUrls: ["https://example.com/img.jpg"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(insert)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(dict?["title"] as? String, "New Post")
        XCTAssertEqual(dict?["body"] as? String, "Insert body")
        XCTAssertNotNil(dict?["topic_id"])
        XCTAssertNotNil(dict?["author_id"])
        XCTAssertNotNil(dict?["image_urls"])
    }

    // MARK: - HangerPostWithAuthor

    func testPostWithAuthorDisplaysCallSign() {
        let pwa = HangerTestData.samplePostWithAuthor(
            authorCallSign: "Maverick",
            authorFullName: "John Doe"
        )
        // The view displays callSign when available
        XCTAssertEqual(pwa.authorCallSign, "Maverick")
        XCTAssertEqual(pwa.authorFullName, "John Doe")
    }

    func testPostWithAuthorNilCallSign() {
        let pwa = HangerTestData.samplePostWithAuthor(
            authorCallSign: nil,
            authorFullName: "Jane Doe"
        )
        XCTAssertNil(pwa.authorCallSign)
        XCTAssertEqual(pwa.authorFullName, "Jane Doe")
    }

    func testPostWithAuthorInteractionFlags() {
        var pwa = HangerTestData.samplePostWithAuthor(
            isLikedByCurrentUser: true,
            isSavedByCurrentUser: false,
            isFollowedByCurrentUser: true
        )
        XCTAssertTrue(pwa.isLikedByCurrentUser)
        XCTAssertFalse(pwa.isSavedByCurrentUser)
        XCTAssertTrue(pwa.isFollowedByCurrentUser)

        // Test mutability
        pwa.isLikedByCurrentUser = false
        XCTAssertFalse(pwa.isLikedByCurrentUser)

        pwa.isSavedByCurrentUser = true
        XCTAssertTrue(pwa.isSavedByCurrentUser)
    }

    func testPostWithAuthorTopicInfo() {
        let pwa = HangerTestData.samplePostWithAuthor(
            topicName: "Equipment",
            topicIconName: "wrench.and.screwdriver.fill",
            topicColorName: "orange"
        )
        XCTAssertEqual(pwa.topicName, "Equipment")
        XCTAssertEqual(pwa.topicIconName, "wrench.and.screwdriver.fill")
        XCTAssertEqual(pwa.topicColorName, "orange")
    }

    func testPostWithAuthorImageUrls() {
        let urls = ["https://example.com/1.jpg", "https://example.com/2.jpg", "https://example.com/3.jpg"]
        let pwa = HangerTestData.samplePostWithAuthor(imageUrls: urls)
        XCTAssertEqual(pwa.imageUrls.count, 3)
    }

    // MARK: - HangerComment

    func testCommentCreation() {
        let comment = HangerTestData.sampleComment(
            body: "Great post!",
            likeCount: 3,
            depth: 0
        )
        XCTAssertEqual(comment.body, "Great post!")
        XCTAssertEqual(comment.likeCount, 3)
        XCTAssertEqual(comment.depth, 0)
        XCTAssertNil(comment.parentCommentId)
    }

    func testNestedComment() {
        let parentId = UUID()
        let reply = HangerTestData.sampleComment(
            parentCommentId: parentId,
            body: "Replying to parent",
            depth: 1
        )
        XCTAssertEqual(reply.parentCommentId, parentId)
        XCTAssertEqual(reply.depth, 1)
    }

    func testCommentCodableRoundTrip() throws {
        let original = HangerTestData.sampleComment(
            body: "Encode me",
            likeCount: 7,
            depth: 2
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HangerComment.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.body, "Encode me")
        XCTAssertEqual(decoded.likeCount, 7)
        XCTAssertEqual(decoded.depth, 2)
    }

    // MARK: - HangerCommentWithAuthor

    func testCommentWithAuthorRepliesTree() {
        let reply1 = HangerTestData.sampleCommentWithAuthor(authorCallSign: "Reply1")
        let reply2 = HangerTestData.sampleCommentWithAuthor(authorCallSign: "Reply2")

        let parent = HangerTestData.sampleCommentWithAuthor(
            authorCallSign: "Parent",
            replies: [reply1, reply2]
        )

        XCTAssertEqual(parent.replies.count, 2)
        XCTAssertEqual(parent.replies[0].authorCallSign, "Reply1")
        XCTAssertEqual(parent.replies[1].authorCallSign, "Reply2")
    }

    func testCommentWithAuthorInteractionFlags() {
        var cwa = HangerTestData.sampleCommentWithAuthor(
            isLikedByCurrentUser: false,
            isSavedByCurrentUser: true,
            isFollowedByCurrentUser: false
        )
        XCTAssertFalse(cwa.isLikedByCurrentUser)
        XCTAssertTrue(cwa.isSavedByCurrentUser)
        XCTAssertFalse(cwa.isFollowedByCurrentUser)

        cwa.isFollowedByCurrentUser = true
        XCTAssertTrue(cwa.isFollowedByCurrentUser)
    }

    // MARK: - HangerActivityItem

    func testActivityItemNewComment() {
        let item = HangerTestData.sampleActivityItem(
            type: .newCommentOnFollowedPost,
            commentBody: "Nice drone shot!",
            commentAuthorName: "Jane",
            postTitle: "Sunset Flight"
        )
        XCTAssertEqual(item.commentBody, "Nice drone shot!")
        XCTAssertEqual(item.postTitle, "Sunset Flight")
    }

    func testActivityItemReply() {
        let item = HangerTestData.sampleActivityItem(
            type: .replyToFollowedComment,
            commentAuthorCallSign: "TopGun"
        )
        XCTAssertEqual(item.commentAuthorCallSign, "TopGun")
    }

    // MARK: - HangerViewMode Enum

    func testViewModeRawValues() {
        XCTAssertEqual(HangerViewMode.latest.rawValue, "Latest")
        XCTAssertEqual(HangerViewMode.mostLiked.rawValue, "Most Liked")
        XCTAssertEqual(HangerViewMode.saved.rawValue, "Saved")
        XCTAssertEqual(HangerViewMode.activity.rawValue, "Activity")
    }

    func testViewModeAllCases() {
        XCTAssertEqual(HangerViewMode.allCases.count, 4)
    }

    // MARK: - HangerTimeAgo Helper

    func testTimeAgoJustNow() {
        let result = hangerTimeAgo(Date())
        XCTAssertEqual(result, "Just Now")
    }

    func testTimeAgoMinutes() {
        let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
        let result = hangerTimeAgo(fiveMinutesAgo)
        XCTAssertEqual(result, "5m")
    }

    func testTimeAgoHours() {
        let threeHoursAgo = Date().addingTimeInterval(-3 * 3600)
        let result = hangerTimeAgo(threeHoursAgo)
        XCTAssertEqual(result, "3h")
    }

    func testTimeAgoDays() {
        let twoDaysAgo = Date().addingTimeInterval(-2 * 86400)
        let result = hangerTimeAgo(twoDaysAgo)
        XCTAssertEqual(result, "2d")
    }

    func testTimeAgoWeeks() {
        let twoWeeksAgo = Date().addingTimeInterval(-14 * 86400)
        let result = hangerTimeAgo(twoWeeksAgo)
        XCTAssertEqual(result, "2w")
    }

    func testTimeAgoMonths() {
        let threeMonthsAgo = Date().addingTimeInterval(-90 * 86400)
        let result = hangerTimeAgo(threeMonthsAgo)
        XCTAssertEqual(result, "3mo")
    }

    func testTimeAgoYears() {
        let twoYearsAgo = Date().addingTimeInterval(-730 * 86400)
        let result = hangerTimeAgo(twoYearsAgo)
        XCTAssertEqual(result, "2y")
    }

    // MARK: - HangerLike

    func testLikeCodingKeys() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "user_id": UUID().uuidString,
            "post_id": UUID().uuidString,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let like = try decoder.decode(HangerLike.self, from: data)

        XCTAssertNotNil(like.postId)
        XCTAssertNil(like.commentId)
    }

    func testLikeCommentCodingKeys() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "user_id": UUID().uuidString,
            "comment_id": UUID().uuidString,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let like = try decoder.decode(HangerLike.self, from: data)

        XCTAssertNil(like.postId)
        XCTAssertNotNil(like.commentId)
    }
}
