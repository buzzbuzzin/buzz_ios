//
//  HangerEditPostView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/8/26.
//

import SwiftUI
import PhotosUI

struct HangerEditPostView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    let postId: UUID
    let initialTitle: String
    let initialBody: String
    let initialImageUrls: [String]

    @State private var title: String
    @State private var bodyText: String
    @State private var existingImageUrls: [String]
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var newImages: [UIImage] = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(postId: UUID, initialTitle: String, initialBody: String, initialImageUrls: [String] = []) {
        self.postId = postId
        self.initialTitle = initialTitle
        self.initialBody = initialBody
        self.initialImageUrls = initialImageUrls
        self._title = State(initialValue: initialTitle)
        self._bodyText = State(initialValue: initialBody)
        self._existingImageUrls = State(initialValue: initialImageUrls)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasChanges: Bool {
        title != initialTitle ||
        bodyText != initialBody ||
        existingImageUrls != initialImageUrls ||
        !newImages.isEmpty
    }

    private var totalImageCount: Int {
        existingImageUrls.count + newImages.count
    }

    private var canAddMoreImages: Bool {
        totalImageCount < 4
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    TextField("Post Title", text: $title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)

                    // Body
                    ZStack(alignment: .topLeading) {
                        if bodyText.isEmpty {
                            Text("body text (optional)")
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

                    // Existing images
                    if !existingImageUrls.isEmpty || !newImages.isEmpty {
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
                                                    .fill(Color.gray.opacity(0.2))
                                                    .overlay(ProgressView())
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
            HStack(spacing: 24) {
                if canAddMoreImages {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 4 - existingImageUrls.count,
                        matching: .images
                    ) {
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.3))
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
            .overlay(Divider(), alignment: .top)
        }
        .navigationTitle("Edit Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task { await savePost() }
                }
                .disabled(!isValid || !hasChanges || isSubmitting)
                .fontWeight(.bold)
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
                for item in newItems.prefix(4 - existingImageUrls.count) {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                newImages = images
            }
        }
    }

    private func savePost() async {
        guard let userId = authService.activeUserId else { return }
        isSubmitting = true
        errorMessage = nil

        do {
            let service = HangerHelpService()

            // Upload new images if any
            var allImageUrls = existingImageUrls
            if !newImages.isEmpty {
                let newUrls = try await service.uploadPostImages(userId: userId, images: newImages)
                allImageUrls.append(contentsOf: newUrls)
            }

            try await service.updatePost(
                postId: postId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
                imageUrls: allImageUrls
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}
