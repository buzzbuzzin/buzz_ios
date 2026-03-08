//
//  RegionSettingsView.swift
//  Buzz
//
//  Created by Xinyu Fang on 01/20/26.
//

import SwiftUI
import Auth

struct RegionSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var profileService = ProfileService()
    @Environment(\.dismiss) var dismiss

    @State private var selectedRegion: TrainingCourse.CourseRegion?
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    private let availableRegions: [TrainingCourse.CourseRegion] = [
        .canada, .usa, .uk, .australia, .newZealand, .southAfrica
    ]

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Course Region")
                        .font(.headline)

                    Text("Select your physical location to see courses relevant to your local regulations and requirements. You'll see courses from your selected region plus global courses.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
            }

            Section("Current Region") {
                if let currentRegionString = authService.userProfile?.selectedRegion,
           let currentRegion = TrainingCourse.CourseRegion(rawValue: currentRegionString) {
                    HStack {
                        Text(currentRegion.icon)
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text(currentRegion.rawValue)
                                .font(.headline)
                            Text("Your selected region")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("No region selected")
                        .foregroundColor(.secondary)
                }
            }

            Section("Change Region") {
                ForEach(availableRegions, id: \.self) { region in
                    HStack {
                        Text(region.icon)
                            .font(.title3)
                        Text(region.rawValue)
                        Spacer()
                        if selectedRegion == region {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedRegion = region
                    }
                }
            }

            Section {
                CustomButton(
                    title: "Save Changes",
                    action: saveRegion,
                    isLoading: isSaving
                )
                .disabled(selectedRegion == nil || selectedRegion?.rawValue == authService.userProfile?.selectedRegion)
            }
        }
        .navigationTitle("Region")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let regionString = authService.userProfile?.selectedRegion {
            selectedRegion = TrainingCourse.CourseRegion(rawValue: regionString)
        }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Region updated successfully")
        }
    }

    private func saveRegion() {
        guard let currentUser = authService.currentUser,
              let selectedRegion = selectedRegion else { return }

        isSaving = true

        Task {
            do {
                try await profileService.updateRegion(
                    userId: currentUser.id,
                    regionString: selectedRegion.rawValue
                )

                // Refresh auth status to get updated profile
                await authService.checkAuthStatus()

                isSaving = false
                showSuccess = true
            } catch {
                isSaving = false
                errorMessage = "Failed to update region: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}