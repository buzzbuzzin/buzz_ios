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

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // If replying, show original post preview
                    if let original = replyToPost {
                        replyContext(original)
                            .padding(.horizontal)
                    }

                    // Text input (no title — Twitter style)
                    ZStack(alignment: .topLeading) {
                        if bodyText.isEmpty {
                            Text(replyToPost != nil ? "Post your reply..." : "What's happening?")
                                .font(.body)
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $bodyText)
                            .font(.body)
                            .frame(minHeight: 120)
                            .padding(.horizontal, 15)
                            .scrollContentBackground(.hidden)
                    }

                    // Image previews
                    if !selectedImages.isEmpty {
                        imagePreviewSection
                            .padding(.horizontal)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 12)
            }

            // Bottom toolbar
            bottomToolbar
        }
        .background(Color(.systemBackground))
        .navigationTitle("")
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(replyToPost != nil ? "Reply" : "Post") {
                    Task { await submitPost() }
                }
                .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                .fontWeight(.bold)
                .foregroundColor(!bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting ? .blue : .secondary)
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

    // MARK: - Reply Context

    private func replyContext(_ original: HangerTalkPostWithAuthor) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let urlString = original.authorProfilePictureUrl,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                }

                Text(original.authorCallSign ?? original.authorFullName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            Text(original.post.body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)

            Text("Replying to \(original.authorCallSign ?? original.authorFullName)")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
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
