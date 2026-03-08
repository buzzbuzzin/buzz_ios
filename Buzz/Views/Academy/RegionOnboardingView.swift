//
//  RegionOnboardingView.swift
//  Buzz
//
//  Created by Xinyu Fang on 01/20/26.
//

import SwiftUI
import Auth

struct RegionOnboardingView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var profileService = ProfileService()
    @Environment(\.dismiss) var dismiss

    @State private var selectedRegion: TrainingCourse.CourseRegion?
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showOtherRegionAlert = false

    private let availableRegions: [TrainingCourse.CourseRegion] = [
        .canada, .usa, .uk, .australia, .newZealand, .southAfrica
    ]

    var body: some View {
        ScrollView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // Header
                    VStack(spacing: 16) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)

                        Text("Welcome to Buzz Academy")
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text("To provide you with the most relevant courses, please select your physical location. This helps us show you courses that comply with your local regulations and requirements.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Region Selection
                    VStack(spacing: 20) {
                        Text("Where are you located?")
                            .font(.headline)
                            .foregroundColor(.primary)

                        VStack(spacing: 12) {
                            ForEach(availableRegions, id: \.self) { region in
                                RegionSelectionCard(
                                    region: region,
                                    isSelected: selectedRegion == region,
                                    action: {
                                        selectedRegion = region
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Continue Button
                    VStack(spacing: 16) {
                        // Footer text moved above button
                        VStack(spacing: 8) {
                            Text("You can always change your region later in Settings > Account > Region")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        Button(action: saveRegionSelection) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Continue to Academy")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(selectedRegion == nil ? Color.gray : Color.blue)
                        .cornerRadius(12)
                        .padding(.horizontal, 32)
                        .disabled(selectedRegion == nil || isSaving)
                    }

                    Spacer()
                }
                .padding(.vertical, 40)
                // .padding(.top, 10) // Add extra top padding
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Other Region Selected", isPresented: $showOtherRegionAlert) {
            Button("Continue Anyway", role: .destructive) {
                // Continue with saving "Other" region
                Task {
                    await saveOtherRegion()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Didn't see your region listed? Don't worry! We will be expanding to your region later. You can still take global courses. And if you are interested in taking other region's courses, you can always change your region setting in Settings > Account > Region.")
        }
    }

    private func saveRegionSelection() {
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
                dismiss()
            } catch {
                isSaving = false
                errorMessage = "Failed to save region selection: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func saveOtherRegion() async {
        guard let currentUser = authService.currentUser else { return }

        isSaving = true

        do {
            try await profileService.updateRegion(
                userId: currentUser.id,
                regionString: "Other"
            )

            // Refresh auth status to get updated profile
            await authService.checkAuthStatus()

            isSaving = false
            dismiss()
        } catch {
            isSaving = false
            errorMessage = "Failed to save region selection: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Region Selection Card

struct RegionSelectionCard: View {
    let region: TrainingCourse.CourseRegion
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(region.icon)
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 4) {
                    Text(region.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(regionDescription(for: region))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 24))
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func regionDescription(for region: TrainingCourse.CourseRegion) -> String {
        switch region {
        case .canada:
            return "Transport Canada regulations"
        case .usa:
            return "FAA Part 107 regulations"
        case .uk:
            return "CAA regulations"
        case .australia:
            return "CASA regulations"
        case .newZealand:
            return "CAA regulations"
        case .southAfrica:
            return "SACAA regulations"
        case .other:
            return "Other regions"
        case .global:
            return "International standards"
        }
    }
}
