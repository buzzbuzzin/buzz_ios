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
    @State private var selectedSegment: SearchSegment = .posts
    @State private var searchResults: [HangerTalkPostWithAuthor] = []
    @State private var pilotResults: [HangerAuthorProfile] = []
    @State private var isSearching = false
    @State private var hasSearched = false

    enum SearchSegment: String, CaseIterable {
        case posts = "Posts"
        case pilots = "Pilots"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar

            // Segment picker
            Picker("", selection: $selectedSegment) {
                ForEach(SearchSegment.allCases, id: \.self) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Results
            ScrollView {
                if isSearching {
                    ProgressView()
                        .padding(.top, 40)
                } else if !hasSearched {
                    emptyPrompt
                } else {
                    switch selectedSegment {
                    case .posts:
                        postResults
                    case .pilots:
                        pilotResultsSection
                    }
                }
            }
        }
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
        Group {
            if searchResults.isEmpty {
                noResultsView
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(searchResults) { postWithAuthor in
                        NavigationLink(destination: HangerTalkPostDetailView(
                            postWithAuthor: postWithAuthor
                        ).environmentObject(authService)) {
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
                                onReply: {},
                                isOwnPost: postWithAuthor.post.authorId == authService.activeUserId
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Pilot Results

    private var pilotResultsSection: some View {
        Group {
            if pilotResults.isEmpty {
                noResultsView
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(pilotResults, id: \.id) { pilot in
                        HStack(spacing: 12) {
                            if let urlString = pilot.profilePictureUrl,
                               let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle().fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(pilot.callSign ?? pilot.fullName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)

                                if pilot.callSign != nil {
                                    Text(pilot.fullName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
        }
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
            switch selectedSegment {
            case .posts:
                searchResults = await service.searchPosts(query: trimmed, currentUserId: userId)
            case .pilots:
                pilotResults = await service.searchPilots(query: trimmed)
            }
            isSearching = false
        }
    }
}
