//
//  HangerTalkPostDetailView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/8/26.
//

import SwiftUI

struct HangerTalkPostDetailView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @StateObject private var service = HangerTalkService()
    @State private var currentPost: HangerTalkPostWithAuthor
    @State private var likeCount: Int
    @State private var replyCount: Int
    @State private var repostCount: Int
    @State private var isLikedByCurrentUser: Bool
    @State private var isRepostedByCurrentUser: Bool
    @State private var isBookmarkedByCurrentUser: Bool
    @State private var showComposeReply = false
    @State private var showDeleteConfirmation = false
    @State private var showEditPost = false
    @State private var navigateToProfileId: UUID?
    @State private var likeAnimating = false
    @State private var repostAnimating = false
    @State private var bookmarkAnimating = false
    @State private var pendingLikeUpdate = false
    @State private var pendingReplyUpdate = false
    @State private var pendingRepostUpdate = false
    @State private var pendingBookmarkUpdate = false

    init(postWithAuthor: HangerTalkPostWithAuthor) {
        _currentPost = State(initialValue: postWithAuthor)
        _likeCount = State(initialValue: postWithAuthor.post.likeCount)
        _replyCount = State(initialValue: postWithAuthor.post.replyCount)
        _repostCount = State(initialValue: postWithAuthor.post.repostCount)
        _isLikedByCurrentUser = State(initialValue: postWithAuthor.isLikedByCurrentUser)
        _isRepostedByCurrentUser = State(initialValue: postWithAuthor.isRepostedByCurrentUser)
        _isBookmarkedByCurrentUser = State(initialValue: postWithAuthor.isBookmarkedByCurrentUser)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    postContentSection
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 10)

                    Divider()

                    statsBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                    Divider()

                    postActionBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                    Rectangle()
                        .fill(Color(.systemGroupedBackground))
                        .frame(height: 8)

                    repliesSection
                }
            }
            .refreshable {
                await refreshDetail()
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if currentPost.post.authorId == authService.activeUserId {
                    Menu {
                        Button {
                            showEditPost = true
                        } label: {
                            Label("Edit Post", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Post", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
            }
        }
        .alert("Delete Post", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    try? await service.deletePost(postId: currentPost.id)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
        .sheet(isPresented: $showEditPost) {
            NavigationView {
                HangerTalkEditView(
                    postWithAuthor: currentPost,
                    onPostUpdated: {
                        showEditPost = false
                        Task {
                            await refreshDetail()
                        }
                    }
                )
                .environmentObject(authService)
            }
        }
        .sheet(isPresented: $showComposeReply) {
            NavigationView {
                HangerTalkComposeView(
                    replyToPost: currentPost,
                    onPostCreated: {
                        showComposeReply = false
                        pendingReplyUpdate = true
                        applyPostUpdate(replyDelta: 1)
                        Task { @MainActor in
                            guard let userId = authService.activeUserId else {
                                pendingReplyUpdate = false
                                return
                            }
                            await service.fetchReplies(parentPostId: currentPost.id, currentUserId: userId)
                            await refreshCurrentPost(currentUserId: userId)
                            pendingReplyUpdate = false
                        }
                    }
                )
                .environmentObject(authService)
            }
        }
        .background(
            NavigationLink(
                destination: Group {
                    if let profileId = navigateToProfileId {
                        PublicProfileView(pilotId: profileId)
                            .environmentObject(authService)
                    }
                },
                isActive: Binding(
                    get: { navigateToProfileId != nil },
                    set: { if !$0 { navigateToProfileId = nil } }
                )
            ) { EmptyView() }
                .hidden()
        )
        .task {
            await refreshDetail()
        }
    }

    // MARK: - Post Content Section

    private var postContentSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                navigateToProfileId = currentPost.post.authorId
            } label: {
                authorAvatar(size: 44)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Button {
                        navigateToProfileId = currentPost.post.authorId
                    } label: {
                        Text(currentPost.authorCallSign ?? "Pilot")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)

                    Text(authorHandle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                TappableMentionText(currentPost.post.body, font: .body) { callSign in
                    Task {
                        if let profile = await service.resolveCallSign(callSign) {
                            navigateToProfileId = profile.id
                        }
                    }
                }

                if !currentPost.post.imageUrls.isEmpty {
                    HangerImageCarousel(imageUrls: currentPost.post.imageUrls, height: 300)
                }

                (
                    Text(currentPost.post.createdAt, style: .date)
                        .foregroundColor(.secondary)
                    + Text(" · ").foregroundColor(.secondary)
                    + Text(currentPost.post.createdAt, style: .time).foregroundColor(.secondary)
                )
                .font(.footnote)
            }
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 16) {
            if replyCount > 0 {
                HStack(spacing: 4) {
                    Text("\(replyCount)")
                        .fontWeight(.semibold)
                    Text(replyCount == 1 ? "Reply" : "Replies")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
            }

            if repostCount > 0 {
                HStack(spacing: 4) {
                    Text("\(repostCount)")
                        .fontWeight(.semibold)
                    Text(repostCount == 1 ? "Repost" : "Reposts")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
            }

            if likeCount > 0 {
                HStack(spacing: 4) {
                    Text("\(likeCount)")
                        .fontWeight(.semibold)
                    Text(likeCount == 1 ? "Like" : "Likes")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
            }

            Spacer()
        }
    }

    // MARK: - Post Action Bar

    private var postActionBar: some View {
        HStack(spacing: 0) {
            Button {
                showComposeReply = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                    Text("\(replyCount)")
                }
                .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                guard let userId = authService.activeUserId else { return }
                let wasReposted = isRepostedByCurrentUser
                pendingRepostUpdate = true
                withAnimation(.easeInOut(duration: 0.15)) {
                    repostAnimating = true
                    applyPostUpdate(
                        repostDelta: wasReposted ? -1 : 1,
                        isRepostedByCurrentUser: !wasReposted
                    )
                }
                Task { @MainActor in
                    do {
                        try await service.toggleRepost(postId: currentPost.id, userId: userId)
                    } catch {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            applyPostUpdate(
                                repostDelta: wasReposted ? 1 : -1,
                                isRepostedByCurrentUser: wasReposted
                            )
                        }
                    }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        repostAnimating = false
                    }
                    pendingRepostUpdate = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.2.squarepath")
                        .scaleEffect(repostAnimating ? 1.15 : 1.0)
                    Text("\(repostCount)")
                }
                .font(.subheadline)
                    .foregroundColor(isRepostedByCurrentUser ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                guard let userId = authService.activeUserId else { return }
                let wasLiked = isLikedByCurrentUser
                pendingLikeUpdate = true
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    likeAnimating = true
                    applyPostUpdate(
                        likeDelta: wasLiked ? -1 : 1,
                        isLikedByCurrentUser: !wasLiked
                    )
                }
                Task { @MainActor in
                    do {
                        try await service.toggleLike(postId: currentPost.id, userId: userId)
                    } catch {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            applyPostUpdate(
                                likeDelta: wasLiked ? 1 : -1,
                                isLikedByCurrentUser: wasLiked
                            )
                        }
                    }
                    likeAnimating = false
                    pendingLikeUpdate = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isLikedByCurrentUser ? "heart.fill" : "heart")
                    Text("\(likeCount)")
                }
                .font(.subheadline)
                    .foregroundColor(isLikedByCurrentUser ? .red : .secondary)
                    .scaleEffect(likeAnimating ? 1.2 : 1.0)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                guard let userId = authService.activeUserId else { return }
                let wasBookmarked = isBookmarkedByCurrentUser
                pendingBookmarkUpdate = true
                withAnimation(.easeInOut(duration: 0.15)) {
                    bookmarkAnimating = true
                    applyPostUpdate(isBookmarkedByCurrentUser: !wasBookmarked)
                }
                Task { @MainActor in
                    do {
                        try await service.toggleBookmark(postId: currentPost.id, userId: userId)
                    } catch {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            applyPostUpdate(isBookmarkedByCurrentUser: wasBookmarked)
                        }
                    }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        bookmarkAnimating = false
                    }
                    pendingBookmarkUpdate = false
                }
            } label: {
                Image(systemName: isBookmarkedByCurrentUser ? "bookmark.fill" : "bookmark")
                    .font(.subheadline)
                    .foregroundColor(isBookmarkedByCurrentUser ? .blue : .secondary)
                    .scaleEffect(bookmarkAnimating ? 1.15 : 1.0)
            }
            .buttonStyle(.plain)

            Spacer()

            ShareLink(item: currentPost.post.body) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Replies Section

    private var repliesSection: some View {
        Group {
            if service.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else if service.replies.isEmpty {
                Text("No replies yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(service.replies) { reply in
                        HangerTalkPostCard(
                            postWithAuthor: reply,
                            onLike: {
                                guard let userId = authService.activeUserId else { return }
                                Task {
                                    try? await service.toggleLike(postId: reply.id, userId: userId)
                                    await service.fetchReplies(parentPostId: currentPost.id, currentUserId: userId)
                                }
                            },
                            onRepost: {
                                guard let userId = authService.activeUserId else { return }
                                Task {
                                    try? await service.toggleRepost(postId: reply.id, userId: userId)
                                    await service.fetchReplies(parentPostId: currentPost.id, currentUserId: userId)
                                }
                            },
                            onBookmark: {
                                guard let userId = authService.activeUserId else { return }
                                Task {
                                    try? await service.toggleBookmark(postId: reply.id, userId: userId)
                                    await service.fetchReplies(parentPostId: currentPost.id, currentUserId: userId)
                                }
                            },
                            onReply: {
                                showComposeReply = true
                            },
                            isOwnPost: reply.post.authorId == authService.activeUserId,
                            onDelete: {
                                guard let userId = authService.activeUserId else { return }
                                Task {
                                    try? await service.deletePost(postId: reply.id)
                                    await refreshCurrentPost(currentUserId: userId)
                                    await service.fetchReplies(parentPostId: currentPost.id, currentUserId: userId)
                                }
                            },
                            onAuthorTap: {
                                navigateToProfileId = reply.post.authorId
                            },
                            onMentionTap: { callSign in
                                Task {
                                    if let profile = await service.resolveCallSign(callSign) {
                                        navigateToProfileId = profile.id
                                    }
                                }
                            },
                            onFollow: {
                                guard let userId = authService.activeUserId else { return }
                                Task {
                                    _ = try? await service.toggleFollow(followerId: userId, followingId: reply.post.authorId)
                                    await service.fetchReplies(parentPostId: currentPost.id, currentUserId: userId)
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private var authorHandle: String {
        let normalized = (currentPost.authorCallSign ?? "pilot")
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        return "@\(normalized)"
    }

    private func authorAvatar(size: CGFloat) -> some View {
        Group {
            if let urlString = currentPost.authorProfilePictureUrl,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func refreshCurrentPost(currentUserId: UUID) async {
        if let updatedPost = await service.fetchPost(postId: currentPost.id, currentUserId: currentUserId) {
            currentPost = updatedPost
            syncInteractionStateFromCurrentPost()
        }
    }

    private func applyPostUpdate(
        likeDelta: Int = 0,
        replyDelta: Int = 0,
        repostDelta: Int = 0,
        isLikedByCurrentUser: Bool? = nil,
        isRepostedByCurrentUser: Bool? = nil,
        isBookmarkedByCurrentUser: Bool? = nil
    ) {
        likeCount = max(0, likeCount + likeDelta)
        replyCount = max(0, replyCount + replyDelta)
        repostCount = max(0, repostCount + repostDelta)
        if let isLikedByCurrentUser {
            self.isLikedByCurrentUser = isLikedByCurrentUser
        }
        if let isRepostedByCurrentUser {
            self.isRepostedByCurrentUser = isRepostedByCurrentUser
        }
        if let isBookmarkedByCurrentUser {
            self.isBookmarkedByCurrentUser = isBookmarkedByCurrentUser
        }
        syncCurrentPostFromInteractionState()
    }

    private func refreshDetail() async {
        guard let userId = authService.activeUserId else { return }
        await refreshCurrentPost(currentUserId: userId)
        await service.fetchReplies(parentPostId: currentPost.id, currentUserId: userId)
    }

    private func syncInteractionStateFromCurrentPost() {
        if !pendingLikeUpdate {
            likeCount = currentPost.post.likeCount
            isLikedByCurrentUser = currentPost.isLikedByCurrentUser
        }
        if !pendingReplyUpdate {
            replyCount = currentPost.post.replyCount
        }
        if !pendingRepostUpdate {
            repostCount = currentPost.post.repostCount
            isRepostedByCurrentUser = currentPost.isRepostedByCurrentUser
        }
        if !pendingBookmarkUpdate {
            isBookmarkedByCurrentUser = currentPost.isBookmarkedByCurrentUser
        }
        syncCurrentPostFromInteractionState()
    }

    private func syncCurrentPostFromInteractionState() {
        let post = currentPost.post
        let updatedPost = HangerTalkPost(
            id: post.id,
            authorId: post.authorId,
            body: post.body,
            imageUrls: post.imageUrls,
            likeCount: likeCount,
            replyCount: replyCount,
            repostCount: repostCount,
            isReply: post.isReply,
            parentPostId: post.parentPostId,
            createdAt: post.createdAt,
            updatedAt: post.updatedAt
        )

        currentPost = HangerTalkPostWithAuthor(
            id: currentPost.id,
            post: updatedPost,
            authorCallSign: currentPost.authorCallSign,
            authorProfilePictureUrl: currentPost.authorProfilePictureUrl,
            authorFullName: currentPost.authorFullName,
            isLikedByCurrentUser: isLikedByCurrentUser,
            isRepostedByCurrentUser: isRepostedByCurrentUser,
            isBookmarkedByCurrentUser: isBookmarkedByCurrentUser,
            isFollowedByCurrentUser: currentPost.isFollowedByCurrentUser
        )
    }
}
