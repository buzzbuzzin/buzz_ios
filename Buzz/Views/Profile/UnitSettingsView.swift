//
//  UnitSettingsView.swift
//  Buzz
//
//  Created by Codex on 3/10/26.
//

import SwiftUI
import Auth

struct UnitSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var profileService = ProfileService()
    @Environment(\.dismiss) var dismiss

    @State private var selectedMeasurementPreference: UnitPreferenceOption = .regionalDefault
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    private var selectedRegion: String? {
        authService.userProfile?.selectedRegion
    }

    private var effectiveMeasurementSystem: MeasurementSystem {
        selectedMeasurementPreference.explicitMeasurementSystem ??
        MeasurementSystem.regionalDefault(for: selectedRegion)
    }

    private var hasChanges: Bool {
        selectedMeasurementPreference != UnitPreferenceOption(authService.userProfile?.preferredMeasurementSystem)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Units")
                        .font(.headline)

                    Text("Use your region’s default unit system or override it manually. This setting is saved to your profile and used across Weather and Fly Safe.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
            }

            Section("Current") {
                HStack {
                    Text("Region")
                    Spacer()
                    Text(selectedRegion ?? "Not selected")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Active Units")
                    Spacer()
                    Text(authService.userProfile?.effectiveMeasurementSystem.displayName ?? MeasurementSystem.imperial.displayName)
                        .foregroundColor(.secondary)
                }
            }

            Section("Override") {
                Picker("Unit System", selection: $selectedMeasurementPreference) {
                    ForEach(UnitPreferenceOption.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }

                Text(unitDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                CustomButton(
                    title: "Save Changes",
                    action: saveUnits,
                    isLoading: isSaving
                )
                .disabled(!hasChanges)
            }
        }
        .navigationTitle("Units")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedMeasurementPreference = UnitPreferenceOption(authService.userProfile?.preferredMeasurementSystem)
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
            Text("Unit preference updated successfully")
        }
    }

    private var unitDescription: String {
        switch selectedMeasurementPreference {
        case .regionalDefault:
            let regionName = selectedRegion ?? "your region"
            return "Using the regional default. \(regionName) currently maps to \(effectiveMeasurementSystem.displayName.lowercased()) units."
        case .imperial, .metric:
            return "Manual override enabled. The app will use \(effectiveMeasurementSystem.displayName.lowercased()) units regardless of region."
        }
    }

    private func saveUnits() {
        guard let currentUser = authService.currentUser else { return }

        isSaving = true

        Task {
            do {
                try await profileService.updatePreferredMeasurementSystem(
                    userId: currentUser.id,
                    preferredMeasurementSystem: selectedMeasurementPreference.explicitMeasurementSystem
                )

                await authService.checkAuthStatus()

                isSaving = false
                showSuccess = true
            } catch {
                isSaving = false
                errorMessage = "Failed to update units: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

private enum UnitPreferenceOption: CaseIterable {
    case regionalDefault
    case imperial
    case metric

    init(_ system: MeasurementSystem?) {
        switch system {
        case .imperial:
            self = .imperial
        case .metric:
            self = .metric
        case nil:
            self = .regionalDefault
        }
    }

    var title: String {
        switch self {
        case .regionalDefault:
            return "Use Regional Default"
        case .imperial:
            return "Imperial"
        case .metric:
            return "Metric"
        }
    }

    var explicitMeasurementSystem: MeasurementSystem? {
        switch self {
        case .regionalDefault:
            return nil
        case .imperial:
            return .imperial
        case .metric:
            return .metric
        }
    }
}
