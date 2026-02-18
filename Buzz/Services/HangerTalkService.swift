//
//  HangerTalkService.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/8/26.
//

import Foundation
import Combine
import Supabase
import UIKit

@MainActor
class HangerTalkService: ObservableObject {
    @Published var feedPosts: [HangerTalkPostWithAuthor] = []
    @Published var followingPosts: [HangerTalkPostWithAuthor] = []
    @Published var likedPosts: [HangerTalkPostWithAuthor] = []
    @Published var bookmarkedPosts: [HangerTalkPostWithAuthor] = []
    @Published var replies: [HangerTalkPostWithAuthor] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var inboxItems: [HangerTalkNotificationItem] = []
    @Published var unreadCount: Int = 0
    @Published var unreadCounts: [HangerTalkNotificationType: Int] = [:]

    private let supabase = SupabaseClient.shared.client

    private func sanitizeSearchPattern(_ query: String) -> String {
        query.replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_")
    }

    // MARK: - Fetch Feed (For You - all non-reply posts, newest first)

    func fetchFeed(currentUserId: UUID) async {
        isLoading = true
        errorMessage = nil

        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 300_000_000)
            feedPosts = Self.demoPosts
            isLoading = false
            return
        }

        do {
            let response: [HangerTalkPostResponse] = try await supabase
                .from("hanger_talk_posts")
                .select("*, profiles(id, call_sign, profile_picture_url, first_name, last_name)")
                .eq("is_reply", value: false)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            let postIds = response.map { $0.id }
            let interactions = await fetchUserInteractions(currentUserId: currentUserId, postIds: postIds)

            feedPosts = response.map { resp in
                mapResponseToPostWithAuthor(resp, interactions: interactions)
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Fetch Liked Posts

    func fetchLikedPosts(currentUserId: UUID) async {
        if DemoModeManager.shared.isDemoModeEnabled {
            likedPosts = []
            return
        }

        do {
            let userLikes: [HangerTalkLike] = try await supabase
                .from("hanger_talk_likes")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            let likedPostIds = userLikes.map { $0.postId }
            guard !likedPostIds.isEmpty else {
                likedPosts = []
                return
            }

            let response: [HangerTalkPostResponse] = try await supabase
                .from("hanger_talk_posts")
                .select("*, profiles(id, call_sign, profile_picture_url, first_name, last_name)")
                .in("id", values: likedPostIds.map { $0.uuidString })
                .execute()
                .value

            let interactions = await fetchUserInteractions(currentUserId: currentUserId, postIds: likedPostIds)

            let mappedPosts = response.map { resp in
                mapResponseToPostWithAuthor(resp, interactions: interactions)
            }

            // Maintain liked order
            likedPosts = likedPostIds.compactMap { postId in
                mappedPosts.first { $0.id == postId }
            }
        } catch {
            print("Error fetching liked posts: \(error)")
        }
    }

    // MARK: - Fetch Bookmarked Posts

    func fetchBookmarkedPosts(currentUserId: UUID) async {
        if DemoModeManager.shared.isDemoModeEnabled {
            bookmarkedPosts = []
            return
        }

        do {
            let userBookmarks: [HangerTalkBookmark] = try await supabase
                .from("hanger_talk_bookmarks")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            let bookmarkedPostIds = userBookmarks.map { $0.postId }
            guard !bookmarkedPostIds.isEmpty else {
                bookmarkedPosts = []
                return
            }

            let response: [HangerTalkPostResponse] = try await supabase
                .from("hanger_talk_posts")
                .select("*, profiles(id, call_sign, profile_picture_url, first_name, last_name)")
                .in("id", values: bookmarkedPostIds.map { $0.uuidString })
                .execute()
                .value

            let interactions = await fetchUserInteractions(currentUserId: currentUserId, postIds: bookmarkedPostIds)

            let mappedPosts = response.map { resp in
                mapResponseToPostWithAuthor(resp, interactions: interactions)
            }

            // Maintain bookmarked order
            bookmarkedPosts = bookmarkedPostIds.compactMap { postId in
                mappedPosts.first { $0.id == postId }
            }
        } catch {
            print("Error fetching bookmarked posts: \(error)")
        }
    }

    // MARK: - Fetch Replies for Post

    func fetchReplies(parentPostId: UUID, currentUserId: UUID) async {
        isLoading = true
        errorMessage = nil

        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 300_000_000)
            replies = []
            isLoading = false
            return
        }

        do {
            let response: [HangerTalkPostResponse] = try await supabase
                .from("hanger_talk_posts")
                .select("*, profiles(id, call_sign, profile_picture_url, first_name, last_name)")
                .eq("parent_post_id", value: parentPostId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value

            let postIds = response.map { $0.id }
            let interactions = await fetchUserInteractions(currentUserId: currentUserId, postIds: postIds)

            replies = response.map { resp in
                mapResponseToPostWithAuthor(resp, interactions: interactions)
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Create Post

    @discardableResult
    func createPost(authorId: UUID, body: String, imageUrls: [String] = []) async throws -> UUID {
        if DemoModeManager.shared.isDemoModeEnabled { return UUID() }

        let insert = HangerTalkPostInsert(
            authorId: authorId,
            body: body,
            imageUrls: imageUrls,
            isReply: false,
            parentPostId: nil
        )

        let response: [HangerTalkPost] = try await supabase
            .from("hanger_talk_posts")
            .insert(insert)
            .select()
            .execute()
            .value

        guard let post = response.first else {
            throw NSError(domain: "HangerTalkService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create post"])
        }

        // Notify followers about the new post (remote push to each follower's device)
        if let authorCallSign = await fetchCallSign(userId: authorId) {
            let followers: [UserFollow] = (try? await supabase
                .from("user_follows")
                .select()
                .eq("following_id", value: authorId.uuidString)
                .execute()
                .value) ?? []

            for follower in followers {
                await NotificationManager.shared.notifyHangerTalkNewPost(
                    postId: post.id,
                    followerUserId: follower.followerId,
                    authorCallSign: authorCallSign
                )
                await insertNotification(
                    recipientId: follower.followerId,
                    actorId: authorId,
                    type: .newPost,
                    postId: post.id
                )
            }
        }

        return post.id
    }

    // MARK: - Create Reply

    @discardableResult
    func createReply(authorId: UUID, parentPostId: UUID, body: String, imageUrls: [String] = []) async throws -> UUID {
        if DemoModeManager.shared.isDemoModeEnabled { return UUID() }

        let insert = HangerTalkPostInsert(
            authorId: authorId,
            body: body,
            imageUrls: imageUrls,
            isReply: true,
            parentPostId: parentPostId
        )

        let response: [HangerTalkPost] = try await supabase
            .from("hanger_talk_posts")
            .insert(insert)
            .select()
            .execute()
            .value

        guard let post = response.first else {
            throw NSError(domain: "HangerTalkService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create reply"])
        }

        // Notify parent post author about the reply (remote push to author's device)
        if let parentAuthorId = await fetchPostAuthorId(postId: parentPostId),
           parentAuthorId != authorId,
           let replierCallSign = await fetchCallSign(userId: authorId) {
            await NotificationManager.shared.notifyHangerTalkReply(
                postId: post.id,
                parentPostId: parentPostId,
                parentAuthorId: parentAuthorId,
                replierCallSign: replierCallSign
            )
            await insertNotification(
                recipientId: parentAuthorId,
                actorId: authorId,
                type: .reply,
                postId: post.id
            )
        }

        return post.id
    }

    // MARK: - Update Post

    func updatePost(postId: UUID, body: String, imageUrls: [String]) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        let update: [String: AnyJSON] = [
            "body": .string(body),
            "image_urls": .array(imageUrls.map { .string($0) })
        ]

        try await supabase
            .from("hanger_talk_posts")
            .update(update)
            .eq("id", value: postId.uuidString)
            .execute()
    }

    // MARK: - Search Posts

    func searchPosts(query: String, currentUserId: UUID) async -> [HangerTalkPostWithAuthor] {
        if DemoModeManager.shared.isDemoModeEnabled { return [] }

        do {
            let response: [HangerTalkPostResponse] = try await supabase
                .from("hanger_talk_posts")
                .select("*, profiles(id, call_sign, profile_picture_url, first_name, last_name)")
                .eq("is_reply", value: false)
                .ilike("body", pattern: "%\(sanitizeSearchPattern(query))%")
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            let postIds = response.map { $0.id }
            let interactions = await fetchUserInteractions(currentUserId: currentUserId, postIds: postIds)

            return response.map { resp in
                mapResponseToPostWithAuthor(resp, interactions: interactions)
            }
        } catch {
            print("Error searching posts: \(error)")
            return []
        }
    }

    // MARK: - Search Pilots

    func searchPilots(query: String) async -> [HangerAuthorProfile] {
        if DemoModeManager.shared.isDemoModeEnabled { return [] }

        do {
            let profiles: [HangerAuthorProfile] = try await supabase
                .from("profiles")
                .select("id, call_sign, profile_picture_url, first_name, last_name")
                .eq("user_type", value: "pilot")
                .or("call_sign.ilike.%\(sanitizeSearchPattern(query))%,first_name.ilike.%\(sanitizeSearchPattern(query))%,last_name.ilike.%\(sanitizeSearchPattern(query))%")
                .limit(20)
                .execute()
                .value

            return profiles
        } catch {
            print("Error searching pilots: \(error)")
            return []
        }
    }

    // MARK: - Delete Post

    func deletePost(postId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        try await supabase
            .from("hanger_talk_posts")
            .delete()
            .eq("id", value: postId.uuidString)
            .execute()
    }

    // MARK: - Toggle Like

    func toggleLike(postId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled {
            let isCurrentlyLiked = currentLikeState(postId: postId)
            applyInteractionUpdate(
                postId: postId,
                likeDelta: isCurrentlyLiked ? -1 : 1,
                isLikedByCurrentUser: !isCurrentlyLiked
            )
            return
        }

        let isCurrentlyLiked = currentLikeState(postId: postId)

        // Optimistic UI update
        applyInteractionUpdate(
            postId: postId,
            likeDelta: isCurrentlyLiked ? -1 : 1,
            isLikedByCurrentUser: !isCurrentlyLiked
        )

        do {
            let existing: [HangerTalkLike] = try await supabase
                .from("hanger_talk_likes")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("post_id", value: postId.uuidString)
                .execute()
                .value

            if let like = existing.first {
                try await supabase
                    .from("hanger_talk_likes")
                    .delete()
                    .eq("id", value: like.id.uuidString)
                    .execute()
            } else {
                let data: [String: AnyJSON] = [
                    "user_id": .string(userId.uuidString),
                    "post_id": .string(postId.uuidString)
                ]
                try await supabase
                    .from("hanger_talk_likes")
                    .insert(data)
                    .execute()

                // Notify post author about the like (remote push to author's device)
                if let postAuthorId = await fetchPostAuthorId(postId: postId),
                   postAuthorId != userId,
                   let likerCallSign = await fetchCallSign(userId: userId) {
                    await NotificationManager.shared.notifyHangerTalkLike(
                        postId: postId,
                        postAuthorId: postAuthorId,
                        likerCallSign: likerCallSign
                    )
                    await insertNotification(
                        recipientId: postAuthorId,
                        actorId: userId,
                        type: .like,
                        postId: postId
                    )
                }
            }
        } catch {
            // Revert optimistic update on failure
            applyInteractionUpdate(
                postId: postId,
                likeDelta: isCurrentlyLiked ? 1 : -1,
                isLikedByCurrentUser: isCurrentlyLiked
            )
            throw error
        }
    }

    // MARK: - Toggle Repost

    func toggleRepost(postId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled {
            let isCurrentlyReposted = currentRepostState(postId: postId)
            applyInteractionUpdate(
                postId: postId,
                repostDelta: isCurrentlyReposted ? -1 : 1,
                isRepostedByCurrentUser: !isCurrentlyReposted
            )
            return
        }

        let isCurrentlyReposted = currentRepostState(postId: postId)

        // Optimistic UI update
        applyInteractionUpdate(
            postId: postId,
            repostDelta: isCurrentlyReposted ? -1 : 1,
            isRepostedByCurrentUser: !isCurrentlyReposted
        )

        do {
            let existing: [HangerTalkRepost] = try await supabase
                .from("hanger_talk_reposts")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("post_id", value: postId.uuidString)
                .execute()
                .value

            if let repost = existing.first {
                try await supabase
                    .from("hanger_talk_reposts")
                    .delete()
                    .eq("id", value: repost.id.uuidString)
                    .execute()
            } else {
                let data: [String: AnyJSON] = [
                    "user_id": .string(userId.uuidString),
                    "post_id": .string(postId.uuidString)
                ]
                try await supabase
                    .from("hanger_talk_reposts")
                    .insert(data)
                    .execute()
            }
        } catch {
            // Revert optimistic update on failure
            applyInteractionUpdate(
                postId: postId,
                repostDelta: isCurrentlyReposted ? 1 : -1,
                isRepostedByCurrentUser: isCurrentlyReposted
            )
            throw error
        }
    }

    // MARK: - Toggle Bookmark

    func toggleBookmark(postId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled {
            let isCurrentlyBookmarked = currentBookmarkState(postId: postId)
            applyInteractionUpdate(
                postId: postId,
                isBookmarkedByCurrentUser: !isCurrentlyBookmarked
            )
            return
        }

        let isCurrentlyBookmarked = currentBookmarkState(postId: postId)

        // Optimistic UI update
        applyInteractionUpdate(
            postId: postId,
            isBookmarkedByCurrentUser: !isCurrentlyBookmarked
        )

        do {
            let existing: [HangerTalkBookmark] = try await supabase
                .from("hanger_talk_bookmarks")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("post_id", value: postId.uuidString)
                .execute()
                .value

            if let bookmark = existing.first {
                try await supabase
                    .from("hanger_talk_bookmarks")
                    .delete()
                    .eq("id", value: bookmark.id.uuidString)
                    .execute()
            } else {
                let data: [String: AnyJSON] = [
                    "user_id": .string(userId.uuidString),
                    "post_id": .string(postId.uuidString)
                ]
                try await supabase
                    .from("hanger_talk_bookmarks")
                    .insert(data)
                    .execute()
            }
        } catch {
            // Revert optimistic update on failure
            applyInteractionUpdate(
                postId: postId,
                isBookmarkedByCurrentUser: isCurrentlyBookmarked
            )
            throw error
        }
    }

    // MARK: - Fetch Following Feed

    func fetchFollowingFeed(currentUserId: UUID) async {
        isLoading = true
        errorMessage = nil

        if DemoModeManager.shared.isDemoModeEnabled {
            followingPosts = []
            isLoading = false
            return
        }

        do {
            // Get IDs of users the current user follows
            let follows: [UserFollow] = try await supabase
                .from("user_follows")
                .select()
                .eq("follower_id", value: currentUserId.uuidString)
                .execute()
                .value

            let followedIds = follows.map { $0.followingId.uuidString }

            guard !followedIds.isEmpty else {
                followingPosts = []
                isLoading = false
                return
            }

            // Fetch posts from followed users
            let response: [HangerTalkPostResponse] = try await supabase
                .from("hanger_talk_posts")
                .select("*, profiles(id, call_sign, profile_picture_url, first_name, last_name)")
                .eq("is_reply", value: false)
                .in("author_id", values: followedIds)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            let postIds = response.map { $0.id }
            let interactions = await fetchUserInteractions(currentUserId: currentUserId, postIds: postIds)

            followingPosts = response.map { resp in
                mapResponseToPostWithAuthor(resp, interactions: interactions)
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Toggle Follow

    func toggleFollow(followerId: UUID, followingId: UUID) async throws -> Bool {
        if DemoModeManager.shared.isDemoModeEnabled { return false }

        let existing: [UserFollow] = try await supabase
            .from("user_follows")
            .select()
            .eq("follower_id", value: followerId.uuidString)
            .eq("following_id", value: followingId.uuidString)
            .execute()
            .value

        if let follow = existing.first {
            try await supabase
                .from("user_follows")
                .delete()
                .eq("id", value: follow.id.uuidString)
                .execute()
            updateFollowState(authorId: followingId, isFollowed: false)
            return false // now unfollowed
        } else {
            let data: [String: AnyJSON] = [
                "follower_id": .string(followerId.uuidString),
                "following_id": .string(followingId.uuidString)
            ]
            try await supabase
                .from("user_follows")
                .insert(data)
                .execute()
            updateFollowState(authorId: followingId, isFollowed: true)

            // Notify the user being followed (remote push to followed user's device)
            if let followerCallSign = await fetchCallSign(userId: followerId) {
                await NotificationManager.shared.notifyHangerTalkFollow(
                    followerCallSign: followerCallSign,
                    followedUserId: followingId
                )
                await insertNotification(
                    recipientId: followingId,
                    actorId: followerId,
                    type: .follow,
                    postId: nil
                )
            }

            return true // now following
        }
    }

    private func updateFollowState(authorId: UUID, isFollowed: Bool) {
        for i in feedPosts.indices where feedPosts[i].post.authorId == authorId {
            feedPosts[i].isFollowedByCurrentUser = isFollowed
        }
        for i in followingPosts.indices where followingPosts[i].post.authorId == authorId {
            followingPosts[i].isFollowedByCurrentUser = isFollowed
        }
        for i in likedPosts.indices where likedPosts[i].post.authorId == authorId {
            likedPosts[i].isFollowedByCurrentUser = isFollowed
        }
        for i in bookmarkedPosts.indices where bookmarkedPosts[i].post.authorId == authorId {
            bookmarkedPosts[i].isFollowedByCurrentUser = isFollowed
        }
        for i in replies.indices where replies[i].post.authorId == authorId {
            replies[i].isFollowedByCurrentUser = isFollowed
        }
    }

    private func currentLikeState(postId: UUID) -> Bool {
        postForStateLookup(postId: postId)?.isLikedByCurrentUser ?? false
    }

    private func currentRepostState(postId: UUID) -> Bool {
        postForStateLookup(postId: postId)?.isRepostedByCurrentUser ?? false
    }

    private func currentBookmarkState(postId: UUID) -> Bool {
        postForStateLookup(postId: postId)?.isBookmarkedByCurrentUser ?? false
    }

    private func postForStateLookup(postId: UUID) -> HangerTalkPostWithAuthor? {
        feedPosts.first(where: { $0.id == postId })
            ?? followingPosts.first(where: { $0.id == postId })
            ?? likedPosts.first(where: { $0.id == postId })
            ?? bookmarkedPosts.first(where: { $0.id == postId })
            ?? replies.first(where: { $0.id == postId })
    }

    private func applyInteractionUpdate(
        postId: UUID,
        likeDelta: Int = 0,
        repostDelta: Int = 0,
        isLikedByCurrentUser: Bool? = nil,
        isRepostedByCurrentUser: Bool? = nil,
        isBookmarkedByCurrentUser: Bool? = nil
    ) {
        updateInteractionState(
            in: &feedPosts,
            postId: postId,
            likeDelta: likeDelta,
            repostDelta: repostDelta,
            isLikedByCurrentUser: isLikedByCurrentUser,
            isRepostedByCurrentUser: isRepostedByCurrentUser,
            isBookmarkedByCurrentUser: isBookmarkedByCurrentUser
        )
        updateInteractionState(
            in: &followingPosts,
            postId: postId,
            likeDelta: likeDelta,
            repostDelta: repostDelta,
            isLikedByCurrentUser: isLikedByCurrentUser,
            isRepostedByCurrentUser: isRepostedByCurrentUser,
            isBookmarkedByCurrentUser: isBookmarkedByCurrentUser
        )
        updateInteractionState(
            in: &likedPosts,
            postId: postId,
            likeDelta: likeDelta,
            repostDelta: repostDelta,
            isLikedByCurrentUser: isLikedByCurrentUser,
            isRepostedByCurrentUser: isRepostedByCurrentUser,
            isBookmarkedByCurrentUser: isBookmarkedByCurrentUser
        )
        updateInteractionState(
            in: &bookmarkedPosts,
            postId: postId,
            likeDelta: likeDelta,
            repostDelta: repostDelta,
            isLikedByCurrentUser: isLikedByCurrentUser,
            isRepostedByCurrentUser: isRepostedByCurrentUser,
            isBookmarkedByCurrentUser: isBookmarkedByCurrentUser
        )
        updateInteractionState(
            in: &replies,
            postId: postId,
            likeDelta: likeDelta,
            repostDelta: repostDelta,
            isLikedByCurrentUser: isLikedByCurrentUser,
            isRepostedByCurrentUser: isRepostedByCurrentUser,
            isBookmarkedByCurrentUser: isBookmarkedByCurrentUser
        )
    }

    private func updateInteractionState(
        in posts: inout [HangerTalkPostWithAuthor],
        postId: UUID,
        likeDelta: Int,
        repostDelta: Int,
        isLikedByCurrentUser: Bool?,
        isRepostedByCurrentUser: Bool?,
        isBookmarkedByCurrentUser: Bool?
    ) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }

        let existing = posts[index]
        let post = existing.post
        let updatedPost = HangerTalkPost(
            id: post.id,
            authorId: post.authorId,
            body: post.body,
            imageUrls: post.imageUrls,
            likeCount: max(0, post.likeCount + likeDelta),
            replyCount: post.replyCount,
            repostCount: max(0, post.repostCount + repostDelta),
            isReply: post.isReply,
            parentPostId: post.parentPostId,
            createdAt: post.createdAt,
            updatedAt: post.updatedAt
        )

        posts[index] = HangerTalkPostWithAuthor(
            id: existing.id,
            post: updatedPost,
            authorCallSign: existing.authorCallSign,
            authorProfilePictureUrl: existing.authorProfilePictureUrl,
            authorFullName: existing.authorFullName,
            isLikedByCurrentUser: isLikedByCurrentUser ?? existing.isLikedByCurrentUser,
            isRepostedByCurrentUser: isRepostedByCurrentUser ?? existing.isRepostedByCurrentUser,
            isBookmarkedByCurrentUser: isBookmarkedByCurrentUser ?? existing.isBookmarkedByCurrentUser,
            isFollowedByCurrentUser: existing.isFollowedByCurrentUser
        )
    }

    // MARK: - Check if Following

    func isFollowing(followerId: UUID, followingId: UUID) async -> Bool {
        if DemoModeManager.shared.isDemoModeEnabled { return false }

        do {
            let existing: [UserFollow] = try await supabase
                .from("user_follows")
                .select()
                .eq("follower_id", value: followerId.uuidString)
                .eq("following_id", value: followingId.uuidString)
                .execute()
                .value
            return !existing.isEmpty
        } catch {
            print("Error checking follow status: \(error)")
            return false
        }
    }

    // MARK: - Fetch Follow Counts

    func fetchFollowCounts(userId: UUID) async -> (followers: Int, following: Int) {
        if DemoModeManager.shared.isDemoModeEnabled { return (0, 0) }

        do {
            let followers: [UserFollow] = try await supabase
                .from("user_follows")
                .select()
                .eq("following_id", value: userId.uuidString)
                .execute()
                .value

            let following: [UserFollow] = try await supabase
                .from("user_follows")
                .select()
                .eq("follower_id", value: userId.uuidString)
                .execute()
                .value

            return (followers.count, following.count)
        } catch {
            print("Error fetching follow counts: \(error)")
            return (0, 0)
        }
    }

    // MARK: - Fetch Followed Pilot IDs

    func fetchFollowedIds(userId: UUID) async -> Set<UUID> {
        if DemoModeManager.shared.isDemoModeEnabled { return [] }

        do {
            let follows: [UserFollow] = try await supabase
                .from("user_follows")
                .select()
                .eq("follower_id", value: userId.uuidString)
                .execute()
                .value
            return Set(follows.map { $0.followingId })
        } catch {
            print("Error fetching followed IDs: \(error)")
            return []
        }
    }

    // MARK: - Search Pilots for Mention Autocomplete

    func searchPilotsForMention(query: String) async -> [HangerAuthorProfile] {
        if DemoModeManager.shared.isDemoModeEnabled { return [] }

        do {
            let profiles: [HangerAuthorProfile] = try await supabase
                .from("profiles")
                .select("id, call_sign, profile_picture_url, first_name, last_name")
                .ilike("call_sign", pattern: "%\(sanitizeSearchPattern(query))%")
                .limit(8)
                .execute()
                .value
            return profiles
        } catch {
            print("Error searching pilots for mention: \(error)")
            return []
        }
    }

    // MARK: - Create Mentions for Post

    func createMentions(postId: UUID, authorId: UUID, mentionedCallSigns: [String]) async {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        for callSign in mentionedCallSigns {
            do {
                let profiles: [HangerAuthorProfile] = try await supabase
                    .from("profiles")
                    .select("id, call_sign, profile_picture_url, first_name, last_name")
                    .ilike("call_sign", pattern: callSign)
                    .limit(1)
                    .execute()
                    .value

                guard let profile = profiles.first else { continue }

                let insert = HangerTalkMentionInsert(
                    postId: postId,
                    mentionedUserId: profile.id
                )
                try await supabase
                    .from("hanger_talk_mentions")
                    .insert(insert)
                    .execute()

                // Notify the mentioned user (remote push to mentioned user's device)
                if profile.id != authorId {
                    let mentionerCallSign = await fetchCallSign(userId: authorId)
                    await NotificationManager.shared.notifyHangerTalkMention(
                        postId: postId,
                        mentionedUserId: profile.id,
                        mentionerCallSign: mentionerCallSign ?? "Someone"
                    )
                    await insertNotification(
                        recipientId: profile.id,
                        actorId: authorId,
                        type: .mention,
                        postId: postId
                    )
                }
            } catch {
                print("Error creating mention for @\(callSign): \(error)")
            }
        }
    }

    // MARK: - Resolve Call Sign to Profile

    func resolveCallSign(_ callSign: String) async -> HangerAuthorProfile? {
        if DemoModeManager.shared.isDemoModeEnabled { return nil }

        do {
            let profiles: [HangerAuthorProfile] = try await supabase
                .from("profiles")
                .select("id, call_sign, profile_picture_url, first_name, last_name")
                .ilike("call_sign", pattern: callSign)
                .limit(1)
                .execute()
                .value
            return profiles.first
        } catch {
            return nil
        }
    }

    // MARK: - Upload Images

    func uploadPostImages(userId: UUID, images: [UIImage]) async throws -> [String] {
        if DemoModeManager.shared.isDemoModeEnabled { return [] }

        var urls: [String] = []

        for image in images.prefix(4) {
            guard let imageData = compressPostImage(image) else { continue }

            let fileName = "\(userId.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"

            let _ = try await supabase.storage
                .from("hanger_talk_images")
                .upload(
                    fileName,
                    data: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )

            let publicURL = try supabase.storage
                .from("hanger_talk_images")
                .getPublicURL(path: fileName)

            urls.append(publicURL.absoluteString)
        }

        return urls
    }

    private func compressPostImage(_ image: UIImage) -> Data? {
        let maxSize: CGFloat = 1200
        let size = image.size

        var newSize: CGSize
        if size.width > maxSize || size.height > maxSize {
            if size.width > size.height {
                newSize = CGSize(width: maxSize, height: (size.height / size.width) * maxSize)
            } else {
                newSize = CGSize(width: (size.width / size.height) * maxSize, height: maxSize)
            }
        } else {
            newSize = size
        }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resizedImage.jpegData(compressionQuality: 0.8)
    }

    // MARK: - Helpers

    private func fetchUserInteractions(currentUserId: UUID, postIds: [UUID]) async -> (likes: Set<UUID>, reposts: Set<UUID>, bookmarks: Set<UUID>, followedAuthorIds: Set<UUID>) {
        guard !postIds.isEmpty else { return ([], [], [], []) }

        do {
            let postIdStrings = postIds.map { $0.uuidString }

            let userLikes: [HangerTalkLike] = try await supabase
                .from("hanger_talk_likes")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .in("post_id", values: postIdStrings)
                .execute()
                .value
            let likedIds = Set(userLikes.map { $0.postId })

            let userReposts: [HangerTalkRepost] = try await supabase
                .from("hanger_talk_reposts")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .in("post_id", values: postIdStrings)
                .execute()
                .value
            let repostedIds = Set(userReposts.map { $0.postId })

            let userBookmarks: [HangerTalkBookmark] = try await supabase
                .from("hanger_talk_bookmarks")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .in("post_id", values: postIdStrings)
                .execute()
                .value
            let bookmarkedIds = Set(userBookmarks.map { $0.postId })

            let followedIds = await fetchFollowedIds(userId: currentUserId)

            return (likedIds, repostedIds, bookmarkedIds, followedIds)
        } catch {
            print("Error fetching user interactions: \(error)")
            return ([], [], [], [])
        }
    }

    private func mapResponseToPostWithAuthor(_ resp: HangerTalkPostResponse, interactions: (likes: Set<UUID>, reposts: Set<UUID>, bookmarks: Set<UUID>, followedAuthorIds: Set<UUID>)) -> HangerTalkPostWithAuthor {
        let profile = resp.profileData
        return HangerTalkPostWithAuthor(
            id: resp.id,
            post: resp.toHangerTalkPost(),
            authorCallSign: profile?.callSign,
            authorProfilePictureUrl: profile?.profilePictureUrl,
            authorFullName: profile?.fullName ?? "Pilot",
            isLikedByCurrentUser: interactions.likes.contains(resp.id),
            isRepostedByCurrentUser: interactions.reposts.contains(resp.id),
            isBookmarkedByCurrentUser: interactions.bookmarks.contains(resp.id),
            isFollowedByCurrentUser: interactions.followedAuthorIds.contains(resp.authorId)
        )
    }

    // MARK: - Fetch User Posts (by author)

    func fetchUserPosts(authorId: UUID, currentUserId: UUID) async -> [HangerTalkPostWithAuthor] {
        if DemoModeManager.shared.isDemoModeEnabled {
            return []
        }

        do {
            let response: [HangerTalkPostResponse] = try await supabase
                .from("hanger_talk_posts")
                .select("*, profiles(id, call_sign, profile_picture_url, first_name, last_name)")
                .eq("author_id", value: authorId.uuidString)
                .eq("is_reply", value: false)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value

            let postIds = response.map { $0.id }
            let interactions = await fetchUserInteractions(currentUserId: currentUserId, postIds: postIds)

            return response.map { resp in
                mapResponseToPostWithAuthor(resp, interactions: interactions)
            }
        } catch {
            print("Error fetching user posts: \(error)")
            return []
        }
    }

    // MARK: - Notification Helpers

    /// Fetch the author ID of a post
    private func fetchPostAuthorId(postId: UUID) async -> UUID? {
        do {
            let posts: [HangerTalkPost] = try await supabase
                .from("hanger_talk_posts")
                .select()
                .eq("id", value: postId.uuidString)
                .limit(1)
                .execute()
                .value
            return posts.first?.authorId
        } catch {
            print("Error fetching post author: \(error)")
            return nil
        }
    }

    /// Fetch the call sign for a given user ID
    private func fetchCallSign(userId: UUID) async -> String? {
        do {
            let profiles: [HangerAuthorProfile] = try await supabase
                .from("profiles")
                .select("id, call_sign, profile_picture_url, first_name, last_name")
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            return profiles.first?.callSign
        } catch {
            print("Error fetching call sign: \(error)")
            return nil
        }
    }

    // MARK: - Inbox / Notifications

    func fetchInbox(userId: UUID) async {
        if DemoModeManager.shared.isDemoModeEnabled {
            inboxItems = []
            return
        }

        do {
            let response: [HangerTalkNotificationResponse] = try await supabase
                .from("hanger_talk_notifications")
                .select("*, profiles!hanger_talk_notifications_actor_id_fkey(id, call_sign, profile_picture_url, first_name, last_name)")
                .eq("recipient_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            inboxItems = response.map { resp in
                let profile = resp.profileData
                return HangerTalkNotificationItem(
                    id: resp.id,
                    type: resp.type,
                    actorId: resp.actorId,
                    actorCallSign: profile?.callSign,
                    actorProfilePictureUrl: profile?.profilePictureUrl,
                    actorFullName: profile?.fullName ?? "Pilot",
                    postId: resp.postId,
                    isRead: resp.isRead,
                    createdAt: resp.createdAt
                )
            }

            // Compute per-category unread counts
            updateUnreadCounts()
        } catch {
            print("Error fetching inbox: \(error)")
        }
    }

    func itemsForCategory(_ type: HangerTalkNotificationType) -> [HangerTalkNotificationItem] {
        inboxItems.filter { $0.type == type }
    }

    private func updateUnreadCounts() {
        var counts: [HangerTalkNotificationType: Int] = [:]
        for item in inboxItems where !item.isRead {
            counts[item.type, default: 0] += 1
        }
        unreadCounts = counts
        unreadCount = inboxItems.filter { !$0.isRead }.count
    }

    func fetchUnreadCount(userId: UUID) async {
        if DemoModeManager.shared.isDemoModeEnabled {
            unreadCount = 0
            return
        }

        do {
            struct IdOnly: Decodable { let id: UUID }
            let response: [IdOnly] = try await supabase
                .from("hanger_talk_notifications")
                .select("id")
                .eq("recipient_id", value: userId.uuidString)
                .eq("is_read", value: false)
                .execute()
                .value

            unreadCount = response.count
        } catch {
            print("Error fetching unread count: \(error)")
        }
    }

    func markAllAsRead(userId: UUID) async {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        do {
            let update: [String: AnyJSON] = ["is_read": .bool(true)]
            try await supabase
                .from("hanger_talk_notifications")
                .update(update)
                .eq("recipient_id", value: userId.uuidString)
                .eq("is_read", value: false)
                .execute()

            unreadCount = 0
            unreadCounts = [:]
            for i in inboxItems.indices {
                inboxItems[i] = HangerTalkNotificationItem(
                    id: inboxItems[i].id,
                    type: inboxItems[i].type,
                    actorId: inboxItems[i].actorId,
                    actorCallSign: inboxItems[i].actorCallSign,
                    actorProfilePictureUrl: inboxItems[i].actorProfilePictureUrl,
                    actorFullName: inboxItems[i].actorFullName,
                    postId: inboxItems[i].postId,
                    isRead: true,
                    createdAt: inboxItems[i].createdAt
                )
            }
        } catch {
            print("Error marking notifications as read: \(error)")
        }
    }

    func fetchPost(postId: UUID, currentUserId: UUID) async -> HangerTalkPostWithAuthor? {
        if DemoModeManager.shared.isDemoModeEnabled { return nil }

        do {
            let response: [HangerTalkPostResponse] = try await supabase
                .from("hanger_talk_posts")
                .select("*, profiles(id, call_sign, profile_picture_url, first_name, last_name)")
                .eq("id", value: postId.uuidString)
                .limit(1)
                .execute()
                .value

            guard let resp = response.first else { return nil }
            let interactions = await fetchUserInteractions(currentUserId: currentUserId, postIds: [postId])
            return mapResponseToPostWithAuthor(resp, interactions: interactions)
        } catch {
            print("Error fetching post: \(error)")
            return nil
        }
    }

    private func insertNotification(recipientId: UUID, actorId: UUID, type: HangerTalkNotificationType, postId: UUID?) async {
        if DemoModeManager.shared.isDemoModeEnabled { return }
        guard recipientId != actorId else { return }

        let insert = HangerTalkNotificationInsert(
            recipientId: recipientId,
            actorId: actorId,
            type: type,
            postId: postId
        )

        do {
            try await supabase
                .from("hanger_talk_notifications")
                .insert(insert)
                .execute()
        } catch {
            print("Error inserting notification: \(error)")
        }
    }

    // MARK: - Demo Data

    static let demoPosts: [HangerTalkPostWithAuthor] = []
}
