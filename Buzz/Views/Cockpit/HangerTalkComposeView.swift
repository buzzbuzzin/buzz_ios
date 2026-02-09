//
//  HangerTalkComposeView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/8/26.
//

import SwiftUI
import PhotosUI

struct HangerTalkComposeView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    let replyToPost: HangerTalkPostWithAuthor?
    let onPostCreated: () -> Void

    @State private var bodyText = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(replyToPost: HangerTalkPostWithAuthor? = nil, onPostCreated: @escaping () -> Void) {
        self.replyToPost = replyToPost
        self.onPostCreated = onPostCreated
    }

    private var isReply: Bool { replyToPost != nil }
    private var canSubmit: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let original = replyToPost {
                        threadedReplyLayout(original)
                    } else {
                        newPostLayout
                    }

                    // Image previews
                    if !selectedImages.isEmpty {
                        imagePreviewSection
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                }
                .padding(.top, 12)
            }

            // Bottom toolbar
            bottomToolbar
        }
        .background(Color(.systemBackground))
        .navigationTitle(isReply ? "Reply" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.primary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isReply ? "Reply" : "Post") {
                    Task { await submitPost() }
                }
                .disabled(!canSubmit)
                .fontWeight(.bold)
                .foregroundColor(canSubmit ? .blue : .secondary)
            }
        }
        .disabled(isSubmitting)
        .overlay {
            if isSubmitting {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Posting...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
        }
        .onChange(of: selectedPhotos) { newItems in
            Task {
                var images: [UIImage] = []
                for item in newItems.prefix(4) {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                selectedImages = images
            }
        }
    }

    // MARK: - New Post Layout

    private var newPostLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            currentUserAvatar(size: 40)

            ZStack(alignment: .topLeading) {
                if bodyText.isEmpty {
                    Text("What's happening?")
                        .font(.body)
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.vertical, 8)
                }
                TextEditor(text: $bodyText)
                    .font(.body)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Threaded Reply Layout

    private func threadedReplyLayout(_ original: HangerTalkPostWithAuthor) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Original post with thread line
            HStack(alignment: .top, spacing: 12) {
                // Avatar + thread line column
                VStack(spacing: 0) {
                    originalPostAvatar(original, size: 40)

                    // Thread line connecting original to reply
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }

                // Original post content
                VStack(alignment: .leading, spacing: 6) {
                    // Author info row
                    HStack(spacing: 4) {
                        Text(original.authorCallSign ?? original.authorFullName)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("·")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(hangerTimeAgo(original.post.createdAt))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()
                    }

                    // Post body
                    Text(original.post.body)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Original post images
                    if !original.post.imageUrls.isEmpty {
                        HangerImageCarousel(imageUrls: original.post.imageUrls, height: 180)
                            .padding(.top, 4)
                    }
                }
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 16)

            // Current user reply area
            HStack(alignment: .top, spacing: 12) {
                currentUserAvatar(size: 40)

                VStack(alignment: .leading, spacing: 6) {
                    // "Replying to" label
                    Text("Reply to \(original.authorCallSign ?? original.authorFullName)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Reply text input
                    ZStack(alignment: .topLeading) {
                        if bodyText.isEmpty {
                            Text("Post your reply...")
                                .font(.body)
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $bodyText)
                            .font(.body)
                            .frame(minHeight: 100)
                            .scrollContentBackground(.hidden)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Avatars

    private func originalPostAvatar(_ post: HangerTalkPostWithAuthor, size: CGFloat) -> some View {
        Group {
            if let urlString = post.authorProfilePictureUrl,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func currentUserAvatar(size: CGFloat) -> some View {
        Group {
            if let urlString = authService.userProfile?.profilePictureUrl,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Image Preview Section

    private var imagePreviewSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            removeImage(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 24) {
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 4,
                matching: .images
            ) {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !selectedImages.isEmpty {
                Text("\(selectedImages.count)/4")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .overlay(
            Divider(), alignment: .top
        )
    }

    // MARK: - Remove Image

    private func removeImage(at index: Int) {
        guard index < selectedImages.count else { return }
        selectedImages.remove(at: index)
        if index < selectedPhotos.count {
            selectedPhotos.remove(at: index)
        }
    }

    // MARK: - Submit Post

    private func submitPost() async {
        guard let userId = authService.activeUserId else { return }
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            let service = HangerTalkService()

            // Upload images if any
            var imageUrls: [String] = []
            if !selectedImages.isEmpty {
                imageUrls = try await service.uploadPostImages(userId: userId, images: selectedImages)
            }

            if let parentPost = replyToPost {
                try await service.createReply(
                    authorId: userId,
                    parentPostId: parentPost.id,
                    body: trimmed,
                    imageUrls: imageUrls
                )
            } else {
                try await service.createPost(
                    authorId: userId,
                    body: trimmed,
                    imageUrls: imageUrls
                )
            }
            onPostCreated()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}
