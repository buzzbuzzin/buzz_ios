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
    @State private var navigateToProfileId: UUID?
    @State private var selectedPostForDetail: HangerTalkPostWithAuthor?
    @State private var showInbox = false

    /// Optional post ID to navigate to on load (from push notification deep link)
    var deepLinkPostId: UUID? = nil
    /// Opens inbox on load when triggered by a follow-notification deep link.
    var deepLinkOpenInbox: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Tab Bar
                feedTabBar

                Divider()

                // Content
                feedList
            }

            // Floating action buttons
            floatingButtons
        }
        .background(
            ZStack {
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

                NavigationLink(
                    destination: Group {
                        if let selectedPost = selectedPostForDetail {
                            HangerTalkPostDetailView(postWithAuthor: selectedPost)
                                .environmentObject(authService)
                        }
                    },
                    isActive: Binding(
                        get: { selectedPostForDetail != nil },
                        set: { if !$0 { selectedPostForDetail = nil } }
                    )
                ) { EmptyView() }
                    .hidden()
            }
        )
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
        .sheet(isPresented: $showInbox, onDismiss: {
            Task {
                guard let userId = authService.activeUserId else { return }
                await service.fetchUnreadCount(userId: userId)
            }
        }) {
            HangerTalkInboxView(service: service)
                .environmentObject(authService)
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
            await service.fetchUnreadCount(userId: userId)

            // If opened via deep link with a specific post, fetch and navigate to it
            if let postId = deepLinkPostId {
                if let post = await service.fetchPost(postId: postId, currentUserId: userId) {
                    selectedPostForDetail = post
                }
            } else if deepLinkOpenInbox {
                showInbox = true
            }

            // Poll for new notifications every 30 seconds
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
                await service.fetchUnreadCount(userId: userId)
            }
        }
        .onChange(of: selectedTab) { newTab in
            guard let userId = authService.activeUserId else { return }
            Task {
                switch newTab {
                case .forYou:
                    await service.fetchFeed(currentUserId: userId)
                case .following:
                    await service.fetchFollowingFeed(currentUserId: userId)
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

    // MARK: - Feed List

    private var currentPosts: [HangerTalkPostWithAuthor] {
        switch selectedTab {
        case .forYou: return service.feedPosts
        case .following: return service.followingPosts
        case .liked: return service.likedPosts
        case .bookmarks: return service.bookmarkedPosts
        }
    }

    private var feedList: some View {
        Group {
            if service.isLoading && currentPosts.isEmpty {
                ProgressView()
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if currentPosts.isEmpty {
                ScrollView {
                    emptyState
                }
            } else {
                List {
                    ForEach(currentPosts) { postWithAuthor in
                        HangerTalkPostCard(
                            postWithAuthor: postWithAuthor,
                            onLike: {
                                guard let userId = authService.activeUserId else { return }
                                Task {
                                    try? await service.toggleLike(postId: postWithAuthor.id, userId: userId)
                                    if selectedTab == .liked {
                                        await refreshCurrentTab()
                                    }
                                }
                            },
                            onRepost: {
                                guard let userId = authService.activeUserId else { return }
                                Task {
                                    try? await service.toggleRepost(postId: postWithAuthor.id, userId: userId)
                                }
                            },
                            onBookmark: {
                                guard let userId = authService.activeUserId else { return }
                                Task {
                                    try? await service.toggleBookmark(postId: postWithAuthor.id, userId: userId)
                                    if selectedTab == .bookmarks {
                                        await refreshCurrentTab()
                                    }
                                }
                            },
                            onReply: {
                                postToReply = postWithAuthor
                            },
                            onPostTap: {
                                selectedPostForDetail = postWithAuthor
                            },
                            isOwnPost: postWithAuthor.post.authorId == authService.activeUserId,
                            onDelete: {
                                postToDelete = postWithAuthor
                                showDeletePostConfirmation = true
                            },
                            onEdit: {
                                postToEdit = postWithAuthor
                                showEditPost = true
                            },
                            onAuthorTap: {
                                navigateToProfileId = postWithAuthor.post.authorId
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
                                    _ = try? await service.toggleFollow(followerId: userId, followingId: postWithAuthor.post.authorId)
                                    await refreshCurrentTab()
                                }
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await refreshCurrentTab()
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
        case .following: return "person.2"
        case .liked: return "heart"
        case .bookmarks: return "bookmark"
        }
    }

    private var emptyStateTitle: String {
        switch selectedTab {
        case .forYou: return "No Posts Yet"
        case .following: return "No Posts from Followed Pilots"
        case .liked: return "No Liked Posts"
        case .bookmarks: return "No Bookmarks"
        }
    }

    private var emptyStateMessage: String {
        switch selectedTab {
        case .forYou: return "Be the first to share something with the pilot community!"
        case .following: return "Follow pilots to see their posts here."
        case .liked: return "Posts you like will appear here."
        case .bookmarks: return "Save posts to find them here later."
        }
    }

    // MARK: - Floating Action Buttons

    private var floatingButtons: some View {
        VStack(spacing: 12) {
            inboxButton
            composeButton
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    private var inboxButton: some View {
        Button {
            showInbox = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(width: 56, height: 56)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)

                if service.unreadCount > 0 {
                    Text(service.unreadCount > 99 ? "99+" : "\(service.unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 4, y: -4)
                }
            }
        }
    }

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
    }

    // MARK: - Refresh

    private func refreshCurrentTab() async {
        guard let userId = authService.activeUserId else { return }
        switch selectedTab {
        case .forYou:
            await service.fetchFeed(currentUserId: userId)
        case .following:
            await service.fetchFollowingFeed(currentUserId: userId)
        case .liked:
            await service.fetchLikedPosts(currentUserId: userId)
        case .bookmarks:
            await service.fetchBookmarkedPosts(currentUserId: userId)
        }
        await service.fetchUnreadCount(userId: userId)
    }
}
