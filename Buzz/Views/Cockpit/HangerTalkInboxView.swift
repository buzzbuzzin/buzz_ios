//
//  HangerTalkInboxView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/10/26.
//

import SwiftUI

struct HangerTalkInboxView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject var service: HangerTalkService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(InboxCategory.allCases) { category in
                        NavigationLink(destination:
                            HangerTalkInboxCategoryView(
                                service: service,
                                category: category
                            )
                            .environmentObject(authService)
                        ) {
                            categoryRow(category)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
            }
            .refreshable {
                guard let userId = authService.activeUserId else { return }
                await service.fetchInbox(userId: userId)
            }
            .navigationTitle("Inbox")
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
            .task {
                guard let userId = authService.activeUserId else { return }
                await service.fetchInbox(userId: userId)
            }
        }
    }

    // MARK: - Category Row

    private func categoryRow(_ category: InboxCategory) -> some View {
        HStack(spacing: 16) {
            // Colored circle icon
            ZStack {
                Circle()
                    .fill(category.backgroundColor)
                    .frame(width: 48, height: 48)

                Image(systemName: category.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(category.iconColor)
            }

            Text(category.title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Spacer()

            // Unread count badge
            if let count = service.unreadCounts[category.notificationType], count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red)
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Inbox Category

enum InboxCategory: String, CaseIterable, Identifiable {
    case followers
    case likes
    case replies
    case mentions
    case spaces

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followers: return "New followers"
        case .likes: return "Likes"
        case .replies: return "Comments"
        case .mentions: return "Mentions"
        case .spaces: return "Spaces"
        }
    }

    var iconName: String {
        switch self {
        case .followers: return "person.badge.plus"
        case .likes: return "heart.fill"
        case .replies: return "arrowshape.turn.up.left.fill"
        case .mentions: return "at"
        case .spaces: return "antenna.radiowaves.left.and.right"
        }
    }

    var iconColor: Color {
        switch self {
        case .followers: return .orange
        case .likes: return .red
        case .replies: return .blue
        case .mentions: return .blue
        case .spaces: return .purple
        }
    }

    var backgroundColor: Color {
        switch self {
        case .followers: return .orange.opacity(0.15)
        case .likes: return .red.opacity(0.15)
        case .replies: return .blue.opacity(0.15)
        case .mentions: return .blue.opacity(0.15)
        case .spaces: return .purple.opacity(0.15)
        }
    }

    var notificationType: HangerTalkNotificationType {
        switch self {
        case .followers: return .follow
        case .likes: return .like
        case .replies: return .reply
        case .mentions: return .mention
        case .spaces: return .spaceLive
        }
    }

    var emptyStateMessage: String {
        switch self {
        case .followers: return "When someone follows you, you'll see it here."
        case .likes: return "When someone likes your posts, you'll see it here."
        case .replies: return "When someone replies to your posts, you'll see it here."
        case .mentions: return "When someone mentions you, you'll see it here."
        case .spaces: return "When someone you follow starts a live Space, you'll see it here."
        }
    }
}
