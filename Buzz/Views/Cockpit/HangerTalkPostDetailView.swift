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
    let postWithAuthor: HangerTalkPostWithAuthor
    @State private var showComposeReply = false
    @State private var showDeleteConfirmation = false
    @State private var showEditPost = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Full post content (expanded)
                    postContentSection
                        .padding(16)

                    Divider()

                    // Stats bar
                    statsBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                    Divider()

                    // Action bar
                    postActionBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    // Gray separator
                    Rectangle()
                        .fill(Color(.systemGroupedBackground))
                        .frame(height: 8)

                    // Replies
                    repliesSection
                }
            }
            .refreshable {
                guard let userId = authService.activeUserId else { return }
                await service.fetchReplies(parentPostId: postWithAuthor.id, currentUserId: userId)
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if postWithAuthor.post.authorId == authService.activeUserId {
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
                    }
                }
            }
        }
        .alert("Delete Post", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    try? await service.deletePost(postId: postWithAuthor.id)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
        .sheet(isPresented: $showEditPost) {
            NavigationView {
                HangerTalkEditView(
                    postWithAuthor: postWithAuthor,
                    onPostUpdated: {
                        showEditPost = false
                        dismiss()
                    }
                )
                .environmentObject(authService)
            }
        }
        .sheet(isPresented: $showComposeReply) {
            NavigationView {
                HangerTalkComposeView(
                    replyToPost: postWithAuthor,
                    onPostCreated: {
                        showComposeReply = false
                        Task {
                            guard let userId = authService.activeUserId else { return }
                            await service.fetchReplies(parentPostId: postWithAuthor.id, currentUserId: userId)
                        }
                    }
                )
                .environmentObject(authService)
            }
        }
        .task {
            guard let userId = authService.activeUserId else { return }
            await service.fetchReplies(parentPostId: postWithAuthor.id, currentUserId: userId)
        }
    }

    // MARK: - Post Content Section

    private var postContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author row
            HStack(spacing: 10) {
                if let urlString = postWithAuthor.authorProfilePictureUrl,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(postWithAuthor.authorCallSign ?? postWithAuthor.authorFullName)
                        .font(.headline)
                        .fontWeight(.bold)

                    Text("@\((postWithAuthor.authorCallSign ?? postWithAuthor.authorFullName).lowercased().replacingOccurrences(of: " ", with: ""))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Body text (full size)
            Text(postWithAuthor.post.body)
                .font(.title3)

            // Image carousel
            if !postWithAuthor.post.imageUrls.isEmpty {
                HangerImageCarousel(imageUrls: postWithAuthor.post.imageUrls, height: 300)
            }

            // Timestamp
            Text(postWithAuthor.post.createdAt, style: .date)
                .font(.subheadline)
                .foregroundColor(.secondary)
            +
            Text(" · ")
                .font(.subheadline)
                .foregroundColor(.secondary)
            +
            Text(postWithAuthor.post.createdAt, style: .time)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 16) {
            if postWithAuthor.post.replyCount > 0 {
                HStack(spacing: 4) {
                    Text("\(postWithAuthor.post.replyCount)")
                        .fontWeight(.semibold)
                    Text(postWithAuthor.post.replyCount == 1 ? "Reply" : "Replies")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
            }

            if postWithAuthor.post.repostCount > 0 {
                HStack(spacing: 4) {
                    Text("\(postWithAuthor.post.repostCount)")
                        .fontWeight(.semibold)
                    Text(postWithAuthor.post.repostCount == 1 ? "Repost" : "Reposts")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
            }

            if postWithAuthor.post.likeCount > 0 {
                HStack(spacing: 4) {
                    Text("\(postWithAuthor.post.likeCount)")
                        .fontWeight(.semibold)
                    Text(postWithAuthor.post.likeCount == 1 ? "Like" : "Likes")
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
            // Reply
            Button {
                showComposeReply = true
            } label: {
                Image(systemName: "bubble.left")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Repost
            Button {
                guard let userId = authService.activeUserId else { return }
                Task { try? await service.toggleRepost(postId: postWithAuthor.id, userId: userId) }
            } label: {
                Image(systemName: "arrow.2.squarepath")
                    .font(.title3)
                    .foregroundColor(postWithAuthor.isRepostedByCurrentUser ? .green : .secondary)
            }

            Spacer()

            // Like
            Button {
                guard let userId = authService.activeUserId else { return }
                Task { try? await service.toggleLike(postId: postWithAuthor.id, userId: userId) }
            } label: {
                Image(systemName: postWithAuthor.isLikedByCurrentUser ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundColor(postWithAuthor.isLikedByCurrentUser ? .red : .secondary)
            }

            Spacer()

            // Bookmark
            Button {
                guard let userId = authService.activeUserId else { return }
                Task { try? await service.toggleBookmark(postId: postWithAuthor.id, userId: userId) }
            } label: {
                Image(systemName: postWithAuthor.isBookmarkedByCurrentUser ? "bookmark.fill" : "bookmark")
                    .font(.title3)
                    .foregroundColor(postWithAuthor.isBookmarkedByCurrentUser ? .blue : .secondary)
            }

            Spacer()

            // Share
            ShareLink(item: postWithAuthor.post.body) {
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
                    .padding(.vertical, 30)
            } else {
                ForEach(service.replies) { reply in
                    HangerTalkPostCard(
                        postWithAuthor: reply,
                        onLike: {
                            guard let userId = authService.activeUserId else { return }
                            Task {
                                try? await service.toggleLike(postId: reply.id, userId: userId)
                                await service.fetchReplies(parentPostId: postWithAuthor.id, currentUserId: userId)
                            }
                        },
                        onRepost: {
                            guard let userId = authService.activeUserId else { return }
                            Task {
                                try? await service.toggleRepost(postId: reply.id, userId: userId)
                                await service.fetchReplies(parentPostId: postWithAuthor.id, currentUserId: userId)
                            }
                        },
                        onBookmark: {
                            guard let userId = authService.activeUserId else { return }
                            Task {
                                try? await service.toggleBookmark(postId: reply.id, userId: userId)
                                await service.fetchReplies(parentPostId: postWithAuthor.id, currentUserId: userId)
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
                                await service.fetchReplies(parentPostId: postWithAuthor.id, currentUserId: userId)
                            }
                        }
                    )
                }
            }
        }
    }
}
