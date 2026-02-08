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
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseClient.shared.client

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

            // Fetch which posts current user has liked
            var likedPostIds: Set<UUID> = []
            if !response.isEmpty {
                let userLikes: [HangarLike] = try await supabase
                    .from("hangar_likes")
                    .select()
                    .eq("user_id", value: currentUserId.uuidString)
                    .execute()
                    .value

                likedPostIds = Set(userLikes.compactMap { $0.postId })
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

            // Fetch which posts current user has liked
            var likedPostIds: Set<UUID> = []
            if !response.isEmpty {
                let userLikes: [HangarLike] = try await supabase
                    .from("hangar_likes")
                    .select()
                    .eq("user_id", value: currentUserId.uuidString)
                    .execute()
                    .value

                likedPostIds = Set(userLikes.compactMap { $0.postId })
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

            // Fetch user's comment likes
            var likedCommentIds: Set<UUID> = []
            if !response.isEmpty {
                let userLikes: [HangarLike] = try await supabase
                    .from("hangar_likes")
                    .select()
                    .eq("user_id", value: currentUserId.uuidString)
                    .execute()
                    .value

                likedCommentIds = Set(userLikes.compactMap { $0.commentId })
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
