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
    @StateObject private var badgeService = BadgeService()
    @State private var showSignOutAlert = false
    @State private var showImagePicker = false
    @State private var showImageSourceSheet = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var profileImage: UIImage?
    @State private var ratingSummary: UserRatingSummary?
    @State private var completedBookingsCount = 0
    @State private var isLoadingRatings = false
    
    var yearsOnBuzz: Int {
        guard let createdAt = authService.userProfile?.createdAt else { return 0 }
        let calendar = Calendar.current
        let years = calendar.dateComponents([.year], from: createdAt, to: Date()).year ?? 0
        return max(years, 0)
    }
    
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
                            
                            // Ratings below call sign
                            if isLoadingRatings && ratingSummary == nil {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if let summary = ratingSummary {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.subheadline)
                                    Text(String(format: "%.1f", summary.averageRating))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("(\(summary.totalRatings))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.gray)
                                        .font(.subheadline)
                                    Text("—")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    Text("No ratings")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Statistics on the right
                        if authService.userProfile?.userType == .pilot, let stats = rankingService.pilotStats {
                            VStack(alignment: .trailing, spacing: 16) {
                                // Flights
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(completedBookingsCount)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("Flights")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Flight Hours
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "%.0f", stats.totalFlightHours))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("Flight hours")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Years on Buzz
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(yearsOnBuzz)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("Years on Buzz")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            // For customers, show Flights and Years on Buzz
                            VStack(alignment: .trailing, spacing: 16) {
                                // Flights
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(completedBookingsCount)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("Flights")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Divider()
                                
                                // Years on Buzz
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(yearsOnBuzz)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("Years on Buzz")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Badges Section (Pilot only)
                if authService.userProfile?.userType == .pilot {
                    Section {
                        NavigationLink(destination: BadgesView()) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Badges")
                                        .font(.headline)
                                    Spacer()
                                    if !badgeService.badges.isEmpty {
                                        Text("\(badgeService.badges.count)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if badgeService.badges.isEmpty {
                                    Text("Complete courses to earn badges")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 4)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(badgeService.badges.prefix(5)) { badge in
                                                BadgePreviewCard(badge: badge)
                                            }
                                            
                                            if badgeService.badges.count > 5 {
                                                VStack {
                                                    Image(systemName: "ellipsis")
                                                        .font(.title2)
                                                        .foregroundColor(.secondary)
                                                    Text("+\(badgeService.badges.count - 5)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                .frame(width: 50, height: 50)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
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
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                Text("Flight Hours")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(String(format: "%.1f hrs", stats.totalFlightHours))
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                                                        
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                Text("Completed Bookings")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(completedBookingsCount)")
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
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
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.secondary)
                                .font(.body)
                            Text("Completed Bookings")
                                .foregroundColor(.primary)
                            Spacer()
                            if isLoadingRatings {
                                ProgressView()
                            } else {
                                Text("\(completedBookingsCount)")
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    // View All Ratings Link
                    if let summary = ratingSummary, summary.totalRatings > 0, let currentUser = authService.currentUser {
                        NavigationLink(destination: RatingsListView(userId: currentUser.id)) {
                            HStack {
                                Image(systemName: "star")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                Text("View All Reviews")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                
                // License Management (if pilot)
                if authService.userProfile?.userType == .pilot {
                    Section {
                        NavigationLink(destination: LicenseManagementView()) {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                Text("Manage Licenses")
                                    .foregroundColor(.primary)
                            }
                        }
                    } header: {
                        Text("License")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Account
                Section {
                    NavigationLink(destination: SettingsView()) {
                        HStack {
                            Image(systemName: "gearshape")
                                .foregroundColor(.secondary)
                                .font(.body)
                            Text("Settings")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    NavigationLink(destination: HelpView()) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.secondary)
                                .font(.body)
                            Text("Help")
                                .foregroundColor(.primary)
                        }
                    }
                                        
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                                .font(.body)
                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("Account")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
            
            // Load badges if pilot
            if isPilot {
                try? await badgeService.fetchPilotBadges(pilotId: userId)
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
                    phone: phone,
                    gender: nil
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

