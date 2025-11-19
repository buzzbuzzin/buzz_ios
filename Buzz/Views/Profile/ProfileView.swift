//
//  ProfileView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import Auth
import PhotosUI
import UIKit

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
    @State private var showVerificationWarning = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var profileImage: UIImage?
    @State private var ratingSummary: UserRatingSummary?
    @State private var customerBookingsCount = 0  // Only used for customers
    @State private var isLoadingRatings = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var navigateToReviews = false
    @State private var navigateToFlightPackages = false
    
    var yearsOnBuzz: Int {
        guard let createdAt = authService.userProfile?.createdAt else { return 0 }
        let calendar = Calendar.current
        let years = calendar.dateComponents([.year], from: createdAt, to: Date()).year ?? 0
        return max(years, 0)
    }
    
    var profileHeaderContent: some View {
        HStack(spacing: 16) {
            Spacer()
            
            // Profile Picture and Info (centered)
            VStack(spacing: 8) {
                // Profile Picture (clickable to upload)
                Button(action: {
                    // Show warning for pilots, then allow upload
                    if authService.userProfile?.userType == .pilot {
                        showVerificationWarning = true
                    } else {
                        showImageSourceSheet = true
                    }
                }) {
                    Group {
                        if let pictureUrl = authService.userProfile?.profilePictureUrl,
                           let url = URL(string: pictureUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 90, height: 90)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                case .failure:
                                    Image(systemName: authService.userProfile?.userType == .pilot ? "airplane.circle.fill" : "person.circle.fill")
                                        .font(.system(size: 90))
                                        .foregroundColor(.blue)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Image(systemName: authService.userProfile?.userType == .pilot ? "airplane.circle.fill" : "person.circle.fill")
                                .font(.system(size: 90))
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
                            .offset(x: 32, y: 32)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Name, Call Sign, and Ratings below picture
                VStack(alignment: .center, spacing: 4) {
                    // For pilots, show callsign instead of first name
                    if authService.userProfile?.userType == .pilot {
                        if let callSign = authService.userProfile?.callSign, !callSign.isEmpty {
                            Text("@\(callSign)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        } else {
                            Text("Pilot")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    } else {
                        Text(authService.userProfile?.firstName ?? "User")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    // Ratings below call sign
                    if isLoadingRatings && ratingSummary == nil {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let summary = ratingSummary {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text(String(format: "%.1f", summary.averageRating))
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("(\(summary.totalRatings))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.gray)
                                .font(.caption)
                            Text("—")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Text("No ratings")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Statistics on the right
            if authService.userProfile?.userType == .pilot, let stats = rankingService.pilotStats {
                VStack(alignment: .leading, spacing: 16) {
                    // Flights
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(stats.completedBookings)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Flights")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Flight Hours
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.0f", stats.totalFlightHours))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Flight hours")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Years on Buzz
                    VStack(alignment: .leading, spacing: 2) {
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
                VStack(alignment: .leading, spacing: 16) {
                    // Flights (customers don't have pilot_stats, keep using actual bookings count)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(customerBookingsCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Jobs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Years on Buzz
                    VStack(alignment: .leading, spacing: 2) {
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
    
    var body: some View {
        NavigationView {
            ZStack {
                // Hidden navigation links (outside List to avoid creating rows)
                if let currentUser = authService.currentUser {
                    NavigationLink(
                        destination: RatingsListView(userId: currentUser.id),
                        isActive: $navigateToReviews
                    ) {
                        EmptyView()
                    }
                    .hidden()
                    
                    NavigationLink(
                        destination: FlightPackagesView(),
                        isActive: $navigateToFlightPackages
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
                
                List {
                    // Profile Header
                Section {
                    // For pilots, wrap in NavigationLink to public profile
                    if authService.userProfile?.userType == .pilot, let currentUser = authService.currentUser {
                        NavigationLink(destination: PublicProfileView(pilotId: currentUser.id)) {
                            profileHeaderContent
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        profileHeaderContent
                    }
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
                
                // Reviews and Flight Packages Cards
                if let currentUser = authService.currentUser {
                    if authService.userProfile?.userType == .customer {
                        // Two cards side by side for customers
                        Section {
                            HStack(spacing: 8) {
                                Button(action: {
                                    navigateToReviews = true
                                }) {
                                    ProfileCard(
                                        icon: "star.fill",
                                        iconColor: .yellow,
                                        title: "Reviews"
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(maxWidth: .infinity)
                                
                                Button(action: {
                                    navigateToFlightPackages = true
                                }) {
                                    ProfileCard(
                                        icon: "gift.fill",
                                        iconColor: .blue,
                                        title: "Flight Packages"
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(maxWidth: .infinity)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                    } else {
                        // Single card for pilots (only Reviews)
                        Section {
                            Button(action: {
                                navigateToReviews = true
                            }) {
                                ProfileCard(
                                    icon: "star.fill",
                                    iconColor: .yellow,
                                    title: "Reviews"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                
                // Balance Section (Pilot only)
                if authService.userProfile?.userType == .pilot {
                    Section {
                        NavigationLink(destination: BalanceView()) {
                            HStack {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.body)
                                    .frame(width: 24)
                                Text("Balance")
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                }
                
                // License Management (if pilot)
                if authService.userProfile?.userType == .pilot {
                    Section {
                        NavigationLink(destination: GovernmentIDView()) {
                            HStack {
                                Image(systemName: "person.badge.key.fill")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                    .frame(width: 24)
                                Text("Government ID")
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        NavigationLink(destination: LicenseManagementView()) {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                    .frame(width: 24)
                                Text("Pilot Licenses")
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        NavigationLink(destination: DroneRegistrationView()) {
                            HStack {
                                Image(systemName: "airplane")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                    .frame(width: 24)
                                Text("Drone Registration")
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
                                .frame(width: 24)
                            Text("Settings")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Saved Payments (Customer only)
                    if authService.userProfile?.userType == .customer {
                        NavigationLink(destination: SavedPaymentsView()) {
                            HStack {
                                Image(systemName: "creditcard")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                    .frame(width: 24)
                                Text("Saved Payments")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    if authService.userProfile?.userType == .pilot {
                        NavigationLink(destination: TaxDocumentView()) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                    .frame(width: 24)
                                Text("Tax Document")
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        NavigationLink(destination: StripeAccountSetupView()) {
                            HStack {
                                Image(systemName: "creditcard.fill")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                    .frame(width: 24)
                                Text("Payment Account")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    NavigationLink(destination: HelpView()) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.secondary)
                                .font(.body)
                                .frame(width: 24)
                            Text("Get Help")
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
                                .frame(width: 24)
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
            .alert("Profile Picture Guidelines", isPresented: $showVerificationWarning) {
                Button("Cancel", role: .cancel) {}
                Button("I Understand") {
                    showImageSourceSheet = true
                }
            } message: {
                Text("Please use a real selfie that matches your face. If you use a fake selfie and it is reported by others, your account may be suspended as a penalty.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
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
            
            // Load completed bookings count (only for customers, pilots use pilot_stats)
            if !isPilot {
                do {
                    customerBookingsCount = try await bookingService.getCompletedBookingsCount(userId: userId, isPilot: isPilot)
                } catch {
                    print("Error loading completed bookings count: \(error)")
                }
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
                print("DEBUG ProfileView: Starting profile picture upload...")
                let url = try await profilePictureService.uploadProfilePicture(userId: currentUser.id, image: image)
                print("DEBUG ProfileView: Upload completed, URL: \(url)")
                // Refresh profile to show new picture
                print("DEBUG ProfileView: Refreshing auth status...")
                await authService.checkAuthStatus()
                print("DEBUG ProfileView: Auth status refreshed")
            } catch {
                print("DEBUG ProfileView: Upload error: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
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

// MARK: - Profile Card Component

struct ProfileCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(iconColor)
                .frame(width: 60, height: 60)
                .background(iconColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Title
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 0.5)
        )
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

