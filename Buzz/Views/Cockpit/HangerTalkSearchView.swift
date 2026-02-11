//
//  HangerTalkSearchView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/9/26.
//

import SwiftUI

struct HangerTalkSearchView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @StateObject private var service = HangerTalkService()

    @State private var searchText = ""
    @State private var searchResults: [HangerTalkPostWithAuthor] = []
    @State private var pilotResults: [HangerAuthorProfile] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var postToReply: HangerTalkPostWithAuthor?
    @State private var followedPilotIds: Set<UUID> = []
    @State private var navigateToProfileId: UUID?
    @State private var selectedPostForDetail: HangerTalkPostWithAuthor?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar

            Divider()

            // Results
            ScrollView {
                if isSearching {
                    ProgressView()
                        .padding(.top, 40)
                } else if !hasSearched {
                    emptyPrompt
                } else if pilotResults.isEmpty && searchResults.isEmpty {
                    noResultsView
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Pilot profiles section
                        if !pilotResults.isEmpty {
                            pilotResultsSection
                        }

                        // Posts section
                        if !searchResults.isEmpty {
                            postResults
                        }
                    }
                }
            }
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
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
        }
        .sheet(item: $postToReply) { post in
            NavigationView {
                HangerTalkComposeView(
                    replyToPost: post,
                    onPostCreated: {
                        postToReply = nil
                        performSearch()
                    }
                )
                .environmentObject(authService)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search posts or pilots...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                        pilotResults = []
                        hasSearched = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Empty Prompt

    private var emptyPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Search Hanger Talk")
                .font(.headline)

            Text("Find posts by keywords or search for pilot accounts.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    // MARK: - Post Results

    private var postResults: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Top posts")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            LazyVStack(spacing: 0) {
                ForEach(searchResults) { postWithAuthor in
                    HangerTalkPostCard(
                        postWithAuthor: postWithAuthor,
                        onLike: {
                            guard let userId = authService.activeUserId else { return }
                            Task {
                                try? await service.toggleLike(postId: postWithAuthor.id, userId: userId)
                                performSearch()
                            }
                        },
                        onRepost: {
                            guard let userId = authService.activeUserId else { return }
                            Task {
                                try? await service.toggleRepost(postId: postWithAuthor.id, userId: userId)
                                performSearch()
                            }
                        },
                        onBookmark: {
                            guard let userId = authService.activeUserId else { return }
                            Task {
                                try? await service.toggleBookmark(postId: postWithAuthor.id, userId: userId)
                                performSearch()
                            }
                        },
                        onReply: {
                            postToReply = postWithAuthor
                        },
                        onPostTap: {
                            selectedPostForDetail = postWithAuthor
                        },
                        isOwnPost: postWithAuthor.post.authorId == authService.activeUserId,
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
                                performSearch()
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Pilot Results

    private var pilotResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Related profiles")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(pilotResults, id: \.id) { pilot in
                        NavigationLink(destination: PublicProfileView(pilotId: pilot.id)
                            .environmentObject(authService)) {
                            pilotCard(pilot: pilot)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }

            Divider()
                .padding(.top, 4)
        }
    }

    private func pilotCard(pilot: HangerAuthorProfile) -> some View {
        VStack(spacing: 10) {
            // Profile picture
            if let urlString = pilot.profilePictureUrl,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)
            }

            // Call sign
            Text(pilot.callSign ?? "Pilot")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)

            // Follow button (skip for own profile)
            if pilot.id != authService.activeUserId {
                Button {
                    Task {
                        guard let myId = authService.activeUserId else { return }
                        let nowFollowing = try? await service.toggleFollow(followerId: myId, followingId: pilot.id)
                        if nowFollowing == true {
                            followedPilotIds.insert(pilot.id)
                        } else {
                            followedPilotIds.remove(pilot.id)
                        }
                    }
                } label: {
                    Text(followedPilotIds.contains(pilot.id) ? "Following" : "Follow")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(followedPilotIds.contains(pilot.id) ? .secondary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(followedPilotIds.contains(pilot.id) ? Color(.systemGray5) : Color.primary)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(width: 120)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            Text("No results found")
                .font(.headline)

            Text("Try searching with different keywords.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 60)
    }

    // MARK: - Perform Search

    private func performSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let userId = authService.activeUserId else { return }

        isSearching = true
        hasSearched = true

        Task {
            async let posts = service.searchPosts(query: trimmed, currentUserId: userId)
            async let pilots = service.searchPilots(query: trimmed)
            async let followedIds = service.fetchFollowedIds(userId: userId)

            searchResults = await posts
            pilotResults = await pilots
            followedPilotIds = await followedIds
            isSearching = false
        }
    }
}
