//
//  HangerTalkView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/8/26.
//

import SwiftUI

struct HangerTalkView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var service = HangerTalkService()
    @State private var selectedTab: HangerTalkFeedTab = .forYou
    @State private var showCompose = false
    @State private var showDeletePostConfirmation = false
    @State private var postToDelete: HangerTalkPostWithAuthor?
    @State private var showSearch = false
    @State private var showEditPost = false
    @State private var postToEdit: HangerTalkPostWithAuthor?
    @State private var postToReply: HangerTalkPostWithAuthor?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Tab Bar
                feedTabBar

                Divider()

                // Content
                ScrollView {
                    switch selectedTab {
                    case .forYou:
                        feedSection(posts: service.feedPosts)
                    case .liked:
                        feedSection(posts: service.likedPosts)
                    case .bookmarks:
                        feedSection(posts: service.bookmarkedPosts)
                    }
                }
                .refreshable {
                    await refreshCurrentTab()
                }
            }

            // Floating compose button
            composeButton
        }
        .navigationTitle("Hanger Talk")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showSearch) {
            NavigationView {
                HangerTalkSearchView()
                    .environmentObject(authService)
            }
        }
        .sheet(isPresented: $showCompose) {
            NavigationView {
                HangerTalkComposeView(
                    onPostCreated: {
                        showCompose = false
                        Task {
                            guard let userId = authService.activeUserId else { return }
                            await service.fetchFeed(currentUserId: userId)
                        }
                    }
                )
                .environmentObject(authService)
            }
        }
        .sheet(isPresented: $showEditPost) {
            if let post = postToEdit {
                NavigationView {
                    HangerTalkEditView(
                        postWithAuthor: post,
                        onPostUpdated: {
                            showEditPost = false
                            postToEdit = nil
                            Task { await refreshCurrentTab() }
                        }
                    )
                    .environmentObject(authService)
                }
            }
        }
        .sheet(item: $postToReply) { post in
            NavigationView {
                HangerTalkComposeView(
                    replyToPost: post,
                    onPostCreated: {
                        postToReply = nil
                        Task { await refreshCurrentTab() }
                    }
                )
                .environmentObject(authService)
            }
        }
        .alert("Delete Post", isPresented: $showDeletePostConfirmation) {
            Button("Cancel", role: .cancel) {
                postToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let post = postToDelete {
                    Task {
                        try? await service.deletePost(postId: post.id)
                        guard let userId = authService.activeUserId else { return }
                        await refreshCurrentTab()
                    }
                }
                postToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
        .task {
            guard let userId = authService.activeUserId else { return }
            await service.fetchFeed(currentUserId: userId)
        }
        .onChange(of: selectedTab) { newTab in
            guard let userId = authService.activeUserId else { return }
            Task {
                switch newTab {
                case .forYou:
                    await service.fetchFeed(currentUserId: userId)
                case .liked:
                    await service.fetchLikedPosts(currentUserId: userId)
                case .bookmarks:
                    await service.fetchBookmarkedPosts(currentUserId: userId)
                }
            }
        }
    }

    // MARK: - Feed Tab Bar

    private var feedTabBar: some View {
        HStack(spacing: 0) {
            ForEach(HangerTalkFeedTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .bold : .regular)
                            .foregroundColor(selectedTab == tab ? .primary : .secondary)

                        Rectangle()
                            .fill(selectedTab == tab ? Color.blue : Color.clear)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Feed Section

    private func feedSection(posts: [HangerTalkPostWithAuthor]) -> some View {
        Group {
            if service.isLoading {
                ProgressView()
                    .padding(.top, 40)
            } else if posts.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(posts) { postWithAuthor in
                        NavigationLink(destination: HangerTalkPostDetailView(
                            postWithAuthor: postWithAuthor
                        ).environmentObject(authService)) {
                            HangerTalkPostCard(
                                postWithAuthor: postWithAuthor,
                                onLike: {
                                    guard let userId = authService.activeUserId else { return }
                                    Task {
                                        try? await service.toggleLike(postId: postWithAuthor.id, userId: userId)
                                        await refreshCurrentTab()
                                    }
                                },
                                onRepost: {
                                    guard let userId = authService.activeUserId else { return }
                                    Task {
                                        try? await service.toggleRepost(postId: postWithAuthor.id, userId: userId)
                                        await refreshCurrentTab()
                                    }
                                },
                                onBookmark: {
                                    guard let userId = authService.activeUserId else { return }
                                    Task {
                                        try? await service.toggleBookmark(postId: postWithAuthor.id, userId: userId)
                                        await refreshCurrentTab()
                                    }
                                },
                                onReply: {
                                    postToReply = postWithAuthor
                                },
                                isOwnPost: postWithAuthor.post.authorId == authService.activeUserId,
                                onDelete: {
                                    postToDelete = postWithAuthor
                                    showDeletePostConfirmation = true
                                },
                                onEdit: {
                                    postToEdit = postWithAuthor
                                    showEditPost = true
                                }
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(emptyStateTitle)
                .font(.headline)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    private var emptyStateIcon: String {
        switch selectedTab {
        case .forYou: return "text.bubble"
        case .liked: return "heart"
        case .bookmarks: return "bookmark"
        }
    }

    private var emptyStateTitle: String {
        switch selectedTab {
        case .forYou: return "No Posts Yet"
        case .liked: return "No Liked Posts"
        case .bookmarks: return "No Bookmarks"
        }
    }

    private var emptyStateMessage: String {
        switch selectedTab {
        case .forYou: return "Be the first to share something with the pilot community!"
        case .liked: return "Posts you like will appear here."
        case .bookmarks: return "Save posts to find them here later."
        }
    }

    // MARK: - Compose Button (FAB)

    private var composeButton: some View {
        Button {
            showCompose = true
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Refresh

    private func refreshCurrentTab() async {
        guard let userId = authService.activeUserId else { return }
        switch selectedTab {
        case .forYou:
            await service.fetchFeed(currentUserId: userId)
        case .liked:
            await service.fetchLikedPosts(currentUserId: userId)
        case .bookmarks:
            await service.fetchBookmarkedPosts(currentUserId: userId)
        }
    }
}
