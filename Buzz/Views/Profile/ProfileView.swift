//
//  ProfileView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import Auth
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var rankingService = RankingService()
    @StateObject private var ratingService = RatingService()
    @StateObject private var bookingService = BookingService()
    @StateObject private var profilePictureService = ProfilePictureService()
    @State private var showSignOutAlert = false
    @State private var showImagePicker = false
    @State private var showImageSourceSheet = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var profileImage: UIImage?
    @State private var ratingSummary: UserRatingSummary?
    @State private var completedBookingsCount = 0
    @State private var isLoadingRatings = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Header
                Section {
                    HStack(spacing: 16) {
                        // Profile Picture (clickable to upload)
                        Button(action: {
                            showImageSourceSheet = true
                        }) {
                            Group {
                                if let pictureUrl = authService.userProfile?.profilePictureUrl,
                                   let url = URL(string: pictureUrl) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(width: 70, height: 70)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 70, height: 70)
                                                .clipShape(Circle())
                                        case .failure:
                                            Image(systemName: authService.userProfile?.userType == .pilot ? "airplane.circle.fill" : "person.circle.fill")
                                                .font(.system(size: 70))
                                                .foregroundColor(.blue)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                } else {
                                    Image(systemName: authService.userProfile?.userType == .pilot ? "airplane.circle.fill" : "person.circle.fill")
                                        .font(.system(size: 70))
                                        .foregroundColor(.blue)
                                }
                            }
                            .overlay(
                                Circle()
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                            )
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .offset(x: 25, y: 25)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authService.userProfile?.fullName ?? "User")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if let callSign = authService.userProfile?.callSign {
                                Text("@\(callSign)")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
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
                
                // Statistics Section
                Section("Statistics") {
                    if authService.userProfile?.userType == .pilot {
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
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                Text("Flight Hours")
                                Spacer()
                                Text(String(format: "%.1f hrs", stats.totalFlightHours))
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .frame(width: 24)
                                Text("Completed Bookings")
                                Spacer()
                                Text("\(completedBookingsCount)")
                                    .fontWeight(.semibold)
                            }
                            
                            NavigationLink(destination: RevenueDetailsView()) {
                                HStack {
                                    Image(systemName: "dollarsign.circle.fill")
                                    Text("Revenue")
                                }
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
                    } else {
                        // Customer stats
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            Text("Completed Bookings")
                            Spacer()
                            if isLoadingRatings {
                                ProgressView()
                            } else {
                                Text("\(completedBookingsCount)")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    
                    // Ratings Summary (for both pilots and customers)
                    if isLoadingRatings && ratingSummary == nil {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 24)
                            Text("Ratings")
                            Spacer()
                            ProgressView()
                        }
                    } else if let summary = ratingSummary {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 24)
                            Text("Ratings")
                            Spacer()
                            HStack(spacing: 4) {
                                StarRatingView(rating: summary.averageRating)
                                Text("(\(summary.totalRatings))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 24)
                            Text("Ratings")
                            Spacer()
                            Text("No ratings yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // View All Ratings Link
                    if let summary = ratingSummary, summary.totalRatings > 0, let currentUser = authService.currentUser {
                        NavigationLink(destination: RatingsListView(userId: currentUser.id)) {
                            HStack {
                                Image(systemName: "star.fill")
                                Text("View All Reviews")
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
                    NavigationLink(destination: SettingsView()) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Settings")
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
            .confirmationDialog("Choose Photo Source", isPresented: $showImageSourceSheet, titleVisibility: .visible) {
                Button("Take Photo") {
                    imageSourceType = .camera
                    showImagePicker = true
                }
                Button("Choose from Library") {
                    imageSourceType = .photoLibrary
                    showImagePicker = true
                }
                if authService.userProfile?.profilePictureUrl != nil {
                    Button("Remove Photo", role: .destructive) {
                        removeProfilePicture()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $profileImage, sourceType: imageSourceType)
            }
            .onChange(of: profileImage) { _, newImage in
                if let image = newImage {
                    uploadProfilePicture(image: image)
                }
            }
        }
        .task {
            guard let currentUser = authService.currentUser else { return }
            
            let userId = currentUser.id
            let isPilot = authService.userProfile?.userType == .pilot
            
            // Load pilot stats if pilot
            if isPilot {
                try? await rankingService.getPilotStats(pilotId: userId)
            }
            
            // Load ratings summary
            isLoadingRatings = true
            do {
                ratingSummary = try await ratingService.getUserRatingSummary(userId: userId)
            } catch {
                print("Error loading rating summary: \(error)")
            }
            
            // Load completed bookings count
            do {
                completedBookingsCount = try await bookingService.getCompletedBookingsCount(userId: userId, isPilot: isPilot)
            } catch {
                print("Error loading completed bookings count: \(error)")
            }
            isLoadingRatings = false
        }
    }
    
    private func uploadProfilePicture(image: UIImage) {
        guard let currentUser = authService.currentUser else { return }
        
        Task {
            do {
                _ = try await profilePictureService.uploadProfilePicture(userId: currentUser.id, image: image)
                // Refresh profile to show new picture
                await authService.checkAuthStatus()
            } catch {
                print("Error uploading profile picture: \(error)")
            }
        }
    }
    
    private func removeProfilePicture() {
        guard let currentUser = authService.currentUser else { return }
        
        Task {
            do {
                try await profilePictureService.deleteProfilePicture(userId: currentUser.id)
                // Refresh profile to remove picture
                await authService.checkAuthStatus()
            } catch {
                print("Error removing profile picture: \(error)")
            }
        }
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var profileService = ProfileService()
    @Environment(\.dismiss) var dismiss
    
    @State private var firstName = ""
    @State private var lastName = ""
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
                TextField("First Name", text: $firstName)
                    .textContentType(.givenName)
                
                TextField("Last Name", text: $lastName)
                    .textContentType(.familyName)
                
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
        firstName = authService.userProfile?.firstName ?? ""
        lastName = authService.userProfile?.lastName ?? ""
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
                    firstName: firstName,
                    lastName: lastName,
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

