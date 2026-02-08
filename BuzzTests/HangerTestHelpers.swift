//
//  HangerTestHelpers.swift
//  BuzzTests
//
//  Sample data factories and utilities for Hanger Help tests.
//

import XCTest
import Foundation
@testable import Buzz

// MARK: - Hanger Sample Data Factories

enum HangerTestData {

    // MARK: - Topics

    static func sampleTopic(
        id: UUID = UUID(),
        name: String = "General",
        description: String? = "General discussion",
        iconName: String = "bubble.left.and.bubble.right.fill",
        colorName: String = "green",
        displayOrder: Int = 1,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) -> HangerTopic {
        HangerTopic(
            id: id,
            name: name,
            description: description,
            iconName: iconName,
            colorName: colorName,
            displayOrder: displayOrder,
            isActive: isActive,
            createdAt: createdAt
        )
    }

    // MARK: - Posts

    static func samplePost(
        id: UUID = UUID(),
        topicId: UUID = UUID(),
        authorId: UUID = UUID(),
        title: String = "Test Post Title",
        body: String = "Test post body content",
        likeCount: Int = 0,
        commentCount: Int = 0,
        isPinned: Bool = false,
        imageUrls: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> HangerPost {
        HangerPost(
            id: id,
            topicId: topicId,
            authorId: authorId,
            title: title,
            body: body,
            likeCount: likeCount,
            commentCount: commentCount,
            isPinned: isPinned,
            imageUrls: imageUrls,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Post With Author

    static func samplePostWithAuthor(
        id: UUID = UUID(),
        post: HangerPost? = nil,
        authorCallSign: String? = "TestPilot",
        authorProfilePictureUrl: String? = nil,
        authorFullName: String = "Test Pilot",
        isLikedByCurrentUser: Bool = false,
        isSavedByCurrentUser: Bool = false,
        isFollowedByCurrentUser: Bool = false,
        topicName: String = "General",
        topicIconName: String = "bubble.left.and.bubble.right.fill",
        topicColorName: String = "green",
        imageUrls: [String] = []
    ) -> HangerPostWithAuthor {
        let actualPost = post ?? samplePost(id: id)
        return HangerPostWithAuthor(
            id: id,
            post: actualPost,
            authorCallSign: authorCallSign,
            authorProfilePictureUrl: authorProfilePictureUrl,
            authorFullName: authorFullName,
            isLikedByCurrentUser: isLikedByCurrentUser,
            isSavedByCurrentUser: isSavedByCurrentUser,
            isFollowedByCurrentUser: isFollowedByCurrentUser,
            topicName: topicName,
            topicIconName: topicIconName,
            topicColorName: topicColorName,
            imageUrls: imageUrls
        )
    }

    // MARK: - Comments

    static func sampleComment(
        id: UUID = UUID(),
        postId: UUID = UUID(),
        parentCommentId: UUID? = nil,
        authorId: UUID = UUID(),
        body: String = "Test comment body",
        likeCount: Int = 0,
        depth: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> HangerComment {
        HangerComment(
            id: id,
            postId: postId,
            parentCommentId: parentCommentId,
            authorId: authorId,
            body: body,
            likeCount: likeCount,
            depth: depth,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Comment With Author

    static func sampleCommentWithAuthor(
        id: UUID = UUID(),
        comment: HangerComment? = nil,
        authorCallSign: String? = "TestPilot",
        authorProfilePictureUrl: String? = nil,
        authorFullName: String = "Test Pilot",
        isLikedByCurrentUser: Bool = false,
        isSavedByCurrentUser: Bool = false,
        isFollowedByCurrentUser: Bool = false,
        replies: [HangerCommentWithAuthor] = []
    ) -> HangerCommentWithAuthor {
        let actualComment = comment ?? sampleComment(id: id)
        return HangerCommentWithAuthor(
            id: id,
            comment: actualComment,
            authorCallSign: authorCallSign,
            authorProfilePictureUrl: authorProfilePictureUrl,
            authorFullName: authorFullName,
            isLikedByCurrentUser: isLikedByCurrentUser,
            isSavedByCurrentUser: isSavedByCurrentUser,
            isFollowedByCurrentUser: isFollowedByCurrentUser,
            replies: replies
        )
    }

    // MARK: - Activity Items

    static func sampleActivityItem(
        id: UUID = UUID(),
        type: HangerActivityType = .newCommentOnFollowedPost,
        commentBody: String = "Test activity comment",
        commentAuthorName: String = "Test Pilot",
        commentAuthorCallSign: String? = "TestCS",
        commentAuthorProfilePictureUrl: String? = nil,
        postId: UUID = UUID(),
        postTitle: String = "Test Post",
        createdAt: Date = Date()
    ) -> HangerActivityItem {
        HangerActivityItem(
            id: id,
            type: type,
            commentBody: commentBody,
            commentAuthorName: commentAuthorName,
            commentAuthorCallSign: commentAuthorCallSign,
            commentAuthorProfilePictureUrl: commentAuthorProfilePictureUrl,
            postId: postId,
            postTitle: postTitle,
            createdAt: createdAt
        )
    }

    // MARK: - Topics List (matching seeded data)

    static let allTopicNames = [
        "Regulations", "Equipment", "Best Practices",
        "Weather", "Emergencies", "General"
    ]
}
