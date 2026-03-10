//
//  HangerTalkInboxCategoryView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/10/26.
//

import SwiftUI

struct HangerTalkInboxCategoryView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject var service: HangerTalkService
    let category: InboxCategory
    @State private var selectedPost: HangerTalkPostWithAuthor?
    @State private var navigateToProfileId: UUID?
    @State private var isLoadingPost = false

    private var items: [HangerTalkNotificationItem] {
        service.itemsForCategory(category.notificationType)
    }

    var body: some View {
        ScrollView {
            if items.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        notificationRow(item)
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
        }
        .refreshable {
            guard let userId = authService.activeUserId else { return }
            await service.fetchInbox(userId: userId)
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedPost) { post in
            HangerTalkPostDetailView(postWithAuthor: post)
                .environmentObject(authService)
        }
        .navigationDestination(item: Binding(
            get: { navigateToProfileId.map { NavigableUUID(id: $0) } },
            set: { navigateToProfileId = $0?.id }
        )) { navigable in
            PublicProfileView(pilotId: navigable.id)
                .environmentObject(authService)
        }
        .task {
            guard let userId = authService.activeUserId else { return }
            if service.inboxItems.isEmpty {
                await service.fetchInbox(userId: userId)
            }
            await service.markAllAsRead(userId: userId)
        }
        .overlay {
            if isLoadingPost {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.5))
            }
        }
    }

    // MARK: - Notification Row

    private func notificationRow(_ item: HangerTalkNotificationItem) -> some View {
        Button {
            handleTap(item)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                avatar(url: item.actorProfilePictureUrl)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(hangerTimeAgo(item.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if item.postId != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(!item.isRead ? Color.blue.opacity(0.05) : Color.clear)
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
                    .fill(category.backgroundColor)
                    .frame(width: 64, height: 64)

                Image(systemName: category.iconName)
                    .font(.system(size: 28))
                    .foregroundColor(category.iconColor)
            }

            Text("Nothing yet")
                .font(.headline)

            Text(category.emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    // MARK: - Tap Handler

    private func handleTap(_ item: HangerTalkNotificationItem) {
        if item.type == .follow {
            navigateToProfileId = item.actorId
            return
        }

        guard let postId = item.postId else { return }
        guard let userId = authService.activeUserId else { return }

        isLoadingPost = true
        Task {
            if let post = await service.fetchPost(postId: postId, currentUserId: userId) {
                selectedPost = post
            }
            isLoadingPost = false
        }
    }
}

// MARK: - Helpers for navigationDestination

private struct NavigableUUID: Hashable {
    let id: UUID
}

extension HangerTalkPostWithAuthor: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: HangerTalkPostWithAuthor, rhs: HangerTalkPostWithAuthor) -> Bool {
        lhs.id == rhs.id
    }
}
