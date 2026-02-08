//
//  HangarHelp.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/7/26.
//

import Foundation

// MARK: - Hangar Topic

struct HangarTopic: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let iconName: String
    let colorName: String
    let displayOrder: Int
    let isActive: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case iconName = "icon_name"
        case colorName = "color_name"
        case displayOrder = "display_order"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

// MARK: - Hangar Post

struct HangarPost: Codable, Identifiable {
    let id: UUID
    let topicId: UUID
    let authorId: UUID
    let title: String
    let body: String
    let likeCount: Int
    let commentCount: Int
    let isPinned: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case topicId = "topic_id"
        case authorId = "author_id"
        case title
        case body
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case isPinned = "is_pinned"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Hangar Post Insert

struct HangarPostInsert: Codable {
    let topicId: UUID
    let authorId: UUID
    let title: String
    let body: String

    enum CodingKeys: String, CodingKey {
        case topicId = "topic_id"
        case authorId = "author_id"
        case title
        case body
    }
}

// MARK: - Hangar Post with Author (for display)

struct HangarPostWithAuthor: Identifiable {
    let id: UUID
    let post: HangarPost
    let authorCallSign: String?
    let authorProfilePictureUrl: String?
    let authorFullName: String
    var isLikedByCurrentUser: Bool
    var isSavedByCurrentUser: Bool
    var isFollowedByCurrentUser: Bool
    let topicName: String
    let topicIconName: String
    let topicColorName: String
}

// MARK: - Hangar Comment

struct HangarComment: Codable, Identifiable {
    let id: UUID
    let postId: UUID
    let parentCommentId: UUID?
    let authorId: UUID
    let body: String
    let likeCount: Int
    let depth: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case parentCommentId = "parent_comment_id"
        case authorId = "author_id"
        case body
        case likeCount = "like_count"
        case depth
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Hangar Comment Insert

struct HangarCommentInsert: Codable {
    let postId: UUID
    let parentCommentId: UUID?
    let authorId: UUID
    let body: String
    let depth: Int

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case parentCommentId = "parent_comment_id"
        case authorId = "author_id"
        case body
        case depth
    }
}

// MARK: - Hangar Comment with Author (for display)

struct HangarCommentWithAuthor: Identifiable {
    let id: UUID
    let comment: HangarComment
    let authorCallSign: String?
    let authorProfilePictureUrl: String?
    let authorFullName: String
    var isLikedByCurrentUser: Bool
    var isSavedByCurrentUser: Bool
    var isFollowedByCurrentUser: Bool
    var replies: [HangarCommentWithAuthor]
}

// MARK: - Hangar Like

struct HangarLike: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let postId: UUID?
    let commentId: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case postId = "post_id"
        case commentId = "comment_id"
        case createdAt = "created_at"
    }
}

// MARK: - Hangar Saved Post

struct HangarSavedPost: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let postId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case postId = "post_id"
        case createdAt = "created_at"
    }
}

// MARK: - Hangar Followed Post

struct HangarFollowedPost: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let postId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case postId = "post_id"
        case createdAt = "created_at"
    }
}

// MARK: - Hangar Hidden Post

struct HangarHiddenPost: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let postId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case postId = "post_id"
        case createdAt = "created_at"
    }
}

// MARK: - Hangar Saved Comment

struct HangarSavedComment: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let commentId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case commentId = "comment_id"
        case createdAt = "created_at"
    }
}

// MARK: - Hangar Followed Comment

struct HangarFollowedComment: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let commentId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case commentId = "comment_id"
        case createdAt = "created_at"
    }
}

// MARK: - Supabase Join Response Models

struct HangarPostResponse: Codable {
    let id: UUID
    let topicId: UUID
    let authorId: UUID
    let title: String
    let body: String
    let likeCount: Int
    let commentCount: Int
    let isPinned: Bool
    let createdAt: Date
    let updatedAt: Date
    let profiles: HangarAuthorProfileOrArray?
    let hangarTopics: HangarTopicInfoOrArray?

    enum CodingKeys: String, CodingKey {
        case id
        case topicId = "topic_id"
        case authorId = "author_id"
        case title
        case body
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case isPinned = "is_pinned"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case profiles
        case hangarTopics = "hangar_topics"
    }

    var profileData: HangarAuthorProfile? {
        switch profiles {
        case .single(let profile): return profile
        case .array(let profiles): return profiles.first
        case .none: return nil
        }
    }

    var topicData: HangarTopicInfo? {
        switch hangarTopics {
        case .single(let topic): return topic
        case .array(let topics): return topics.first
        case .none: return nil
        }
    }

    func toHangarPost() -> HangarPost {
        HangarPost(
            id: id,
            topicId: topicId,
            authorId: authorId,
            title: title,
            body: body,
            likeCount: likeCount,
            commentCount: commentCount,
            isPinned: isPinned,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct HangarCommentResponse: Codable {
    let id: UUID
    let postId: UUID
    let parentCommentId: UUID?
    let authorId: UUID
    let body: String
    let likeCount: Int
    let depth: Int
    let createdAt: Date
    let updatedAt: Date
    let profiles: HangarAuthorProfileOrArray?

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case parentCommentId = "parent_comment_id"
        case authorId = "author_id"
        case body
        case likeCount = "like_count"
        case depth
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case profiles
    }

    var profileData: HangarAuthorProfile? {
        switch profiles {
        case .single(let profile): return profile
        case .array(let profiles): return profiles.first
        case .none: return nil
        }
    }

    func toHangarComment() -> HangarComment {
        HangarComment(
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
}

// Handles Supabase join returning either a single profile object or an array
enum HangarAuthorProfileOrArray: Codable {
    case single(HangarAuthorProfile?)
    case array([HangarAuthorProfile])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([HangarAuthorProfile].self) {
            self = .array(array)
        } else if let single = try? container.decode(HangarAuthorProfile.self) {
            self = .single(single)
        } else {
            self = .single(nil)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let profile):
            if let profile = profile {
                try container.encode(profile)
            } else {
                try container.encodeNil()
            }
        case .array(let profiles):
            try container.encode(profiles)
        }
    }
}

struct HangarAuthorProfile: Codable {
    let id: UUID
    let callSign: String?
    let profilePictureUrl: String?
    let firstName: String?
    let lastName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case callSign = "call_sign"
        case profilePictureUrl = "profile_picture_url"
        case firstName = "first_name"
        case lastName = "last_name"
    }

    var fullName: String {
        let components = [firstName, lastName].compactMap { $0 }
        return components.isEmpty ? "Pilot" : components.joined(separator: " ")
    }
}

// MARK: - Topic Info (from Supabase join)

struct HangarTopicInfo: Codable {
    let name: String
    let iconName: String
    let colorName: String

    enum CodingKeys: String, CodingKey {
        case name
        case iconName = "icon_name"
        case colorName = "color_name"
    }
}

// MARK: - Activity Feed Models

enum HangarActivityType {
    case newCommentOnFollowedPost
    case replyToFollowedComment
}

struct HangarActivityItem: Identifiable {
    let id: UUID
    let type: HangarActivityType
    let commentBody: String
    let commentAuthorName: String
    let commentAuthorCallSign: String?
    let commentAuthorProfilePictureUrl: String?
    let postId: UUID
    let postTitle: String
    let createdAt: Date
}

struct HangarActivityCommentResponse: Codable {
    let id: UUID
    let postId: UUID
    let parentCommentId: UUID?
    let authorId: UUID
    let body: String
    let createdAt: Date
    let profiles: HangarAuthorProfileOrArray?
    let hangarPosts: HangarActivityPostInfo?

    enum CodingKeys: String, CodingKey {
        case id, body
        case postId = "post_id"
        case parentCommentId = "parent_comment_id"
        case authorId = "author_id"
        case createdAt = "created_at"
        case profiles
        case hangarPosts = "hangar_posts"
    }

    var profileData: HangarAuthorProfile? {
        switch profiles {
        case .single(let p): return p
        case .array(let a): return a.first
        case .none: return nil
        }
    }
}

struct HangarActivityPostInfo: Codable {
    let id: UUID
    let title: String
}

enum HangarTopicInfoOrArray: Codable {
    case single(HangarTopicInfo?)
    case array([HangarTopicInfo])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([HangarTopicInfo].self) {
            self = .array(array)
        } else if let single = try? container.decode(HangarTopicInfo.self) {
            self = .single(single)
        } else {
            self = .single(nil)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let topic):
            if let topic = topic {
                try container.encode(topic)
            } else {
                try container.encodeNil()
            }
        case .array(let topics):
            try container.encode(topics)
        }
    }
}
