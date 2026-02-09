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

    func createPost(authorId: UUID, body: String, imageUrls: [String] = []) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        let insert = HangerTalkPostInsert(
            authorId: authorId,
            body: body,
            imageUrls: imageUrls,
            isReply: false,
            parentPostId: nil
        )

        try await supabase
            .from("hanger_talk_posts")
            .insert(insert)
            .execute()
    }

    // MARK: - Create Reply

    func createReply(authorId: UUID, parentPostId: UUID, body: String, imageUrls: [String] = []) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        let insert = HangerTalkPostInsert(
            authorId: authorId,
            body: body,
            imageUrls: imageUrls,
            isReply: true,
            parentPostId: parentPostId
        )

        try await supabase
            .from("hanger_talk_posts")
            .insert(insert)
            .execute()
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

    private func fetchUserInteractions(currentUserId: UUID, postIds: [UUID]) async -> (likes: Set<UUID>, reposts: Set<UUID>, bookmarks: Set<UUID>) {
        guard !postIds.isEmpty else { return ([], [], []) }

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

            return (likedIds, repostedIds, bookmarkedIds)
        } catch {
            print("Error fetching user interactions: \(error)")
            return ([], [], [])
        }
    }

    private func mapResponseToPostWithAuthor(_ resp: HangerTalkPostResponse, interactions: (likes: Set<UUID>, reposts: Set<UUID>, bookmarks: Set<UUID>)) -> HangerTalkPostWithAuthor {
        let profile = resp.profileData
        return HangerTalkPostWithAuthor(
            id: resp.id,
            post: resp.toHangerTalkPost(),
            authorCallSign: profile?.callSign,
            authorProfilePictureUrl: profile?.profilePictureUrl,
            authorFullName: profile?.fullName ?? "Pilot",
            isLikedByCurrentUser: interactions.likes.contains(resp.id),
            isRepostedByCurrentUser: interactions.reposts.contains(resp.id),
            isBookmarkedByCurrentUser: interactions.bookmarks.contains(resp.id)
        )
    }

    // MARK: - Demo Data

    static let demoPosts: [HangerTalkPostWithAuthor] = []
}
