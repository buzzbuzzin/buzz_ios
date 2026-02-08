//
//  HangarHelpView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/7/26.
//

import SwiftUI

// MARK: - Sort Mode

enum HangarSortMode: String, CaseIterable {
    case newest = "Newest"
    case mostLiked = "Most Liked"
}

struct HangarHelpView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var hangarService = HangarHelpService()
    @State private var sortMode: HangarSortMode = .newest
    @State private var selectedTopicId: UUID?
    @State private var showNewPost = false

    // MARK: - Filtered & Sorted Posts

    private var displayedPosts: [HangarPostWithAuthor] {
        var filtered = hangarService.posts

        // Filter by topic
        if let topicId = selectedTopicId {
            filtered = filtered.filter { $0.post.topicId == topicId }
        }

        // Sort
        switch sortMode {
        case .newest:
            return filtered.sorted { $0.post.createdAt > $1.post.createdAt }
        case .mostLiked:
            return filtered.sorted { $0.post.likeCount > $1.post.likeCount }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Sort Picker
                Picker("Sort by", selection: $sortMode) {
                    ForEach(HangarSortMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Topic Filter Bar
                topicFilterBar

                // Posts Feed
                if hangarService.isLoading {
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
                    LazyVStack(spacing: 12) {
                        ForEach(displayedPosts) { postWithAuthor in
                            NavigationLink(destination: HangarPostDetailView(
                                postWithAuthor: postWithAuthor,
                                topicName: postWithAuthor.topicName
                            ).environmentObject(authService)) {
                                HangarPostCard(postWithAuthor: postWithAuthor, onLike: {
                                    guard let userId = authService.activeUserId else { return }
                                    Task {
                                        try? await hangarService.togglePostLike(postId: postWithAuthor.id, userId: userId)
                                        await hangarService.fetchAllPosts(currentUserId: userId)
                                    }
                                })
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .navigationTitle("Hangar Help")
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
                HangarNewPostView(
                    topics: hangarService.topics,
                    onPostCreated: {
                        showNewPost = false
                        Task {
                            guard let userId = authService.activeUserId else { return }
                            await hangarService.fetchAllPosts(currentUserId: userId)
                        }
                    }
                )
                .environmentObject(authService)
            }
        }
        .task {
            await hangarService.fetchTopics()
            guard let userId = authService.activeUserId else { return }
            await hangarService.fetchAllPosts(currentUserId: userId)
        }
        .refreshable {
            await hangarService.fetchTopics()
            guard let userId = authService.activeUserId else { return }
            await hangarService.fetchAllPosts(currentUserId: userId)
        }
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
                ForEach(hangarService.topics) { topic in
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
