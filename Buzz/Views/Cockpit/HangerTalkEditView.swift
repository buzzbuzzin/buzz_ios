//
//  HangerTalkEditView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/9/26.
//

import SwiftUI
import PhotosUI

struct HangerTalkEditView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    let postWithAuthor: HangerTalkPostWithAuthor
    let onPostUpdated: () -> Void

    @State private var bodyText: String
    @State private var existingImageUrls: [String]
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var newImages: [UIImage] = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(postWithAuthor: HangerTalkPostWithAuthor, onPostUpdated: @escaping () -> Void) {
        self.postWithAuthor = postWithAuthor
        self.onPostUpdated = onPostUpdated
        _bodyText = State(initialValue: postWithAuthor.post.body)
        _existingImageUrls = State(initialValue: postWithAuthor.post.imageUrls)
    }

    private var totalImageCount: Int {
        existingImageUrls.count + newImages.count
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Text input
                    ZStack(alignment: .topLeading) {
                        // Invisible text to drive dynamic height
                        Text(bodyText.isEmpty ? " " : bodyText)
                            .font(.body)
                            .foregroundColor(.clear)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if bodyText.isEmpty {
                            Text("What's happening?")
                                .font(.body)
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $bodyText)
                            .font(.body)
                            .padding(.horizontal, 15)
                            .scrollContentBackground(.hidden)
                            .scrollDisabled(true)
                    }
                    .frame(minHeight: 120)

                    // Existing image previews
                    if !existingImageUrls.isEmpty || !newImages.isEmpty {
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
        .navigationTitle("Edit Post")
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
                Button("Save") {
                    Task { await submitEdit() }
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
                    Text("Saving...")
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
                for item in newItems.prefix(max(0, 4 - existingImageUrls.count)) {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                newImages = images
            }
        }
    }

    // MARK: - Image Preview Section

    private var imagePreviewSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Existing images
                ForEach(Array(existingImageUrls.enumerated()), id: \.offset) { index, urlString in
                    ZStack(alignment: .topTrailing) {
                        if let url = URL(string: urlString) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            existingImageUrls.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        .offset(x: 6, y: -6)
                    }
                }

                // New images
                ForEach(Array(newImages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            newImages.remove(at: index)
                            if index < selectedPhotos.count {
                                selectedPhotos.remove(at: index)
                            }
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
            if totalImageCount < 4 {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: max(1, 4 - existingImageUrls.count),
                    matching: .images
                ) {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if totalImageCount > 0 {
                Text("\(totalImageCount)/4")
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

    // MARK: - Submit Edit

    private func submitEdit() async {
        guard let userId = authService.activeUserId else { return }
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            let service = HangerTalkService()

            // Upload new images if any
            var allImageUrls = existingImageUrls
            if !newImages.isEmpty {
                let uploadedUrls = try await service.uploadPostImages(userId: userId, images: newImages)
                allImageUrls.append(contentsOf: uploadedUrls)
            }

            try await service.updatePost(postId: postWithAuthor.id, body: trimmed, imageUrls: allImageUrls)
            onPostUpdated()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}
