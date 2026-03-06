//
//  CreateSpaceView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/22/26.
//

import SwiftUI

struct CreateSpaceView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject var spaceService: HangerSpaceService
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var isCreating = false

    let onSpaceCreated: (HangerSpace) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Space Details") {
                    TextField("Space title (e.g., Pre-flight check tips)", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Text("When you go live, your followers will be notified and can join to listen.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Start a Space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go Live") {
                        createSpace()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                }
            }
            .overlay {
                if isCreating {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Going live...")
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                }
            }
        }
    }

    private func createSpace() {
        guard let userId = authService.activeUserId else { return }
        isCreating = true

        Task {
            do {
                let space = try await spaceService.createSpace(
                    hostId: userId,
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description.trimmingCharacters(in: .whitespaces)
                )
                isCreating = false
                dismiss()
                onSpaceCreated(space)
            } catch {
                spaceService.errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }
}
