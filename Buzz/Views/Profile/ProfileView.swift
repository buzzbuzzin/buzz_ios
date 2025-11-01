//
//  ProfileView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import Auth

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var rankingService = RankingService()
    @State private var showSignOutAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Header
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: authService.userProfile?.userType == .pilot ? "airplane.circle.fill" : "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if let callSign = authService.userProfile?.callSign {
                                Text(callSign)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            Text(authService.userProfile?.userType == .pilot ? "Pilot" : "Customer")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if let email = authService.userProfile?.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Pilot Stats (if user is pilot)
                if authService.userProfile?.userType == .pilot {
                    Section("Statistics") {
                        if let stats = rankingService.pilotStats {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Tier")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    HStack {
                                        Text("\(stats.tier)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                        Text(stats.tierName)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            
                            HStack {
                                Text("Flight Hours")
                                Spacer()
                                Text(String(format: "%.1f hrs", stats.totalFlightHours))
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Text("Completed Bookings")
                                Spacer()
                                Text("\(stats.completedBookings)")
                                    .fontWeight(.semibold)
                            }
                            
                            NavigationLink(destination: LeaderboardView()) {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                    Text("View Leaderboard")
                                }
                            }
                        } else if rankingService.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }
                    }
                }
                
                // License Management (if pilot)
                if authService.userProfile?.userType == .pilot {
                    Section("License") {
                        NavigationLink(destination: LicenseManagementView()) {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                Text("Manage Licenses")
                            }
                        }
                    }
                }
                
                // Account
                Section("Account") {
                    NavigationLink(destination: EditProfileView()) {
                        HStack {
                            Image(systemName: "person.crop.circle")
                            Text("Edit Profile")
                        }
                    }
                    
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task {
                        try? await authService.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
        .task {
            if authService.userProfile?.userType == .pilot,
               let currentUser = authService.currentUser {
                try? await rankingService.getPilotStats(pilotId: currentUser.id)
            }
        }
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var profileService = ProfileService()
    @Environment(\.dismiss) var dismiss
    
    @State private var callSign = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        Form {
            Section("Profile Information") {
                if authService.userProfile?.userType == .pilot {
                    TextField("Call Sign", text: $callSign)
                        .autocapitalization(.allCharacters)
                }
                
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                
                TextField("Phone", text: $phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
            }
            
            Section {
                CustomButton(
                    title: "Save Changes",
                    action: saveProfile,
                    isLoading: isLoading
                )
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentProfile()
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
            Text("Profile updated successfully")
        }
    }
    
    private func loadCurrentProfile() {
        callSign = authService.userProfile?.callSign ?? ""
        email = authService.userProfile?.email ?? ""
        phone = authService.userProfile?.phone ?? ""
    }
    
    private func saveProfile() {
        guard let currentUser = authService.currentUser else { return }
        
        isLoading = true
        Task {
            let userId = currentUser.id
            do {
                try await profileService.updateProfile(
                    userId: userId,
                    callSign: authService.userProfile?.userType == .pilot ? callSign : nil,
                    email: email,
                    phone: phone
                )
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

