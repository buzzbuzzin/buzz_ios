//
//  HangarEditPostView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/8/26.
//

import SwiftUI

struct HangarEditPostView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    let postId: UUID
    let initialTitle: String
    let initialBody: String

    @State private var title: String
    @State private var bodyText: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(postId: UUID, initialTitle: String, initialBody: String) {
        self.postId = postId
        self.initialTitle = initialTitle
        self.initialBody = initialBody
        self._title = State(initialValue: initialTitle)
        self._bodyText = State(initialValue: initialBody)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasChanges: Bool {
        title != initialTitle || bodyText != initialBody
    }

    var body: some View {
        Form {
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
                ProgressView()
            }
        }
    }

    private func savePost() async {
        isSubmitting = true
        errorMessage = nil

        do {
            let service = HangarHelpService()
            try await service.updatePost(
                postId: postId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}
