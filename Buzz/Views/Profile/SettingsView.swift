//
//  SettingsView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var profileService = ProfileService()
    @Environment(\.dismiss) var dismiss
    
    @State private var communicationPreference: CommunicationPreference = .email
    @State private var appearanceMode: AppearanceMode = .system
    
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    enum AppearanceMode: String, CaseIterable {
        case light = "light"
        case dark = "dark"
        case system = "system"
        
        var displayName: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            case .system: return "System"
            }
        }
        
        var colorScheme: ColorScheme? {
            switch self {
            case .light: return .light
            case .dark: return .dark
            case .system: return nil
            }
        }
    }
    
    var body: some View {
        Form {
            // Personal Info
            NavigationLink(destination: PersonalInfoView()) {
                HStack {
                    Text("Personal info")
                }
            }
            
            // Login & Security
            NavigationLink(destination: LoginSecurityView()) {
                HStack {
                    Text("Login & Security")
                }
            }
            
            // Notifications
            NavigationLink(destination: NotificationsView()) {
                HStack {
                    Text("Notifications")
                }
            }
            
            // Communication Preferences
            Picker("Communication Preference", selection: $communicationPreference) {
                ForEach([CommunicationPreference.email, .text, .both], id: \.self) { preference in
                    Text(preference.displayName).tag(preference)
                }
            }
            
            // Appearance
            Picker("Appearance", selection: $appearanceMode) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    HStack {
                        Text(mode.displayName)
                        if mode == .system {
                            Spacer()
                            Text("Uses device settings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }.tag(mode)
                }
            }
            
            // Save Button
            Section {
                CustomButton(
                    title: "Save Changes",
                    action: saveSettings,
                    isLoading: isLoading
                )
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(appearanceMode.colorScheme)
        .onAppear {
            loadCurrentSettings()
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
            Text("Settings saved successfully")
        }
    }
    
    private func loadCurrentSettings() {
        // Load communication preference
        communicationPreference = authService.userProfile?.communicationPreference ?? .email
        
        // Load appearance mode from UserDefaults
        if let savedMode = UserDefaults.standard.string(forKey: "appearanceMode"),
           let mode = AppearanceMode(rawValue: savedMode) {
            appearanceMode = mode
        } else {
            appearanceMode = .system
        }
    }
    
    private func saveSettings() {
        guard let currentUser = authService.currentUser else { return }
        
        isLoading = true
        Task {
            let userId = currentUser.id
            do {
                // Update communication preference
                try await profileService.updateCommunicationPreference(
                    userId: userId,
                    preference: communicationPreference
                )
                
                // Save appearance mode to AppStorage (via UserDefaults)
                UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
                
                // Post notification to update app-wide appearance
                NotificationCenter.default.post(name: NSNotification.Name("AppearanceModeChanged"), object: nil)
                
                // Refresh profile
                await authService.checkAuthStatus()
                
                isLoading = false
                showSuccess = true
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

