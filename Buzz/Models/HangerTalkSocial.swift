//
//  HangerTalkSocial.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/8/26.
//

import Foundation

// MARK: - Feed Tab

enum HangerTalkFeedTab: String, CaseIterable {
    case forYou = "For You"
    case following = "Following"
    case liked = "Liked"
    case bookmarks = "Bookmarks"
}

// MARK: - Hanger Talk Post (Social Feed Post)

struct HangerTalkPost: Codable, Identifiable {
    let id: UUID
    let authorId: UUID
    let body: String
    let imageUrls: [String]
    let likeCount: Int
    let replyCount: Int
    let repostCount: Int
    let isReply: Bool
    let parentPostId: UUID?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case body
        case imageUrls = "image_urls"
        case likeCount = "like_count"
        case replyCount = "reply_count"
        case repostCount = "repost_count"
        case isReply = "is_reply"
        case parentPostId = "parent_post_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        authorId = try container.decode(UUID.self, forKey: .authorId)
        body = try container.decode(String.self, forKey: .body)
        imageUrls = try container.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        likeCount = try container.decode(Int.self, forKey: .likeCount)
        replyCount = try container.decode(Int.self, forKey: .replyCount)
        repostCount = try container.decode(Int.self, forKey: .repostCount)
        isReply = try container.decode(Bool.self, forKey: .isReply)
        parentPostId = try container.decodeIfPresent(UUID.self, forKey: .parentPostId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    init(id: UUID, authorId: UUID, body: String, imageUrls: [String] = [],
         likeCount: Int, replyCount: Int, repostCount: Int,
         isReply: Bool, parentPostId: UUID?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.authorId = authorId
        self.body = body
        self.imageUrls = imageUrls
        self.likeCount = likeCount
        self.replyCount = replyCount
        self.repostCount = repostCount
        self.isReply = isReply
        self.parentPostId = parentPostId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Hanger Talk Post Insert

struct HangerTalkPostInsert: Codable {
    let authorId: UUID
    let body: String
    let imageUrls: [String]
    let isReply: Bool
    let parentPostId: UUID?

    enum CodingKeys: String, CodingKey {
        case authorId = "author_id"
        case body
        case imageUrls = "image_urls"
        case isReply = "is_reply"
        case parentPostId = "parent_post_id"
    }
}

// MARK: - Hanger Talk Post with Author (for display)

struct HangerTalkPostWithAuthor: Identifiable {
    let id: UUID
    let post: HangerTalkPost
    let authorCallSign: String?
    let authorProfilePictureUrl: String?
    let authorFullName: String
    var isLikedByCurrentUser: Bool
    var isRepostedByCurrentUser: Bool
    var isBookmarkedByCurrentUser: Bool
    var isFollowedByCurrentUser: Bool
}

// MARK: - Supabase Join Response

struct HangerTalkPostResponse: Codable {
    let id: UUID
    let authorId: UUID
    let body: String
    let imageUrls: [String]
    let likeCount: Int
    let replyCount: Int
    let repostCount: Int
    let isReply: Bool
    let parentPostId: UUID?
    let createdAt: Date
    let updatedAt: Date
    let profiles: HangerAuthorProfileOrArray?

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case body
        case imageUrls = "image_urls"
        case likeCount = "like_count"
        case replyCount = "reply_count"
        case repostCount = "repost_count"
        case isReply = "is_reply"
        case parentPostId = "parent_post_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case profiles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        authorId = try container.decode(UUID.self, forKey: .authorId)
        body = try container.decode(String.self, forKey: .body)
        imageUrls = try container.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        likeCount = try container.decode(Int.self, forKey: .likeCount)
        replyCount = try container.decode(Int.self, forKey: .replyCount)
        repostCount = try container.decode(Int.self, forKey: .repostCount)
        isReply = try container.decode(Bool.self, forKey: .isReply)
        parentPostId = try container.decodeIfPresent(UUID.self, forKey: .parentPostId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        profiles = try container.decodeIfPresent(HangerAuthorProfileOrArray.self, forKey: .profiles)
    }

    var profileData: HangerAuthorProfile? {
        switch profiles {
        case .single(let profile): return profile
        case .array(let profiles): return profiles.first
        case .none: return nil
        }
    }

    func toHangerTalkPost() -> HangerTalkPost {
        HangerTalkPost(
            id: id,
            authorId: authorId,
            body: body,
            imageUrls: imageUrls,
            likeCount: likeCount,
            replyCount: replyCount,
            repostCount: repostCount,
            isReply: isReply,
            parentPostId: parentPostId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Hanger Talk Like

struct HangerTalkLike: Codable, Identifiable {
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

// MARK: - Hanger Talk Repost

struct HangerTalkRepost: Codable, Identifiable {
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

// MARK: - Hanger Talk Bookmark

struct HangerTalkBookmark: Codable, Identifiable {
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

// MARK: - User Follow

struct UserFollow: Codable, Identifiable {
    let id: UUID
    let followerId: UUID
    let followingId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followingId = "following_id"
        case createdAt = "created_at"
    }
}

// MARK: - Hanger Talk Mention

struct HangerTalkMention: Codable, Identifiable {
    let id: UUID
    let postId: UUID
    let mentionedUserId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case mentionedUserId = "mentioned_user_id"
        case createdAt = "created_at"
    }
}

struct HangerTalkMentionInsert: Codable {
    let postId: UUID
    let mentionedUserId: UUID

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case mentionedUserId = "mentioned_user_id"
    }
}
