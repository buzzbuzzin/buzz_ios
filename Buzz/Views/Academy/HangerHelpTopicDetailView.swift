//
//  HangerHelpTopicDetailView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/7/26.
//

import SwiftUI

struct HangerHelpTopicDetailView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var hangerService = HangerHelpService()
    let topic: HangerTopic
    @State private var showNewPost = false
    @State private var menuPost: HangerPostWithAuthor?
    @State private var showDeletePostConfirmation = false
    @State private var showEditPostSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if hangerService.isLoading {
                    ProgressView()
                        .padding(.top, 50)
                } else if hangerService.posts.isEmpty {
                    EmptyStateView(
                        icon: "text.bubble",
                        title: "No Posts Yet",
                        message: "Be the first to start a discussion in \(topic.name)!",
                        actionTitle: "Create Post",
                        action: { showNewPost = true }
                    )
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(hangerService.posts) { postWithAuthor in
                            NavigationLink(destination: HangerHelpPostDetailView(
                                postWithAuthor: postWithAuthor,
                                topicName: topic.name
                            ).environmentObject(authService)) {
                                HangerHelpPostCard(postWithAuthor: postWithAuthor, onLike: {
                                    guard let userId = authService.activeUserId else { return }
                                    Task {
                                        try? await hangerService.togglePostLike(postId: postWithAuthor.id, userId: userId)
                                        await hangerService.fetchPosts(topicId: topic.id, currentUserId: userId)
                                    }
                                }, isOwnPost: postWithAuthor.post.authorId == authService.activeUserId, onFollow: {
                                    guard let userId = authService.activeUserId else { return }
                                    Task {
                                        try? await hangerService.toggleFollowPost(postId: postWithAuthor.id, userId: userId)
                                        await hangerService.fetchPosts(topicId: topic.id, currentUserId: userId)
                                    }
                                }, onSave: {
                                    guard let userId = authService.activeUserId else { return }
                                    Task {
                                        try? await hangerService.toggleSavePost(postId: postWithAuthor.id, userId: userId)
                                        await hangerService.fetchPosts(topicId: topic.id, currentUserId: userId)
                                    }
                                }, onHide: {
                                    guard let userId = authService.activeUserId else { return }
                                    Task {
                                        try? await hangerService.toggleHidePost(postId: postWithAuthor.id, userId: userId)
                                        await hangerService.fetchPosts(topicId: topic.id, currentUserId: userId)
                                    }
                                }, onEdit: {
                                    menuPost = postWithAuthor
                                    showEditPostSheet = true
                                }, onDelete: {
                                    menuPost = postWithAuthor
                                    showDeletePostConfirmation = true
                                })
                            }
                            .buttonStyle(PlainButtonStyle())

                            Divider()
                        }
                    }
                }
            }
            .padding(.bottom)
        }
        .navigationTitle(topic.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNewPost = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
        }
        .sheet(isPresented: $showNewPost) {
            NavigationView {
                HangerHelpNewPostView(topics: [topic], preselectedTopicId: topic.id, onPostCreated: {
                    showNewPost = false
                    Task {
                        guard let userId = authService.activeUserId else { return }
                        await hangerService.fetchPosts(topicId: topic.id, currentUserId: userId)
                    }
                })
                .environmentObject(authService)
            }
        }
        .task {
            guard let userId = authService.activeUserId else { return }
            await hangerService.fetchPosts(topicId: topic.id, currentUserId: userId)
        }
        .refreshable {
            guard let userId = authService.activeUserId else { return }
            await hangerService.fetchPosts(topicId: topic.id, currentUserId: userId)
        }
        .alert("Delete Post", isPresented: $showDeletePostConfirmation) {
            Button("Cancel", role: .cancel) {
                menuPost = nil
            }
            Button("Delete", role: .destructive) {
                if let post = menuPost {
                    Task {
                        try? await hangerService.deletePost(postId: post.id)
                        guard let userId = authService.activeUserId else { return }
                        await hangerService.fetchPosts(topicId: topic.id, currentUserId: userId)
                    }
                }
                menuPost = nil
            }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
        .sheet(isPresented: $showEditPostSheet) {
            if let post = menuPost {
                NavigationView {
                    HangerHelpEditPostView(
                        postId: post.id,
                        initialTitle: post.post.title,
                        initialBody: post.post.body,
                        initialImageUrls: post.imageUrls
                    )
                    .environmentObject(authService)
                }
            }
        }
    }
}

// MARK: - Post Card

struct HangerHelpPostCard: View {
    let postWithAuthor: HangerPostWithAuthor
    let onLike: () -> Void
    var isOwnPost: Bool = false
    var onFollow: (() -> Void)?
    var onSave: (() -> Void)?
    var onHide: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Topic badge
            HStack(spacing: 4) {
                Image(systemName: postWithAuthor.topicIconName)
                    .font(.system(size: 10))
                Text(postWithAuthor.topicName)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(topicColor.opacity(0.12))
            .foregroundColor(topicColor)
            .cornerRadius(12)

            // Author info row
            HStack(spacing: 8) {
                if let urlString = postWithAuthor.authorProfilePictureUrl,
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
                    Text(postWithAuthor.authorCallSign ?? "Pilot")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(hangerTimeAgo(postWithAuthor.post.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if postWithAuthor.post.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }

            // Title
            Text(postWithAuthor.post.title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Body preview
            if !postWithAuthor.post.body.isEmpty {
                Text(postWithAuthor.post.body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            // Image carousel
            if !postWithAuthor.imageUrls.isEmpty {
                HangerImageCarousel(imageUrls: postWithAuthor.imageUrls, height: 200)
            }

            // Stats row
            HStack(spacing: 16) {
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: postWithAuthor.isLikedByCurrentUser ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .foregroundColor(postWithAuthor.isLikedByCurrentUser ? .blue : .secondary)
                        Text("\(postWithAuthor.post.likeCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .foregroundColor(.secondary)
                    Text("\(postWithAuthor.post.commentCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if onFollow != nil || onSave != nil || onHide != nil {
                    Menu {
                        if let onFollow {
                            Button(action: onFollow) {
                                Label(
                                    postWithAuthor.isFollowedByCurrentUser ? "Unfollow Post" : "Follow Post",
                                    systemImage: postWithAuthor.isFollowedByCurrentUser ? "bell.slash" : "bell"
                                )
                            }
                        }

                        if let onSave {
                            Button(action: onSave) {
                                Label(
                                    postWithAuthor.isSavedByCurrentUser ? "Unsave" : "Save",
                                    systemImage: postWithAuthor.isSavedByCurrentUser ? "bookmark.slash" : "bookmark"
                                )
                            }
                        }

                        if let onHide {
                            Button(action: onHide) {
                                Label("Hide", systemImage: "eye.slash")
                            }
                        }

                        if isOwnPost {
                            Divider()

                            if let onEdit {
                                Button(action: onEdit) {
                                    Label("Edit Post", systemImage: "pencil")
                                }
                            }

                            if let onDelete {
                                Button(role: .destructive, action: onDelete) {
                                    Label("Delete Post", systemImage: "trash")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var topicColor: Color {
        switch postWithAuthor.topicColorName {
        case "blue": return .blue
        case "orange": return .orange
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "red": return .red
        case "green": return .green
        case "mint": return .mint
        default: return .gray
        }
    }
}

