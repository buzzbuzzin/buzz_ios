//
//  HangarNewPostView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/7/26.
//

import SwiftUI

struct HangarNewPostView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    let topics: [HangarTopic]
    let onPostCreated: () -> Void

    @State private var selectedTopicId: UUID?
    @State private var title = ""
    @State private var bodyText = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(topics: [HangarTopic], preselectedTopicId: UUID? = nil, onPostCreated: @escaping () -> Void) {
        self.topics = topics
        self.onPostCreated = onPostCreated
        self._selectedTopicId = State(initialValue: preselectedTopicId)
    }

    private var isValid: Bool {
        selectedTopicId != nil &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section {
                Picker("Topic", selection: $selectedTopicId) {
                    Text("Select a topic").tag(UUID?.none)
                    ForEach(topics) { topic in
                        HStack {
                            Image(systemName: topic.iconName)
                            Text(topic.name)
                        }
                        .tag(UUID?.some(topic.id))
                    }
                }
            } header: {
                Text("Topic")
            }

            Section {
                TextField("Post Title", text: $title)
                    .font(.headline)
            } header: {
                Text("Title")
            }

            Section {
                TextEditor(text: $bodyText)
                    .frame(minHeight: 150)
            } header: {
                Text("What's on your mind?")
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("New Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Post") {
                    Task { await submitPost() }
                }
                .disabled(!isValid || isSubmitting)
                .fontWeight(.bold)
            }
        }
        .disabled(isSubmitting)
        .overlay {
            if isSubmitting {
                ProgressView()
            }
        }
    }

    private func submitPost() async {
        guard let userId = authService.activeUserId,
              let topicId = selectedTopicId else { return }
        isSubmitting = true
        errorMessage = nil

        do {
            let service = HangarHelpService()
            try await service.createPost(
                topicId: topicId,
                authorId: userId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onPostCreated()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}
