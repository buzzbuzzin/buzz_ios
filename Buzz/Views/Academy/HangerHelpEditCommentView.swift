//
//  HangerHelpEditCommentView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/8/26.
//

import SwiftUI

struct HangerHelpEditCommentView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    let commentId: UUID
    let initialBody: String
    let onSaved: () -> Void

    @State private var bodyText: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(commentId: UUID, initialBody: String, onSaved: @escaping () -> Void) {
        self.commentId = commentId
        self.initialBody = initialBody
        self.onSaved = onSaved
        self._bodyText = State(initialValue: initialBody)
    }

    private var isValid: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasChanges: Bool {
        bodyText != initialBody
    }

    var body: some View {
        Form {
            Section {
                TextEditor(text: $bodyText)
                    .frame(minHeight: 120)
            } header: {
                Text("Comment")
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Edit Comment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task { await saveComment() }
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

    private func saveComment() async {
        isSubmitting = true
        errorMessage = nil

        do {
            let service = HangerHelpService()
            try await service.updateComment(
                commentId: commentId,
                body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}
