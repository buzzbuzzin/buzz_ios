//
//  HangerNewPostView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/7/26.
//

import SwiftUI
import PhotosUI

struct HangerNewPostView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    let topics: [HangerTopic]
    let onPostCreated: () -> Void

    @State private var selectedTopicId: UUID?
    @State private var title = ""
    @State private var bodyText = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showTopicPicker = false
    @State private var showTopicRequiredAlert = false

    init(topics: [HangerTopic], preselectedTopicId: UUID? = nil, onPostCreated: @escaping () -> Void) {
        self.topics = topics
        self.onPostCreated = onPostCreated
        self._selectedTopicId = State(initialValue: preselectedTopicId)
    }

    private var isValid: Bool {
        selectedTopicId != nil &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedTopic: HangerTopic? {
        guard let id = selectedTopicId else { return nil }
        return topics.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Topic picker pill
                    topicPickerPill
                        .padding(.horizontal)

                    // Title field
                    TextField("Title", text: $title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)

                    // Body field
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
                Button("Post") {
                    if selectedTopicId == nil {
                        showTopicRequiredAlert = true
                    } else {
                        Task { await submitPost() }
                    }
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                .fontWeight(.bold)
                .foregroundColor(!title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting ? .blue : .secondary)
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
        .alert("Select a Community", isPresented: $showTopicRequiredAlert) {
            Button("Choose Community") {
                showTopicPicker = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please select a community for your post before posting.")
        }
        .confirmationDialog("Select a topic", isPresented: $showTopicPicker) {
            ForEach(topics) { topic in
                Button(topic.name) {
                    selectedTopicId = topic.id
                }
            }
            Button("Cancel", role: .cancel) { }
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

    // MARK: - Topic Picker Pill

    private var topicPickerPill: some View {
        Button {
            showTopicPicker = true
        } label: {
            HStack(spacing: 6) {
                if let topic = selectedTopic {
                    Image(systemName: topic.iconName)
                        .font(.system(size: 14))
                    Text(topic.name)
                        .font(.system(size: 14, weight: .medium))
                } else {
                    Image(systemName: "circle.grid.2x2")
                        .font(.system(size: 14))
                    Text("Select a community")
                        .font(.system(size: 14, weight: .medium))
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
            .foregroundColor(selectedTopic != nil ? .primary : .secondary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
        guard let userId = authService.activeUserId,
              let topicId = selectedTopicId else { return }
        isSubmitting = true
        errorMessage = nil

        do {
            let service = HangerTalkService()

            // Upload images if any
            var imageUrls: [String] = []
            if !selectedImages.isEmpty {
                imageUrls = try await service.uploadPostImages(userId: userId, images: selectedImages)
            }

            try await service.createPost(
                topicId: topicId,
                authorId: userId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
                imageUrls: imageUrls
            )
            onPostCreated()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}
