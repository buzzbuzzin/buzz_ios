//
//  HangerTalkView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/7/26.
//

import SwiftUI

// MARK: - View Mode

enum HangerViewMode: String, CaseIterable {
    case latest = "Latest"
    case mostLiked = "Most Liked"
    case saved = "Saved"
    case activity = "Activity"
}

struct HangerTalkView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var hangerService = HangerTalkService()
    @State private var viewMode: HangerViewMode = .latest
    @State private var selectedTopicId: UUID?
    @State private var showNewPost = false

    // MARK: - Filtered & Sorted Posts

    private var displayedPosts: [HangerPostWithAuthor] {
        var filtered = hangerService.posts

        // Filter out hidden posts
        filtered = filtered.filter { !hangerService.hiddenPostIds.contains($0.id) }

        // Filter by topic
        if let topicId = selectedTopicId {
            filtered = filtered.filter { $0.post.topicId == topicId }
        }

        // Sort
        switch viewMode {
        case .latest:
            return filtered.sorted { $0.post.createdAt > $1.post.createdAt }
        case .mostLiked:
            return filtered.sorted { $0.post.likeCount > $1.post.likeCount }
        default:
            return filtered
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // View Mode Tab Bar
                viewModeTabBar

                // Content based on view mode
                switch viewMode {
                case .latest, .mostLiked:
                    // Topic Filter Bar
                    topicFilterBar

                    // Posts Feed
                    postsFeedSection

                case .saved:
                    savedSection

                case .activity:
                    activitySection
                }
            }
            .padding(.bottom)
        }
        .navigationTitle("Hanger Talk")
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
                HangerNewPostView(
                    topics: hangerService.topics,
                    onPostCreated: {
                        showNewPost = false
                        Task {
                            guard let userId = authService.activeUserId else { return }
                            await hangerService.fetchAllPosts(currentUserId: userId)
                        }
                    }
                )
                .environmentObject(authService)
            }
        }
        .task {
            await hangerService.fetchTopics()
            guard let userId = authService.activeUserId else { return }
            await hangerService.fetchAllPosts(currentUserId: userId)
        }
        .onChange(of: viewMode) { newMode in
            guard let userId = authService.activeUserId else { return }
            Task {
                switch newMode {
                case .saved:
                    await hangerService.fetchSavedPosts(currentUserId: userId)
                    await hangerService.fetchSavedComments(currentUserId: userId)
                case .activity:
                    await hangerService.fetchActivityItems(currentUserId: userId)
                default:
                    break
                }
            }
        }
        .refreshable {
            guard let userId = authService.activeUserId else { return }
            switch viewMode {
            case .latest, .mostLiked:
                await hangerService.fetchTopics()
                await hangerService.fetchAllPosts(currentUserId: userId)
            case .saved:
                await hangerService.fetchSavedPosts(currentUserId: userId)
                await hangerService.fetchSavedComments(currentUserId: userId)
            case .activity:
                await hangerService.fetchActivityItems(currentUserId: userId)
            }
        }
    }

    // MARK: - View Mode Tab Bar

    private var viewModeTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HangerViewMode.allCases, id: \.self) { mode in
                    Button {
                        viewMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(viewMode == mode ? Color.mint.opacity(0.2) : Color(.tertiarySystemBackground))
                            .foregroundColor(viewMode == mode ? .mint : .secondary)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(viewMode == mode ? Color.mint.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Posts Feed Section

    private var postsFeedSection: some View {
        Group {
            if hangerService.isLoading {
                ProgressView()
                    .padding(.top, 40)
            } else if displayedPosts.isEmpty {
                EmptyStateView(
                    icon: "text.bubble",
                    title: "No Posts Yet",
                    message: selectedTopicId != nil
                        ? "No posts in this topic yet. Be the first!"
                        : "Start a discussion with fellow pilots!"
                )
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(displayedPosts) { postWithAuthor in
                        NavigationLink(destination: HangerPostDetailView(
                            postWithAuthor: postWithAuthor,
                            topicName: postWithAuthor.topicName
                        ).environmentObject(authService)) {
                            HangerPostCard(postWithAuthor: postWithAuthor, onLike: {
                                guard let userId = authService.activeUserId else { return }
                                Task {
                                    try? await hangerService.togglePostLike(postId: postWithAuthor.id, userId: userId)
                                    await hangerService.fetchAllPosts(currentUserId: userId)
                                }
                            })
                        }
                        .buttonStyle(PlainButtonStyle())

                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Saved Section

    private var savedSection: some View {
        Group {
            if hangerService.savedPosts.isEmpty && hangerService.savedComments.isEmpty {
                EmptyStateView(
                    icon: "bookmark",
                    title: "No Saved Items",
                    message: "Save posts and comments to find them here later."
                )
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    // Saved Posts
                    if !hangerService.savedPosts.isEmpty {
                        Text("Saved Posts")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVStack(spacing: 0) {
                            ForEach(hangerService.savedPosts) { postWithAuthor in
                                NavigationLink(destination: HangerPostDetailView(
                                    postWithAuthor: postWithAuthor,
                                    topicName: postWithAuthor.topicName
                                ).environmentObject(authService)) {
                                    HangerPostCard(postWithAuthor: postWithAuthor, onLike: {
                                        guard let userId = authService.activeUserId else { return }
                                        Task {
                                            try? await hangerService.togglePostLike(postId: postWithAuthor.id, userId: userId)
                                            await hangerService.fetchSavedPosts(currentUserId: userId)
                                        }
                                    })
                                }
                                .buttonStyle(PlainButtonStyle())

                                Divider()
                            }
                        }
                    }

                    // Saved Comments
                    if !hangerService.savedComments.isEmpty {
                        Text("Saved Comments")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVStack(spacing: 8) {
                            ForEach(hangerService.savedComments) { commentWithAuthor in
                                HangerSavedCommentCard(commentWithAuthor: commentWithAuthor)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        Group {
            if hangerService.activityItems.isEmpty {
                EmptyStateView(
                    icon: "bell",
                    title: "No Activity Yet",
                    message: "Follow posts and comments to see new activity here."
                )
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(hangerService.activityItems) { item in
                        NavigationLink(destination: activityDestination(for: item)) {
                            HangerActivityItemCard(item: item)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
        }
    }

    private func activityDestination(for item: HangerActivityItem) -> some View {
        // Navigate to the post detail
        let dummyPost = HangerPostWithAuthor(
            id: item.postId,
            post: HangerPost(
                id: item.postId,
                topicId: UUID(),
                authorId: UUID(),
                title: item.postTitle,
                body: "",
                likeCount: 0,
                commentCount: 0,
                isPinned: false,
                createdAt: Date(),
                updatedAt: Date()
            ),
            authorCallSign: nil,
            authorProfilePictureUrl: nil,
            authorFullName: "",
            isLikedByCurrentUser: false,
            isSavedByCurrentUser: false,
            isFollowedByCurrentUser: false,
            topicName: "",
            topicIconName: "bubble.left.and.bubble.right.fill",
            topicColorName: "green",
            imageUrls: []
        )
        return HangerPostDetailView(
            postWithAuthor: dummyPost,
            topicName: ""
        ).environmentObject(authService)
    }

    // MARK: - Topic Filter Bar

    private var topicFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" pill
                TopicFilterPill(
                    name: "All",
                    iconName: "list.bullet",
                    colorName: "gray",
                    isSelected: selectedTopicId == nil,
                    action: { selectedTopicId = nil }
                )

                // Topic pills
                ForEach(hangerService.topics) { topic in
                    TopicFilterPill(
                        name: topic.name,
                        iconName: topic.iconName,
                        colorName: topic.colorName,
                        isSelected: selectedTopicId == topic.id,
                        action: {
                            if selectedTopicId == topic.id {
                                selectedTopicId = nil // Deselect
                            } else {
                                selectedTopicId = topic.id
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Saved Comment Card

struct HangerSavedCommentCard: View {
    let commentWithAuthor: HangerCommentWithAuthor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Author row
            HStack(spacing: 8) {
                if let urlString = commentWithAuthor.authorProfilePictureUrl,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(commentWithAuthor.authorCallSign ?? commentWithAuthor.authorFullName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(hangerTimeAgo(commentWithAuthor.comment.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "bookmark.fill")
                    .font(.caption)
                    .foregroundColor(.mint)
            }

            // Comment body
            Text(commentWithAuthor.comment.body)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            // Stats
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup")
                        .font(.caption2)
                    Text("\(commentWithAuthor.comment.likeCount)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Activity Item Card

struct HangerActivityItemCard: View {
    let item: HangerActivityItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Author avatar
            if let urlString = item.commentAuthorProfilePictureUrl,
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

            VStack(alignment: .leading, spacing: 4) {
                // Activity description
                Group {
                    switch item.type {
                    case .newCommentOnFollowedPost:
                        Text("\(item.commentAuthorCallSign ?? item.commentAuthorName) ")
                            .fontWeight(.semibold) +
                        Text("commented on ") +
                        Text(item.postTitle)
                            .fontWeight(.semibold)
                    case .replyToFollowedComment:
                        Text("\(item.commentAuthorCallSign ?? item.commentAuthorName) ")
                            .fontWeight(.semibold) +
                        Text("replied on ") +
                        Text(item.postTitle)
                            .fontWeight(.semibold)
                    }
                }
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)

                // Comment body preview
                Text(item.commentBody)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Timestamp
                Text(hangerTimeAgo(item.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// MARK: - Topic Filter Pill

struct TopicFilterPill: View {
    let name: String
    let iconName: String
    let colorName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 12))
                Text(name)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? colorForName(colorName).opacity(0.2)
                    : Color(.tertiarySystemBackground)
            )
            .foregroundColor(
                isSelected
                    ? colorForName(colorName)
                    : .secondary
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected
                            ? colorForName(colorName).opacity(0.5)
                            : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "orange": return .orange
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "red": return .red
        case "green": return .green
        case "mint": return .mint
        case "gray": return .gray
        default: return .gray
        }
    }
}
