//
//  HangerTalkPostCard.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/8/26.
//

import SwiftUI

struct HangerTalkPostCard: View {
    let postWithAuthor: HangerTalkPostWithAuthor
    let onLike: () -> Void
    let onRepost: () -> Void
    let onBookmark: () -> Void
    let onReply: () -> Void
    var onPostTap: (() -> Void)? = nil
    var isOwnPost: Bool = false
    var onDelete: (() -> Void)?
    var onEdit: (() -> Void)?
    var onAuthorTap: (() -> Void)?
    var onMentionTap: ((String) -> Void)?
    var onFollow: (() -> Void)?

    @State private var likeAnimating = false
    @State private var suppressPostTap = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Author avatar
                authorAvatar

                VStack(alignment: .leading, spacing: 8) {
                    // Author info row
                    authorInfoRow

                    // Post body text (with @mention highlighting)
                    if let onMentionTap {
                        TappableMentionText(postWithAuthor.post.body) { callSign in
                            markActionTap()
                            onMentionTap(callSign)
                        }
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        MentionText(postWithAuthor.post.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Optional image carousel
                    if !postWithAuthor.post.imageUrls.isEmpty {
                        HangerImageCarousel(imageUrls: postWithAuthor.post.imageUrls, height: 240)
                            .padding(.top, 4)
                    }

                    // Action bar
                    actionBar
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                handlePostTap()
            }

            Divider()
        }
    }

    // MARK: - Author Avatar

    private var authorAvatar: some View {
        ZStack(alignment: .bottom) {
            Button {
                performAction {
                    onAuthorTap?()
                }
            } label: {
                Group {
                    if let urlString = postWithAuthor.authorProfilePictureUrl,
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
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
            }
            .buttonStyle(.plain)

            // Threads-style follow "+" button
            if !isOwnPost && !postWithAuthor.isFollowedByCurrentUser, let onFollow {
                Button {
                    performAction(onFollow)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .offset(y: 6)
            }
        }
    }

    // MARK: - Author Info Row

    private var authorInfoRow: some View {
        HStack(spacing: 4) {
            Button {
                performAction {
                    onAuthorTap?()
                }
            } label: {
                Text(postWithAuthor.authorCallSign ?? "Pilot")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)

            Text("·")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(hangerTimeAgo(postWithAuthor.post.createdAt))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            if isOwnPost, onEdit != nil || onDelete != nil {
                Menu {
                    if let onEdit {
                        Button(action: onEdit) {
                            Label("Edit Post", systemImage: "pencil")
                        }
                    }
                    if let onDelete {
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete Post", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .simultaneousGesture(TapGesture().onEnded {
                    markActionTap()
                })
            }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 0) {
            // Reply
            Button {
                performAction(onReply)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                    Text("\(postWithAuthor.post.replyCount)")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Repost
            Button {
                performAction(onRepost)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.2.squarepath")
                    Text("\(postWithAuthor.post.repostCount)")
                }
                .font(.subheadline)
                .foregroundColor(postWithAuthor.isRepostedByCurrentUser ? .green : .secondary)
            }

            Spacer()

            // Like
            Button {
                markActionTap()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    likeAnimating = true
                }
                onLike()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    likeAnimating = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: postWithAuthor.isLikedByCurrentUser ? "heart.fill" : "heart")
                        .scaleEffect(likeAnimating ? 1.3 : 1.0)
                    Text("\(postWithAuthor.post.likeCount)")
                }
                .font(.subheadline)
                .foregroundColor(postWithAuthor.isLikedByCurrentUser ? .red : .secondary)
            }

            Spacer()

            // Bookmark
            Button {
                performAction(onBookmark)
            } label: {
                Image(systemName: postWithAuthor.isBookmarkedByCurrentUser ? "bookmark.fill" : "bookmark")
                    .font(.subheadline)
                    .foregroundColor(postWithAuthor.isBookmarkedByCurrentUser ? .blue : .secondary)
            }

            Spacer()

            // Share
            ShareLink(item: postWithAuthor.post.body) {
                Image(systemName: "square.and.arrow.up")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .simultaneousGesture(TapGesture().onEnded {
                markActionTap()
            })
        }
    }

    private func handlePostTap() {
        guard !suppressPostTap else { return }
        onPostTap?()
    }

    private func performAction(_ action: () -> Void) {
        markActionTap()
        action()
    }

    private func markActionTap() {
        suppressPostTap = true
        DispatchQueue.main.async {
            suppressPostTap = false
        }
    }
}
