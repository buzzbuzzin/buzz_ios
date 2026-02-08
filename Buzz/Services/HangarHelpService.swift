//
//  HangarHelpService.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/7/26.
//

import Foundation
import Supabase
import Combine

@MainActor
class HangarHelpService: ObservableObject {
    @Published var topics: [HangarTopic] = []
    @Published var posts: [HangarPostWithAuthor] = []
    @Published var comments: [HangarCommentWithAuthor] = []
    @Published var hiddenPostIds: Set<UUID> = []
    @Published var savedPosts: [HangarPostWithAuthor] = []
    @Published var savedComments: [HangarCommentWithAuthor] = []
    @Published var activityItems: [HangarActivityItem] = []
    @Published var hasNewActivity: Bool = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseClient.shared.client
    private static let activityLastSeenKey = "hangarActivityLastSeenAt"

    // MARK: - Fetch Topics

    func fetchTopics() async {
        isLoading = true
        errorMessage = nil

        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 300_000_000)
            topics = Self.demoTopics
            isLoading = false
            return
        }

        do {
            let fetchedTopics: [HangarTopic] = try await supabase
                .from("hangar_topics")
                .select()
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            topics = fetchedTopics
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Fetch All Posts (unified feed)

    func fetchAllPosts(currentUserId: UUID) async {
        isLoading = true
        errorMessage = nil

        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 300_000_000)
            posts = Self.demoPosts
            isLoading = false
            return
        }

        do {
            let response: [HangarPostResponse] = try await supabase
                .from("hangar_posts")
                .select("*, profiles(id, call_sign, profile_picture_url, first_name, last_name), hangar_topics(name, icon_name, color_name)")
                .order("created_at", ascending: false)
                .execute()
                .value

            // Fetch user's post interactions (likes, saves, follows, hidden)
            var likedPostIds: Set<UUID> = []
            var savedPostIds: Set<UUID> = []
            var followedPostIds: Set<UUID> = []
            var hiddenIds: Set<UUID> = []

            if !response.isEmpty {
                let userLikes: [HangarLike] = try await supabase
                    .from("hangar_likes")
                    .select()
                    .eq("user_id", value: currentUserId.uuidString)
                    .execute()
                    .value
                likedPostIds = Set(userLikes.compactMap { $0.postId })

                let userSaves: [HangarSavedPost] = try await supabase
                    .from("hangar_saved_posts")
                    .select()
                    .eq("user_id", value: currentUserId.uuidString)
                    .execute()
                    .value
                savedPostIds = Set(userSaves.map { $0.postId })

                let userFollows: [HangarFollowedPost] = try await supabase
                    .from("hangar_followed_posts")
                    .select()
                    .eq("user_id", value: currentUserId.uuidString)
                    .execute()
                    .value
                followedPostIds = Set(userFollows.map { $0.postId })

                let userHidden: [HangarHiddenPost] = try await supabase
                    .from("hangar_hidden_posts")
                    .select()
                    .eq("user_id", value: currentUserId.uuidString)
                    .execute()
                    .value
                hiddenIds = Set(userHidden.map { $0.postId })
            }

            hiddenPostIds = hiddenIds

            posts = response.map { resp in
                let profile = resp.profileData
                let topic = resp.topicData
                return HangarPostWithAuthor(
                    id: resp.id,
                    post: resp.toHangarPost(),
                    authorCallSign: profile?.callSign,
                    authorProfilePictureUrl: profile?.profilePictureUrl,
                    authorFullName: profile?.fullName ?? "Pilot",
                    isLikedByCurrentUser: likedPostIds.contains(resp.id),
                    isSavedByCurrentUser: savedPostIds.contains(resp.id),
                    isFollowedByCurrentUser: followedPostIds.contains(resp.id),
                    topicName: topic?.name ?? "General",
                    topicIconName: topic?.iconName ?? "bubble.left.and.bubble.right.fill",
                    topicColorName: topic?.colorName ?? "green"
                )
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Fetch Posts for Topic

    func fetchPosts(topicId: UUID, currentUserId: UUID) async {
        isLoading = true
        errorMessage = nil

        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 300_000_000)
            posts = Self.demoPosts
            isLoading = false
            return
        }

        do {
            let response: [HangarPostResponse] = try await supabase
                .from("hangar_posts")
                .select("*, profiles(id, call_sign, profile_picture_url, first_name, last_name), hangar_topics(name, icon_name, color_name)")
                .eq("topic_id", value: topicId.uuidString)
                .order("is_pinned", ascending: false)
                .order("created_at", ascending: false)
                .execute()
                .value

            // Fetch user's post interactions
            var likedPostIds: Set<UUID> = []
            var savedPostIds: Set<UUID> = []
            var followedPostIds: Set<UUID> = []

            if !response.isEmpty {
                let userLikes: [HangarLike] = try await supabase
                    .from("hangar_likes")
                    .select()
                    .eq("user_id", value: currentUserId.uuidString)
                    .execute()
                    .value
                likedPostIds = Set(userLikes.compactMap { $0.postId })

                let userSaves: [HangarSavedPost] = try await supabase
                    .from("hangar_saved_posts")
                    .select()
                    .eq("user_id", value: currentUserId.uuidString)
                    .execute()
                    .value
                savedPostIds = Set(userSaves.map { $0.postId })

                let userFollows: [HangarFollowedPost] = try await supabase
                    .from("hangar_followed_posts")
                    .select()
                    .eq("user_id", value: currentUserId.uuidString)
                    .execute()
                    .value
                followedPostIds = Set(userFollows.map { $0.postId })
            }

            posts = response.map { resp in
                let profile = resp.profileData
                let topic = resp.topicData
                return HangarPostWithAuthor(
                    id: resp.id,
                    post: resp.toHangarPost(),
                    authorCallSign: profile?.callSign,
                    authorProfilePictureUrl: profile?.profilePictureUrl,
                    authorFullName: profile?.fullName ?? "Pilot",
                    isLikedByCurrentUser: likedPostIds.contains(resp.id),
                    isSavedByCurrentUser: savedPostIds.contains(resp.id),
                    isFollowedByCurrentUser: followedPostIds.contains(resp.id),
                    topicName: topic?.name ?? "General",
                    topicIconName: topic?.iconName ?? "bubble.left.and.bubble.right.fill",
                    topicColorName: topic?.colorName ?? "green"
                )
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Fetch Comments for Post

    func fetchComments(postId: UUID, currentUserId: UUID) async {
        isLoading = true
        errorMessage = nil

        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 300_000_000)
            comments = []
            isLoading = false
            return
        }

        do {
            let response: [HangarCommentResponse] = try await supabase
                .from("hangar_comments")
                .select("*, profiles(id, call_sign, profile_picture_url, first_name, last_name)")
                .eq("post_id", value: postId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value

            // Fetch user's comment interactions (likes, saves, follows)
            var likedCommentIds: Set<UUID> = []
            var savedCommentIds: Set<UUID> = []
            var followedCommentIds: Set<UUID> = []

            if !response.isEmpty {
                let userLikes: [HangarLike] = try await supabase
                    .from("hangar_likes")
                    .select()
                    .eq("user_id", value: currentUserId.uuidString)
                    .execute()
                    .value
                likedCommentIds = Set(userLikes.compactMap { $0.commentId })

                let userSaves: [HangarSavedComment] = try await supabase
                    .from("hangar_saved_comments")
                    .select()
                    .eq("user_id", value: currentUserId.uuidString)
                    .execute()
                    .value
                savedCommentIds = Set(userSaves.map { $0.commentId })

                let userFollows: [HangarFollowedComment] = try await supabase
                    .from("hangar_followed_comments")
                    .select()
                    .eq("user_id", value: currentUserId.uuidString)
                    .execute()
                    .value
                followedCommentIds = Set(userFollows.map { $0.commentId })
            }

            let flatComments = response.map { resp in
                let profile = resp.profileData
                return HangarCommentWithAuthor(
                    id: resp.id,
                    comment: resp.toHangarComment(),
                    authorCallSign: profile?.callSign,
                    authorProfilePictureUrl: profile?.profilePictureUrl,
                    authorFullName: profile?.fullName ?? "Pilot",
                    isLikedByCurrentUser: likedCommentIds.contains(resp.id),
                    isSavedByCurrentUser: savedCommentIds.contains(resp.id),
                    isFollowedByCurrentUser: followedCommentIds.contains(resp.id),
                    replies: []
                )
            }

            comments = buildCommentTree(flatComments)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Create Post

    func createPost(topicId: UUID, authorId: UUID, title: String, body: String) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        let insert = HangarPostInsert(topicId: topicId, authorId: authorId, title: title, body: body)

        try await supabase
            .from("hangar_posts")
            .insert(insert)
            .execute()
    }

    // MARK: - Delete Post

    func deletePost(postId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        try await supabase
            .from("hangar_posts")
            .delete()
            .eq("id", value: postId.uuidString)
            .execute()
    }

    // MARK: - Update Post

    func updatePost(postId: UUID, title: String, body: String) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        let updateData: [String: AnyJSON] = [
            "title": .string(title),
            "body": .string(body)
        ]

        try await supabase
            .from("hangar_posts")
            .update(updateData)
            .eq("id", value: postId.uuidString)
            .execute()
    }

    // MARK: - Delete Comment

    func deleteComment(commentId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        try await supabase
            .from("hangar_comments")
            .delete()
            .eq("id", value: commentId.uuidString)
            .execute()
    }

    // MARK: - Update Comment

    func updateComment(commentId: UUID, body: String) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        let updateData: [String: AnyJSON] = [
            "body": .string(body)
        ]

        try await supabase
            .from("hangar_comments")
            .update(updateData)
            .eq("id", value: commentId.uuidString)
            .execute()
    }

    // MARK: - Create Comment

    func createComment(postId: UUID, parentCommentId: UUID?, authorId: UUID, body: String, depth: Int) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        let insert = HangarCommentInsert(
            postId: postId,
            parentCommentId: parentCommentId,
            authorId: authorId,
            body: body,
            depth: depth
        )

        try await supabase
            .from("hangar_comments")
            .insert(insert)
            .execute()
    }

    // MARK: - Toggle Like (Post)

    func togglePostLike(postId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled {
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                posts[index].isLikedByCurrentUser.toggle()
            }
            return
        }

        let existingLikes: [HangarLike] = try await supabase
            .from("hangar_likes")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("post_id", value: postId.uuidString)
            .execute()
            .value

        if let existingLike = existingLikes.first {
            try await supabase
                .from("hangar_likes")
                .delete()
                .eq("id", value: existingLike.id.uuidString)
                .execute()
        } else {
            let likeData: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "post_id": .string(postId.uuidString)
            ]
            try await supabase
                .from("hangar_likes")
                .insert(likeData)
                .execute()
        }
    }

    // MARK: - Toggle Like (Comment)

    func toggleCommentLike(commentId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        let existingLikes: [HangarLike] = try await supabase
            .from("hangar_likes")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("comment_id", value: commentId.uuidString)
            .execute()
            .value

        if let existingLike = existingLikes.first {
            try await supabase
                .from("hangar_likes")
                .delete()
                .eq("id", value: existingLike.id.uuidString)
                .execute()
        } else {
            let likeData: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "comment_id": .string(commentId.uuidString)
            ]
            try await supabase
                .from("hangar_likes")
                .insert(likeData)
                .execute()
        }
    }

    // MARK: - Toggle Save Post

    func toggleSavePost(postId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled {
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                posts[index].isSavedByCurrentUser.toggle()
            }
            return
        }

        let existing: [HangarSavedPost] = try await supabase
            .from("hangar_saved_posts")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("post_id", value: postId.uuidString)
            .execute()
            .value

        if let saved = existing.first {
            try await supabase
                .from("hangar_saved_posts")
                .delete()
                .eq("id", value: saved.id.uuidString)
                .execute()
        } else {
            let data: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "post_id": .string(postId.uuidString)
            ]
            try await supabase
                .from("hangar_saved_posts")
                .insert(data)
                .execute()
        }

        // Update local state
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index].isSavedByCurrentUser.toggle()
        }
    }

    // MARK: - Toggle Follow Post

    func toggleFollowPost(postId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled {
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                posts[index].isFollowedByCurrentUser.toggle()
            }
            return
        }

        let existing: [HangarFollowedPost] = try await supabase
            .from("hangar_followed_posts")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("post_id", value: postId.uuidString)
            .execute()
            .value

        if let followed = existing.first {
            try await supabase
                .from("hangar_followed_posts")
                .delete()
                .eq("id", value: followed.id.uuidString)
                .execute()
        } else {
            let data: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "post_id": .string(postId.uuidString)
            ]
            try await supabase
                .from("hangar_followed_posts")
                .insert(data)
                .execute()
        }

        // Update local state
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index].isFollowedByCurrentUser.toggle()
        }
    }

    // MARK: - Toggle Hide Post

    func toggleHidePost(postId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled {
            if hiddenPostIds.contains(postId) {
                hiddenPostIds.remove(postId)
            } else {
                hiddenPostIds.insert(postId)
            }
            return
        }

        let existing: [HangarHiddenPost] = try await supabase
            .from("hangar_hidden_posts")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("post_id", value: postId.uuidString)
            .execute()
            .value

        if let hidden = existing.first {
            try await supabase
                .from("hangar_hidden_posts")
                .delete()
                .eq("id", value: hidden.id.uuidString)
                .execute()
            hiddenPostIds.remove(postId)
        } else {
            let data: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "post_id": .string(postId.uuidString)
            ]
            try await supabase
                .from("hangar_hidden_posts")
                .insert(data)
                .execute()
            hiddenPostIds.insert(postId)
        }
    }

    // MARK: - Toggle Save Comment

    func toggleSaveComment(commentId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        let existing: [HangarSavedComment] = try await supabase
            .from("hangar_saved_comments")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("comment_id", value: commentId.uuidString)
            .execute()
            .value

        if let saved = existing.first {
            try await supabase
                .from("hangar_saved_comments")
                .delete()
                .eq("id", value: saved.id.uuidString)
                .execute()
        } else {
            let data: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "comment_id": .string(commentId.uuidString)
            ]
            try await supabase
                .from("hangar_saved_comments")
                .insert(data)
                .execute()
        }
    }

    // MARK: - Toggle Follow Comment

    func toggleFollowComment(commentId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        let existing: [HangarFollowedComment] = try await supabase
            .from("hangar_followed_comments")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("comment_id", value: commentId.uuidString)
            .execute()
            .value

        if let followed = existing.first {
            try await supabase
                .from("hangar_followed_comments")
                .delete()
                .eq("id", value: followed.id.uuidString)
                .execute()
        } else {
            let data: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "comment_id": .string(commentId.uuidString)
            ]
            try await supabase
                .from("hangar_followed_comments")
                .insert(data)
                .execute()
        }
    }

    // MARK: - Fetch Saved Posts

    func fetchSavedPosts(currentUserId: UUID) async {
        if DemoModeManager.shared.isDemoModeEnabled {
            savedPosts = []
            return
        }

        do {
            // Get saved post IDs
            let userSaves: [HangarSavedPost] = try await supabase
                .from("hangar_saved_posts")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            let savedPostIds = userSaves.map { $0.postId }
            guard !savedPostIds.isEmpty else {
                savedPosts = []
                return
            }

            // Fetch those posts with joins
            let response: [HangarPostResponse] = try await supabase
                .from("hangar_posts")
                .select("*, profiles(id, call_sign, profile_picture_url, first_name, last_name), hangar_topics(name, icon_name, color_name)")
                .in("id", values: savedPostIds.map { $0.uuidString })
                .execute()
                .value

            // Fetch user's like state
            let userLikes: [HangarLike] = try await supabase
                .from("hangar_likes")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .execute()
                .value
            let likedPostIds = Set(userLikes.compactMap { $0.postId })

            // Fetch follow state
            let userFollows: [HangarFollowedPost] = try await supabase
                .from("hangar_followed_posts")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .execute()
                .value
            let followedPostIds = Set(userFollows.map { $0.postId })

            let savedSet = Set(savedPostIds)

            // Sort to match saved order (most recently saved first)
            let mappedPosts = response.map { resp in
                let profile = resp.profileData
                let topic = resp.topicData
                return HangarPostWithAuthor(
                    id: resp.id,
                    post: resp.toHangarPost(),
                    authorCallSign: profile?.callSign,
                    authorProfilePictureUrl: profile?.profilePictureUrl,
                    authorFullName: profile?.fullName ?? "Pilot",
                    isLikedByCurrentUser: likedPostIds.contains(resp.id),
                    isSavedByCurrentUser: savedSet.contains(resp.id),
                    isFollowedByCurrentUser: followedPostIds.contains(resp.id),
                    topicName: topic?.name ?? "General",
                    topicIconName: topic?.iconName ?? "bubble.left.and.bubble.right.fill",
                    topicColorName: topic?.colorName ?? "green"
                )
            }

            // Maintain saved order
            savedPosts = savedPostIds.compactMap { postId in
                mappedPosts.first { $0.id == postId }
            }
        } catch {
            print("Error fetching saved posts: \(error)")
        }
    }

    // MARK: - Fetch Saved Comments

    func fetchSavedComments(currentUserId: UUID) async {
        if DemoModeManager.shared.isDemoModeEnabled {
            savedComments = []
            return
        }

        do {
            // Get saved comment IDs
            let userSaves: [HangarSavedComment] = try await supabase
                .from("hangar_saved_comments")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            let savedCommentIds = userSaves.map { $0.commentId }
            guard !savedCommentIds.isEmpty else {
                savedComments = []
                return
            }

            // Fetch those comments with profile joins
            let response: [HangarCommentResponse] = try await supabase
                .from("hangar_comments")
                .select("*, profiles(id, call_sign, profile_picture_url, first_name, last_name)")
                .in("id", values: savedCommentIds.map { $0.uuidString })
                .execute()
                .value

            // Fetch user's like state
            let userLikes: [HangarLike] = try await supabase
                .from("hangar_likes")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .execute()
                .value
            let likedCommentIds = Set(userLikes.compactMap { $0.commentId })

            // Fetch follow state
            let userFollows: [HangarFollowedComment] = try await supabase
                .from("hangar_followed_comments")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .execute()
                .value
            let followedCommentIds = Set(userFollows.map { $0.commentId })

            let savedSet = Set(savedCommentIds)

            let mappedComments = response.map { resp in
                let profile = resp.profileData
                return HangarCommentWithAuthor(
                    id: resp.id,
                    comment: resp.toHangarComment(),
                    authorCallSign: profile?.callSign,
                    authorProfilePictureUrl: profile?.profilePictureUrl,
                    authorFullName: profile?.fullName ?? "Pilot",
                    isLikedByCurrentUser: likedCommentIds.contains(resp.id),
                    isSavedByCurrentUser: savedSet.contains(resp.id),
                    isFollowedByCurrentUser: followedCommentIds.contains(resp.id),
                    replies: []
                )
            }

            // Maintain saved order
            savedComments = savedCommentIds.compactMap { commentId in
                mappedComments.first { $0.id == commentId }
            }
        } catch {
            print("Error fetching saved comments: \(error)")
        }
    }

    // MARK: - Fetch Activity Items

    func fetchActivityItems(currentUserId: UUID) async {
        if DemoModeManager.shared.isDemoModeEnabled {
            activityItems = []
            return
        }

        do {
            // Get followed post IDs
            let followedPosts: [HangarFollowedPost] = try await supabase
                .from("hangar_followed_posts")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .execute()
                .value
            let followedPostIds = followedPosts.map { $0.postId }

            // Get followed comment IDs
            let followedComments: [HangarFollowedComment] = try await supabase
                .from("hangar_followed_comments")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .execute()
                .value
            let followedCommentIds = followedComments.map { $0.commentId }

            var allItems: [HangarActivityItem] = []

            // Fetch new comments on followed posts
            if !followedPostIds.isEmpty {
                let postComments: [HangarActivityCommentResponse] = try await supabase
                    .from("hangar_comments")
                    .select("id, post_id, parent_comment_id, author_id, body, created_at, profiles(id, call_sign, profile_picture_url, first_name, last_name), hangar_posts!inner(id, title)")
                    .in("post_id", values: followedPostIds.map { $0.uuidString })
                    .neq("author_id", value: currentUserId.uuidString)
                    .order("created_at", ascending: false)
                    .limit(50)
                    .execute()
                    .value

                for comment in postComments {
                    let profile = comment.profileData
                    if let postInfo = comment.hangarPosts {
                        allItems.append(HangarActivityItem(
                            id: comment.id,
                            type: .newCommentOnFollowedPost,
                            commentBody: comment.body,
                            commentAuthorName: profile?.fullName ?? "Pilot",
                            commentAuthorCallSign: profile?.callSign,
                            commentAuthorProfilePictureUrl: profile?.profilePictureUrl,
                            postId: postInfo.id,
                            postTitle: postInfo.title,
                            createdAt: comment.createdAt
                        ))
                    }
                }
            }

            // Fetch replies to followed comments
            if !followedCommentIds.isEmpty {
                let commentReplies: [HangarActivityCommentResponse] = try await supabase
                    .from("hangar_comments")
                    .select("id, post_id, parent_comment_id, author_id, body, created_at, profiles(id, call_sign, profile_picture_url, first_name, last_name), hangar_posts!inner(id, title)")
                    .in("parent_comment_id", values: followedCommentIds.map { $0.uuidString })
                    .neq("author_id", value: currentUserId.uuidString)
                    .order("created_at", ascending: false)
                    .limit(50)
                    .execute()
                    .value

                for comment in commentReplies {
                    let profile = comment.profileData
                    if let postInfo = comment.hangarPosts {
                        allItems.append(HangarActivityItem(
                            id: comment.id,
                            type: .replyToFollowedComment,
                            commentBody: comment.body,
                            commentAuthorName: profile?.fullName ?? "Pilot",
                            commentAuthorCallSign: profile?.callSign,
                            commentAuthorProfilePictureUrl: profile?.profilePictureUrl,
                            postId: postInfo.id,
                            postTitle: postInfo.title,
                            createdAt: comment.createdAt
                        ))
                    }
                }
            }

            // Deduplicate by comment ID and sort by newest first
            var seen = Set<UUID>()
            let deduplicated = allItems.filter { item in
                guard !seen.contains(item.id) else { return false }
                seen.insert(item.id)
                return true
            }

            activityItems = deduplicated.sorted { $0.createdAt > $1.createdAt }
            markActivityAsSeen()
        } catch {
            print("Error fetching activity items: \(error)")
        }
    }

    // MARK: - Check for New Activity (lightweight)

    func checkForNewActivity(currentUserId: UUID) async {
        if DemoModeManager.shared.isDemoModeEnabled {
            hasNewActivity = false
            return
        }

        do {
            let lastSeenAt = getActivityLastSeenDate()

            // Get followed post IDs
            let followedPosts: [HangarFollowedPost] = try await supabase
                .from("hangar_followed_posts")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .execute()
                .value
            let followedPostIds = followedPosts.map { $0.postId }

            // Get followed comment IDs
            let followedComments: [HangarFollowedComment] = try await supabase
                .from("hangar_followed_comments")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .execute()
                .value
            let followedCommentIds = followedComments.map { $0.commentId }

            // Check for new comments on followed posts
            if !followedPostIds.isEmpty {
                let newPostComments: [HangarComment] = try await supabase
                    .from("hangar_comments")
                    .select()
                    .in("post_id", values: followedPostIds.map { $0.uuidString })
                    .neq("author_id", value: currentUserId.uuidString)
                    .gt("created_at", value: ISO8601DateFormatter().string(from: lastSeenAt))
                    .limit(1)
                    .execute()
                    .value

                if !newPostComments.isEmpty {
                    hasNewActivity = true
                    return
                }
            }

            // Check for replies to followed comments
            if !followedCommentIds.isEmpty {
                let newCommentReplies: [HangarComment] = try await supabase
                    .from("hangar_comments")
                    .select()
                    .in("parent_comment_id", values: followedCommentIds.map { $0.uuidString })
                    .neq("author_id", value: currentUserId.uuidString)
                    .gt("created_at", value: ISO8601DateFormatter().string(from: lastSeenAt))
                    .limit(1)
                    .execute()
                    .value

                hasNewActivity = !newCommentReplies.isEmpty
            } else {
                hasNewActivity = false
            }
        } catch {
            print("Error checking for new activity: \(error)")
            hasNewActivity = false
        }
    }

    // MARK: - Mark Activity As Seen

    func markActivityAsSeen() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.activityLastSeenKey)
        hasNewActivity = false
    }

    // MARK: - Get Activity Last Seen Date

    private func getActivityLastSeenDate() -> Date {
        let timestamp = UserDefaults.standard.double(forKey: Self.activityLastSeenKey)
        if timestamp == 0 {
            return .distantPast
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    // MARK: - Build Comment Tree

    private func buildCommentTree(_ flatComments: [HangarCommentWithAuthor]) -> [HangarCommentWithAuthor] {
        var commentMap: [UUID: HangarCommentWithAuthor] = [:]
        var topLevel: [UUID] = []

        for comment in flatComments {
            commentMap[comment.id] = comment
        }

        for comment in flatComments {
            if let parentId = comment.comment.parentCommentId, commentMap[parentId] != nil {
                commentMap[parentId]!.replies.append(comment)
            } else {
                topLevel.append(comment.id)
            }
        }

        return topLevel.compactMap { commentMap[$0] }
    }

    // MARK: - Demo Data

    static let demoTopics: [HangarTopic] = [
        HangarTopic(id: UUID(), name: "Regulations", description: "FAA rules, Part 107, airspace questions", iconName: "book.closed.fill", colorName: "blue", displayOrder: 1, isActive: true, createdAt: Date()),
        HangarTopic(id: UUID(), name: "Equipment", description: "Drones, cameras, accessories, repairs", iconName: "wrench.and.screwdriver.fill", colorName: "orange", displayOrder: 2, isActive: true, createdAt: Date()),
        HangarTopic(id: UUID(), name: "Best Practices", description: "Tips, techniques, and flight procedures", iconName: "star.fill", colorName: "yellow", displayOrder: 3, isActive: true, createdAt: Date()),
        HangarTopic(id: UUID(), name: "Weather", description: "Forecasts, METAR reading, wind advisories", iconName: "cloud.sun.bolt.fill", colorName: "cyan", displayOrder: 4, isActive: true, createdAt: Date()),
        HangarTopic(id: UUID(), name: "Emergencies", description: "Incident reporting, emergency procedures", iconName: "exclamationmark.triangle.fill", colorName: "red", displayOrder: 5, isActive: true, createdAt: Date()),
        HangarTopic(id: UUID(), name: "General", description: "Anything else drone-related", iconName: "bubble.left.and.bubble.right.fill", colorName: "green", displayOrder: 6, isActive: true, createdAt: Date())
    ]

    static let demoPosts: [HangarPostWithAuthor] = []
}
