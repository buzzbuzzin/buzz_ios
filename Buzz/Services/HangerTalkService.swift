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

    private let supabase = SupabaseClient.shared.client

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
                .ilike("body", pattern: "%\(query)%")
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
                .or("call_sign.ilike.%\(query)%,first_name.ilike.%\(query)%,last_name.ilike.%\(query)%")
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
            if let index = feedPosts.firstIndex(where: { $0.id == postId }) {
                feedPosts[index].isLikedByCurrentUser.toggle()
            }
            return
        }

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
            }
        }

        // Update local state
        if let index = feedPosts.firstIndex(where: { $0.id == postId }) {
            feedPosts[index].isLikedByCurrentUser.toggle()
        }
        if let index = replies.firstIndex(where: { $0.id == postId }) {
            replies[index].isLikedByCurrentUser.toggle()
        }
    }

    // MARK: - Toggle Repost

    func toggleRepost(postId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled {
            if let index = feedPosts.firstIndex(where: { $0.id == postId }) {
                feedPosts[index].isRepostedByCurrentUser.toggle()
            }
            return
        }

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

        // Update local state
        if let index = feedPosts.firstIndex(where: { $0.id == postId }) {
            feedPosts[index].isRepostedByCurrentUser.toggle()
        }
        if let index = replies.firstIndex(where: { $0.id == postId }) {
            replies[index].isRepostedByCurrentUser.toggle()
        }
    }

    // MARK: - Toggle Bookmark

    func toggleBookmark(postId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled {
            if let index = feedPosts.firstIndex(where: { $0.id == postId }) {
                feedPosts[index].isBookmarkedByCurrentUser.toggle()
            }
            return
        }

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

        // Update local state
        if let index = feedPosts.firstIndex(where: { $0.id == postId }) {
            feedPosts[index].isBookmarkedByCurrentUser.toggle()
        }
        if let index = replies.firstIndex(where: { $0.id == postId }) {
            replies[index].isBookmarkedByCurrentUser.toggle()
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
                .ilike("call_sign", pattern: "%\(query)%")
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

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage?.jpegData(compressionQuality: 0.8)
    }

    // MARK: - Helpers

    private func fetchUserInteractions(currentUserId: UUID, postIds: [UUID]) async -> (likes: Set<UUID>, reposts: Set<UUID>, bookmarks: Set<UUID>, followedAuthorIds: Set<UUID>) {
        guard !postIds.isEmpty else { return ([], [], [], []) }

        do {
            let userLikes: [HangerTalkLike] = try await supabase
                .from("hanger_talk_likes")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .execute()
                .value
            let likedIds = Set(userLikes.map { $0.postId })

            let userReposts: [HangerTalkRepost] = try await supabase
                .from("hanger_talk_reposts")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .execute()
                .value
            let repostedIds = Set(userReposts.map { $0.postId })

            let userBookmarks: [HangerTalkBookmark] = try await supabase
                .from("hanger_talk_bookmarks")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
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

    // MARK: - Demo Data

    static let demoPosts: [HangerTalkPostWithAuthor] = []
}
