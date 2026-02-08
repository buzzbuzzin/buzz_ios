//
//  HangarPostDetailView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/7/26.
//

import SwiftUI

// MARK: - Time Ago Helper

func hangarTimeAgo(_ date: Date) -> String {
    let seconds = Int(Date().timeIntervalSince(date))
    if seconds < 60 { return "Just Now" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h" }
    let days = hours / 24
    if days < 7 { return "\(days)d" }
    let weeks = days / 7
    if weeks < 4 { return "\(weeks)w" }
    let months = days / 30
    if months < 12 { return "\(months)mo" }
    let years = days / 365
    return "\(years)y"
}

struct HangarPostDetailView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @StateObject private var hangarService = HangarHelpService()
    let postWithAuthor: HangarPostWithAuthor
    let topicName: String
    @State private var replyText = ""
    @State private var replyingToComment: HangarCommentWithAuthor?
    @FocusState private var isReplyFocused: Bool
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var showDeleteCommentConfirmation = false
    @State private var commentToDelete: UUID?
    @State private var showEditCommentSheet = false
    @State private var commentToEdit: HangarCommentWithAuthor?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Full post content
                    postContentSection
                        .padding()

                    // Gray gap bar separator (Reddit-style)
                    Rectangle()
                        .fill(Color(.systemGroupedBackground))
                        .frame(height: 10)

                    // Comments section
                    commentsSection
                }
            }

            // Reply bar
            replyBar
        }
        .navigationTitle(topicName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        guard let userId = authService.activeUserId else { return }
                        Task {
                            try? await hangarService.toggleFollowPost(postId: postWithAuthor.id, userId: userId)
                        }
                    } label: {
                        if postWithAuthor.isFollowedByCurrentUser {
                            Label("Unfollow Post", systemImage: "bell.slash")
                        } else {
                            Label("Follow Post", systemImage: "bell")
                        }
                    }

                    Button {
                        guard let userId = authService.activeUserId else { return }
                        Task {
                            try? await hangarService.toggleSavePost(postId: postWithAuthor.id, userId: userId)
                        }
                    } label: {
                        if postWithAuthor.isSavedByCurrentUser {
                            Label("Unsave", systemImage: "bookmark.slash")
                        } else {
                            Label("Save", systemImage: "bookmark")
                        }
                    }

                    Button {
                        guard let userId = authService.activeUserId else { return }
                        Task {
                            try? await hangarService.toggleHidePost(postId: postWithAuthor.id, userId: userId)
                            dismiss()
                        }
                    } label: {
                        Label("Hide", systemImage: "eye.slash")
                    }

                    if postWithAuthor.post.authorId == authService.activeUserId {
                        Divider()

                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit Post", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Post", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
        }
        .alert("Delete Post", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    try? await hangarService.deletePost(postId: postWithAuthor.id)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationView {
                HangarEditPostView(
                    postId: postWithAuthor.id,
                    initialTitle: postWithAuthor.post.title,
                    initialBody: postWithAuthor.post.body
                )
                .environmentObject(authService)
            }
        }
        .alert("Delete Comment", isPresented: $showDeleteCommentConfirmation) {
            Button("Cancel", role: .cancel) {
                commentToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let commentId = commentToDelete {
                    Task {
                        try? await hangarService.deleteComment(commentId: commentId)
                        guard let userId = authService.activeUserId else { return }
                        await hangarService.fetchComments(postId: postWithAuthor.id, currentUserId: userId)
                    }
                }
                commentToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this comment? This action cannot be undone.")
        }
        .sheet(isPresented: $showEditCommentSheet) {
            if let editComment = commentToEdit {
                NavigationView {
                    HangarEditCommentView(
                        commentId: editComment.id,
                        initialBody: editComment.comment.body,
                        onSaved: {
                            showEditCommentSheet = false
                            commentToEdit = nil
                            Task {
                                guard let userId = authService.activeUserId else { return }
                                await hangarService.fetchComments(postId: postWithAuthor.id, currentUserId: userId)
                            }
                        }
                    )
                    .environmentObject(authService)
                }
            }
        }
        .task {
            guard let userId = authService.activeUserId else { return }
            await hangarService.fetchComments(postId: postWithAuthor.id, currentUserId: userId)
        }
        .refreshable {
            guard let userId = authService.activeUserId else { return }
            await hangarService.fetchComments(postId: postWithAuthor.id, currentUserId: userId)
        }
    }

    // MARK: - Post Content

    private var postContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author info
            HStack(spacing: 10) {
                if let urlString = postWithAuthor.authorProfilePictureUrl,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(postWithAuthor.authorCallSign ?? postWithAuthor.authorFullName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(hangarTimeAgo(postWithAuthor.post.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if postWithAuthor.post.isPinned {
                    HStack(spacing: 4) {
                        Image(systemName: "pin.fill")
                        Text("Pinned")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
            }

            // Title
            Text(postWithAuthor.post.title)
                .font(.title3)
                .fontWeight(.bold)

            // Body
            Text(postWithAuthor.post.body)
                .font(.body)
                .foregroundColor(.primary)

            // Like button
            HStack(spacing: 16) {
                Button {
                    guard let userId = authService.activeUserId else { return }
                    Task {
                        try? await hangarService.togglePostLike(postId: postWithAuthor.id, userId: userId)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: postWithAuthor.isLikedByCurrentUser ? "hand.thumbsup.fill" : "hand.thumbsup")
                        Text("\(postWithAuthor.post.likeCount)")
                    }
                    .font(.subheadline)
                    .foregroundColor(postWithAuthor.isLikedByCurrentUser ? .blue : .secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                    Text("\(postWithAuthor.post.commentCount)")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Comments Section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hangarService.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else if hangarService.comments.isEmpty {
                Text("No comments yet. Be the first to reply!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(hangarService.comments.enumerated()), id: \.element.id) { index, comment in
                    HangarCommentRow(
                        comment: comment,
                        currentUserId: authService.activeUserId,
                        onReply: {
                            replyingToComment = comment
                            isReplyFocused = true
                        },
                        onLike: {
                            guard let userId = authService.activeUserId else { return }
                            Task {
                                try? await hangarService.toggleCommentLike(commentId: comment.id, userId: userId)
                                await hangarService.fetchComments(postId: postWithAuthor.id, currentUserId: userId)
                            }
                        },
                        onSave: {
                            guard let userId = authService.activeUserId else { return }
                            Task {
                                try? await hangarService.toggleSaveComment(commentId: comment.id, userId: userId)
                                await hangarService.fetchComments(postId: postWithAuthor.id, currentUserId: userId)
                            }
                        },
                        onFollow: {
                            guard let userId = authService.activeUserId else { return }
                            Task {
                                try? await hangarService.toggleFollowComment(commentId: comment.id, userId: userId)
                                await hangarService.fetchComments(postId: postWithAuthor.id, currentUserId: userId)
                            }
                        },
                        onEdit: { commentToEdit in
                            self.commentToEdit = commentToEdit
                            showEditCommentSheet = true
                        },
                        onDelete: { commentId in
                            self.commentToDelete = commentId
                            showDeleteCommentConfirmation = true
                        }
                    )
                    .padding()

                    // Gray gap between comments (not after last one)
                    if index < hangarService.comments.count - 1 {
                        Rectangle()
                            .fill(Color(.systemGroupedBackground))
                            .frame(height: 8)
                    }
                }
            }
        }
    }

    // MARK: - Reply Bar

    private var replyBar: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 8) {
                if let replyingTo = replyingToComment {
                    HStack {
                        Text("Replying to \(replyingTo.authorCallSign ?? replyingTo.authorFullName)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button {
                            replyingToComment = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                HStack(spacing: 12) {
                    TextField("Write a reply...", text: $replyText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isReplyFocused)

                    Button {
                        Task { await submitReply() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    }
                    .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Submit Reply

    private func submitReply() async {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let userId = authService.activeUserId, !trimmed.isEmpty else { return }

        let parentId = replyingToComment?.id
        let depth = replyingToComment != nil ? min((replyingToComment?.comment.depth ?? 0) + 1, 3) : 0

        do {
            try await hangarService.createComment(
                postId: postWithAuthor.id,
                parentCommentId: parentId,
                authorId: userId,
                body: trimmed,
                depth: depth
            )
            replyText = ""
            replyingToComment = nil
            await hangarService.fetchComments(postId: postWithAuthor.id, currentUserId: userId)
        } catch {
            // Error is handled by the service's errorMessage
        }
    }
}

// MARK: - Comment Row (Recursive for threading)

struct HangarCommentRow: View {
    let comment: HangarCommentWithAuthor
    let currentUserId: UUID?
    let onReply: () -> Void
    let onLike: () -> Void
    let onSave: () -> Void
    let onFollow: () -> Void
    let onEdit: (HangarCommentWithAuthor) -> Void
    let onDelete: (UUID) -> Void

    private var isOwnComment: Bool {
        comment.comment.authorId == currentUserId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Author info
            HStack(spacing: 10) {
                if let urlString = comment.authorProfilePictureUrl,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.authorCallSign ?? comment.authorFullName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(hangarTimeAgo(comment.comment.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Comment body
            Text(comment.comment.body)
                .font(.body)

            // Actions — right-aligned
            HStack(spacing: 16) {
                Spacer()

                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: comment.isLikedByCurrentUser ? "hand.thumbsup.fill" : "hand.thumbsup")
                        Text("\(comment.comment.likeCount)")
                    }
                    .font(.subheadline)
                    .foregroundColor(comment.isLikedByCurrentUser ? .blue : .secondary)
                }

                Button(action: onReply) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.left")
                        Text("Reply")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                Menu {
                    Button(action: onSave) {
                        if comment.isSavedByCurrentUser {
                            Label("Unsave", systemImage: "bookmark.slash")
                        } else {
                            Label("Save", systemImage: "bookmark")
                        }
                    }

                    Button(action: onFollow) {
                        if comment.isFollowedByCurrentUser {
                            Label("Unfollow Comment", systemImage: "bell.slash")
                        } else {
                            Label("Follow Comment", systemImage: "bell")
                        }
                    }

                    if isOwnComment {
                        Divider()

                        Button {
                            onEdit(comment)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            onDelete(comment.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Nested replies
            if !comment.replies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(comment.replies) { reply in
                        HangarCommentRow(
                            comment: reply,
                            currentUserId: currentUserId,
                            onReply: onReply,
                            onLike: {
                                // Like action is passed through for nested comments
                            },
                            onSave: onSave,
                            onFollow: onFollow,
                            onEdit: onEdit,
                            onDelete: onDelete
                        )
                    }
                }
                .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
    }
}
