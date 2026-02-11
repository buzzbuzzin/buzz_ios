//
//  PilotPostsListView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/9/26.
//

import SwiftUI
import Auth

struct PilotPostsListView: View {
    let pilotId: UUID
    @EnvironmentObject var authService: AuthService
    @StateObject private var hangerTalkService = HangerTalkService()

    @State private var posts: [HangerTalkPostWithAuthor] = []
    @State private var isLoading = false
    @State private var navigateToProfileId: UUID?
    @State private var selectedPostForDetail: HangerTalkPostWithAuthor?

    var body: some View {
        ZStack {
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

            ScrollView {
                if isLoading && posts.isEmpty {
                    ProgressView()
                        .padding(.top, 40)
                } else if posts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No Posts Yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(posts) { postWithAuthor in
                            HangerTalkPostCard(
                                postWithAuthor: postWithAuthor,
                                onLike: {
                                    guard let userId = authService.activeUserId else { return }
                                    Task {
                                        try? await hangerTalkService.toggleLike(postId: postWithAuthor.id, userId: userId)
                                        await refreshPosts()
                                    }
                                },
                                onRepost: {
                                    guard let userId = authService.activeUserId else { return }
                                    Task {
                                        try? await hangerTalkService.toggleRepost(postId: postWithAuthor.id, userId: userId)
                                        await refreshPosts()
                                    }
                                },
                                onBookmark: {
                                    guard let userId = authService.activeUserId else { return }
                                    Task {
                                        try? await hangerTalkService.toggleBookmark(postId: postWithAuthor.id, userId: userId)
                                        await refreshPosts()
                                    }
                                },
                                onReply: {},
                                onPostTap: {
                                    selectedPostForDetail = postWithAuthor
                                },
                                isOwnPost: postWithAuthor.post.authorId == authService.activeUserId,
                                onAuthorTap: {
                                    navigateToProfileId = postWithAuthor.post.authorId
                                },
                                onMentionTap: { callSign in
                                    Task {
                                        if let profile = await hangerTalkService.resolveCallSign(callSign) {
                                            navigateToProfileId = profile.id
                                        }
                                    }
                                },
                                onFollow: {
                                    guard let userId = authService.activeUserId else { return }
                                    Task {
                                        _ = try? await hangerTalkService.toggleFollow(followerId: userId, followingId: postWithAuthor.post.authorId)
                                        await refreshPosts()
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .refreshable {
                await refreshPosts()
            }
        }
        .navigationTitle("Posts")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await refreshPosts()
        }
    }

    private func refreshPosts() async {
        isLoading = true
        let currentUserId = authService.currentUser?.id ?? UUID()
        posts = await hangerTalkService.fetchUserPosts(authorId: pilotId, currentUserId: currentUserId)
        isLoading = false
    }
}
