//
//  HangarTopicDetailView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/7/26.
//

import SwiftUI

struct HangarTopicDetailView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var hangarService = HangarHelpService()
    let topic: HangarTopic
    @State private var showNewPost = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if hangarService.isLoading {
                    ProgressView()
                        .padding(.top, 50)
                } else if hangarService.posts.isEmpty {
                    EmptyStateView(
                        icon: "text.bubble",
                        title: "No Posts Yet",
                        message: "Be the first to start a discussion in \(topic.name)!",
                        actionTitle: "Create Post",
                        action: { showNewPost = true }
                    )
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(hangarService.posts) { postWithAuthor in
                            NavigationLink(destination: HangarPostDetailView(
                                postWithAuthor: postWithAuthor,
                                topicName: topic.name
                            ).environmentObject(authService)) {
                                HangarPostCard(postWithAuthor: postWithAuthor, onLike: {
                                    guard let userId = authService.activeUserId else { return }
                                    Task {
                                        try? await hangarService.togglePostLike(postId: postWithAuthor.id, userId: userId)
                                        await hangarService.fetchPosts(topicId: topic.id, currentUserId: userId)
                                    }
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
                HangarNewPostView(topics: [topic], preselectedTopicId: topic.id, onPostCreated: {
                    showNewPost = false
                    Task {
                        guard let userId = authService.activeUserId else { return }
                        await hangarService.fetchPosts(topicId: topic.id, currentUserId: userId)
                    }
                })
                .environmentObject(authService)
            }
        }
        .task {
            guard let userId = authService.activeUserId else { return }
            await hangarService.fetchPosts(topicId: topic.id, currentUserId: userId)
        }
        .refreshable {
            guard let userId = authService.activeUserId else { return }
            await hangarService.fetchPosts(topicId: topic.id, currentUserId: userId)
        }
    }
}

// MARK: - Post Card

struct HangarPostCard: View {
    let postWithAuthor: HangarPostWithAuthor
    let onLike: () -> Void

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
                    Text(postWithAuthor.authorCallSign ?? postWithAuthor.authorFullName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(hangarTimeAgo(postWithAuthor.post.createdAt))
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
                HangarImageCarousel(imageUrls: postWithAuthor.imageUrls, height: 200)
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

// MARK: - Image Carousel (shared component)

struct HangarImageCarousel: View {
    let imageUrls: [String]
    let height: CGFloat
    @State private var currentPage = 0

    var body: some View {
        if imageUrls.count == 1 {
            // Single image — no carousel
            singleImage(urlString: imageUrls[0])
        } else {
            // Multiple images — swipeable carousel
            ZStack(alignment: .topTrailing) {
                TabView(selection: $currentPage) {
                    ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, urlString in
                        carouselImage(urlString: urlString)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Counter badge
                Text("\(currentPage + 1) / \(imageUrls.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .padding(8)
            }
        }
    }

    private func singleImage(urlString: String) -> some View {
        Group {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: height)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        imagePlaceholder
                    case .empty:
                        imageLoading
                    @unknown default:
                        imageLoading
                    }
                }
            }
        }
    }

    private func carouselImage(urlString: String) -> some View {
        Group {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: height)
                            .clipped()
                    case .failure:
                        imagePlaceholder
                    case .empty:
                        imageLoading
                    @unknown default:
                        imageLoading
                    }
                }
            }
        }
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.2))
            .frame(height: height)
            .overlay(
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundColor(.secondary)
            )
    }

    private var imageLoading: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.1))
            .frame(height: height)
            .overlay(ProgressView())
    }
}
