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
    @StateObject private var demoModeManager = DemoModeManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var communicationPreference: CommunicationPreference = .email
    @State private var appearanceMode: AppearanceMode = .system
    
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
                    Text("Personal Info")
                }
            }

            // Region
            NavigationLink(destination: RegionSettingsView()) {
                HStack {
                    Text("Region")
                }
            }

            NavigationLink(destination: UnitSettingsView()) {
                HStack {
                    Text("Units")
                    Spacer()
                    Text(authService.userProfile?.effectiveMeasurementSystem.displayName ?? MeasurementSystem.imperial.displayName)
                        .foregroundColor(.secondary)
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
            
            // Saved Payments
            NavigationLink(destination: SavedPaymentsView()) {
                HStack {
                    Text("Saved Payments")
                }
            }
            
            // Express Promotion (Pilot only)
            if authService.userProfile?.userType == .pilot {
                NavigationLink(destination: ExpressPromotionView()) {
                    Text("Express Promotion")
                }
            }
            
            // Communication Preferences
            Picker("Communication Preference", selection: $communicationPreference) {
                ForEach([CommunicationPreference.email, .text, .both], id: \.self) { preference in
                    Text(preference.displayName).tag(preference)
                }
            }
            .onChange(of: communicationPreference) { newValue in
                // Save immediately when changed
                Task {
                    await saveCommunicationPreference(newValue)
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
            .onChange(of: appearanceMode) { newValue in
                // Save immediately when changed
                saveAppearanceMode(newValue)
            }
            
            // Legal
            NavigationLink(destination: LegalDocumentsView()) {
                HStack {
                    Text("Legal")
                }
            }
            
            // Demo Mode Toggle - Hidden
//            Section(header: Text("Development")) {
//                Toggle("Demo Mode", isOn: $demoModeManager.isDemoModeEnabled)
//                    .onChange(of: demoModeManager.isDemoModeEnabled) { newValue in
//                        // Demo mode is saved immediately - no need to click Save Changes
//                        // The change is already persisted via DemoModeManager's didSet
//                    }
//                
//                if demoModeManager.isDemoModeEnabled {
//                    Text("Demo mode is enabled. The app will show sample data instead of connecting to the backend.")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                        .padding(.top, 4)
//                } else {
//                    Text("Demo mode is disabled. The app will connect to the backend for all data.")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                        .padding(.top, 4)
//                }
//            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(appearanceMode.colorScheme)
        .onAppear {
            loadCurrentSettings()
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
    
    private func saveCommunicationPreference(_ preference: CommunicationPreference) async {
        guard let currentUser = authService.currentUser else { return }
        
        do {
            try await profileService.updateCommunicationPreference(
                userId: currentUser.id,
                preference: preference
            )
            
            // Refresh profile to reflect the change
            await authService.checkAuthStatus()
        } catch {
            print("Error saving communication preference: \(error.localizedDescription)")
            // Optionally show an error alert, but for now just log it
        }
    }
    
    private func saveAppearanceMode(_ mode: AppearanceMode) {
        // Save appearance mode to UserDefaults
        UserDefaults.standard.set(mode.rawValue, forKey: "appearanceMode")
        
        // Post notification to update app-wide appearance
        NotificationCenter.default.post(name: NSNotification.Name("AppearanceModeChanged"), object: nil)
    }
}

struct LegalDocumentsView: View {
    private var eulaURL: URL {
        URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    }
    
    private var privacyPolicyURL: URL {
        URL(string: "https://www.buzzbuzzin.com/privacy")!
    }
    
    var body: some View {
        List {
            NavigationLink("End User License Agreement") {
                SafariView(url: eulaURL)
                    .navigationTitle("EULA")
                    .navigationBarTitleDisplayMode(.inline)
            }
            
            NavigationLink("Privacy Policy") {
                SafariView(url: privacyPolicyURL)
                    .navigationTitle("Privacy Policy")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .navigationTitle("Legal")
    }
}
