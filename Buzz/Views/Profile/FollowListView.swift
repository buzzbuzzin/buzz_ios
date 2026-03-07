//
//  FollowListView.swift
//  Buzz
//
//  Created by Xinyu Fang on 3/5/26.
//

import SwiftUI
import Auth

struct FollowListView: View {
    let pilotId: UUID
    let initialTab: FollowListTab
    @ObservedObject var hangerTalkService: HangerTalkService
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: FollowListTab

    init(pilotId: UUID, initialTab: FollowListTab, hangerTalkService: HangerTalkService) {
        self.pilotId = pilotId
        self.initialTab = initialTab
        self.hangerTalkService = hangerTalkService
        _selectedTab = State(initialValue: initialTab)
    }
    @State private var followers: [HangerAuthorProfile] = []
    @State private var following: [HangerAuthorProfile] = []
    @State private var followedByMe: Set<UUID> = []
    @State private var followToggleInProgress: Set<UUID> = []
    @State private var isLoading = true
    @State private var navigateToProfileId: UUID?

    private var currentUserId: UUID? { authService.currentUser?.id }

    private var displayedProfiles: [HangerAuthorProfile] {
        selectedTab == .followers ? followers : following
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Tab", selection: $selectedTab) {
                    ForEach(FollowListTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if displayedProfiles.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(displayedProfiles, id: \.id) { profile in
                                userRow(profile)
                                Divider()
                                    .padding(.leading, 72)
                            }
                        }
                    }
                }
            }
            .navigationTitle(selectedTab.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationDestination(item: Binding(
                get: { navigateToProfileId.map { FollowListNavigableUUID(id: $0) } },
                set: { navigateToProfileId = $0?.id }
            )) { navigable in
                PublicProfileView(pilotId: navigable.id)
                    .environmentObject(authService)
            }
            .task {
                await loadData()
            }
        }
    }

    // MARK: - User Row

    private func userRow(_ profile: HangerAuthorProfile) -> some View {
        Button {
            navigateToProfileId = profile.id
        } label: {
            HStack(spacing: 12) {
                avatar(url: profile.profilePictureUrl)

                Text(profile.visibleDisplayName(to: currentUserId))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                if profile.id != currentUserId {
                    Button {
                        guard !followToggleInProgress.contains(profile.id) else { return }
                        followToggleInProgress.insert(profile.id)
                        Task {
                            guard let myId = currentUserId else {
                                followToggleInProgress.remove(profile.id)
                                return
                            }
                            if let nowFollowing = try? await hangerTalkService.toggleFollow(
                                followerId: myId, followingId: profile.id) {
                                if nowFollowing {
                                    followedByMe.insert(profile.id)
                                } else {
                                    followedByMe.remove(profile.id)
                                }
                            }
                            followToggleInProgress.remove(profile.id)
                        }
                    } label: {
                        Text(followedByMe.contains(profile.id) ? "Following" : (selectedTab == .followers ? "Follow back" : "Follow"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(followedByMe.contains(profile.id) ? .secondary : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(followedByMe.contains(profile.id) ? Color(.systemGray5) : Color.blue)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    .disabled(followToggleInProgress.contains(profile.id))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Avatar

    private func avatar(url: String?) -> some View {
        Group {
            if let urlString = url, let imageUrl = URL(string: urlString) {
                AsyncImage(url: imageUrl) { image in
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
        }
        .frame(width: 40, height: 40)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: selectedTab == .followers ? "person.2" : "person.badge.plus")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
            }

            Text(selectedTab == .followers ? "No followers yet" : "Not following anyone")
                .font(.headline)

            Text(selectedTab == .followers
                 ? "When people follow this pilot, they'll show up here."
                 : "When this pilot follows others, they'll show up here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        let myId = currentUserId
        async let fetchedFollowers = hangerTalkService.fetchFollowerProfiles(userId: pilotId)
        async let fetchedFollowing = hangerTalkService.fetchFollowingProfiles(userId: pilotId)
        async let fetchedMyFollows: Set<UUID> = {
            if let myId = myId {
                return await hangerTalkService.fetchFollowedIds(userId: myId)
            }
            return []
        }()

        followers = await fetchedFollowers
        following = await fetchedFollowing
        followedByMe = await fetchedMyFollows
        isLoading = false
    }
}

// MARK: - Helpers

private struct FollowListNavigableUUID: Hashable {
    let id: UUID
}
