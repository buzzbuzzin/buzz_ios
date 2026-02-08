//
//  HangerHelp.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/7/26.
//

import Foundation

// MARK: - Hanger Topic

struct HangerTopic: Codable, Identifiable {
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

// MARK: - Hanger Post

struct HangerPost: Codable, Identifiable {
    let id: UUID
    let topicId: UUID
    let authorId: UUID
    let title: String
    let body: String
    let likeCount: Int
    let commentCount: Int
    let isPinned: Bool
    let imageUrls: [String]
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
        case imageUrls = "image_urls"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        topicId = try container.decode(UUID.self, forKey: .topicId)
        authorId = try container.decode(UUID.self, forKey: .authorId)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        likeCount = try container.decode(Int.self, forKey: .likeCount)
        commentCount = try container.decode(Int.self, forKey: .commentCount)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        imageUrls = try container.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    init(id: UUID, topicId: UUID, authorId: UUID, title: String, body: String, likeCount: Int, commentCount: Int, isPinned: Bool, imageUrls: [String] = [], createdAt: Date, updatedAt: Date) {
        self.id = id
        self.topicId = topicId
        self.authorId = authorId
        self.title = title
        self.body = body
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.isPinned = isPinned
        self.imageUrls = imageUrls
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Hanger Post Insert

struct HangerPostInsert: Codable {
    let topicId: UUID
    let authorId: UUID
    let title: String
    let body: String
    let imageUrls: [String]

    enum CodingKeys: String, CodingKey {
        case topicId = "topic_id"
        case authorId = "author_id"
        case title
        case body
        case imageUrls = "image_urls"
    }
}

// MARK: - Hanger Post with Author (for display)

struct HangerPostWithAuthor: Identifiable {
    let id: UUID
    let post: HangerPost
    let authorCallSign: String?
    let authorProfilePictureUrl: String?
    let authorFullName: String
    var isLikedByCurrentUser: Bool
    var isSavedByCurrentUser: Bool
    var isFollowedByCurrentUser: Bool
    let topicName: String
    let topicIconName: String
    let topicColorName: String
    let imageUrls: [String]
}

// MARK: - Hanger Comment

struct HangerComment: Codable, Identifiable {
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

// MARK: - Hanger Comment Insert

struct HangerCommentInsert: Codable {
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

// MARK: - Hanger Comment with Author (for display)

struct HangerCommentWithAuthor: Identifiable {
    let id: UUID
    let comment: HangerComment
    let authorCallSign: String?
    let authorProfilePictureUrl: String?
    let authorFullName: String
    var isLikedByCurrentUser: Bool
    var isSavedByCurrentUser: Bool
    var isFollowedByCurrentUser: Bool
    var replies: [HangerCommentWithAuthor]
}

// MARK: - Hanger Like

struct HangerLike: Codable, Identifiable {
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

// MARK: - Hanger Saved Post

struct HangerSavedPost: Codable, Identifiable {
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

// MARK: - Hanger Followed Post

struct HangerFollowedPost: Codable, Identifiable {
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

// MARK: - Hanger Hidden Post

struct HangerHiddenPost: Codable, Identifiable {
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

// MARK: - Hanger Saved Comment

struct HangerSavedComment: Codable, Identifiable {
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

// MARK: - Hanger Followed Comment

struct HangerFollowedComment: Codable, Identifiable {
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

struct HangerPostResponse: Codable {
    let id: UUID
    let topicId: UUID
    let authorId: UUID
    let title: String
    let body: String
    let likeCount: Int
    let commentCount: Int
    let isPinned: Bool
    let imageUrls: [String]
    let createdAt: Date
    let updatedAt: Date
    let profiles: HangerAuthorProfileOrArray?
    let hangerTopics: HangerTopicInfoOrArray?

    enum CodingKeys: String, CodingKey {
        case id
        case topicId = "topic_id"
        case authorId = "author_id"
        case title
        case body
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case isPinned = "is_pinned"
        case imageUrls = "image_urls"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case profiles
        case hangerTopics = "hanger_topics"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        topicId = try container.decode(UUID.self, forKey: .topicId)
        authorId = try container.decode(UUID.self, forKey: .authorId)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        likeCount = try container.decode(Int.self, forKey: .likeCount)
        commentCount = try container.decode(Int.self, forKey: .commentCount)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        imageUrls = try container.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        profiles = try container.decodeIfPresent(HangerAuthorProfileOrArray.self, forKey: .profiles)
        hangerTopics = try container.decodeIfPresent(HangerTopicInfoOrArray.self, forKey: .hangerTopics)
    }

    var profileData: HangerAuthorProfile? {
        switch profiles {
        case .single(let profile): return profile
        case .array(let profiles): return profiles.first
        case .none: return nil
        }
    }

    var topicData: HangerTopicInfo? {
        switch hangerTopics {
        case .single(let topic): return topic
        case .array(let topics): return topics.first
        case .none: return nil
        }
    }

    func toHangerPost() -> HangerPost {
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
}

struct HangerCommentResponse: Codable {
    let id: UUID
    let postId: UUID
    let parentCommentId: UUID?
    let authorId: UUID
    let body: String
    let likeCount: Int
    let depth: Int
    let createdAt: Date
    let updatedAt: Date
    let profiles: HangerAuthorProfileOrArray?

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

    var profileData: HangerAuthorProfile? {
        switch profiles {
        case .single(let profile): return profile
        case .array(let profiles): return profiles.first
        case .none: return nil
        }
    }

    func toHangerComment() -> HangerComment {
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
}

// Handles Supabase join returning either a single profile object or an array
enum HangerAuthorProfileOrArray: Codable {
    case single(HangerAuthorProfile?)
    case array([HangerAuthorProfile])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([HangerAuthorProfile].self) {
            self = .array(array)
        } else if let single = try? container.decode(HangerAuthorProfile.self) {
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

struct HangerAuthorProfile: Codable {
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

struct HangerTopicInfo: Codable {
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

enum HangerActivityType {
    case newCommentOnFollowedPost
    case replyToFollowedComment
}

struct HangerActivityItem: Identifiable {
    let id: UUID
    let type: HangerActivityType
    let commentBody: String
    let commentAuthorName: String
    let commentAuthorCallSign: String?
    let commentAuthorProfilePictureUrl: String?
    let postId: UUID
    let postTitle: String
    let createdAt: Date
}

struct HangerActivityCommentResponse: Codable {
    let id: UUID
    let postId: UUID
    let parentCommentId: UUID?
    let authorId: UUID
    let body: String
    let createdAt: Date
    let profiles: HangerAuthorProfileOrArray?
    let hangerPosts: HangerActivityPostInfo?

    enum CodingKeys: String, CodingKey {
        case id, body
        case postId = "post_id"
        case parentCommentId = "parent_comment_id"
        case authorId = "author_id"
        case createdAt = "created_at"
        case profiles
        case hangerPosts = "hanger_posts"
    }

    var profileData: HangerAuthorProfile? {
        switch profiles {
        case .single(let p): return p
        case .array(let a): return a.first
        case .none: return nil
        }
    }
}

struct HangerActivityPostInfo: Codable {
    let id: UUID
    let title: String
}

enum HangerTopicInfoOrArray: Codable {
    case single(HangerTopicInfo?)
    case array([HangerTopicInfo])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([HangerTopicInfo].self) {
            self = .array(array)
        } else if let single = try? container.decode(HangerTopicInfo.self) {
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
