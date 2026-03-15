//
//  CustomerProfileView.swift
//  Buzz
//
//  Created for customer-specific profile view with card-based design
//

import SwiftUI
import Auth
import PhotosUI
import UIKit

struct CustomerProfileView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var ratingService = RatingService()
    @StateObject private var bookingService = BookingService()
    @StateObject private var profilePictureService = ProfilePictureService()
    @State private var showSignOutAlert = false
    @State private var showImagePicker = false
    @State private var showImageSourceSheet = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var profileImage: UIImage?
    @State private var ratingSummary: UserRatingSummary?
    @State private var customerBookingsCount = 0
    @State private var isLoadingRatings = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var navigateToReviews = false
    @State private var navigateToFlightPackages = false
    @State private var navigateToConnections = false
    @State private var navigateToShop = false
    @State private var navigateToBecomePilot = false
    
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
                    showImageSourceSheet = true
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
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 90))
                                        .foregroundColor(.blue)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
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
                .accessibilityLabel("Profile picture")
                .accessibilityHint("Double tap to change your profile picture")

                // Name and Ratings below picture
                VStack(alignment: .center, spacing: 4) {
                    Text(authService.userProfile?.firstName ?? "User")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Ratings below name
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
            VStack(alignment: .leading, spacing: 16) {
                // Jobs
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(customerBookingsCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Jobs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)

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
                .accessibilityElement(children: .combine)
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
                    
                    NavigationLink(
                        destination: ConnectionsView(),
                        isActive: $navigateToConnections
                    ) {
                        EmptyView()
                    }
                    .hidden()
                    
                    NavigationLink(
                        destination: ClientShopView(),
                        isActive: $navigateToShop
                    ) {
                        EmptyView()
                    }
                    .hidden()
                    
                    NavigationLink(
                        destination: BecomePilotView(),
                        isActive: $navigateToBecomePilot
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
                
                List {
                    // Profile Header
                    Section {
                        profileHeaderContent
                    }
                    
                    // Reviews, Flight Packages, and Shop Cards
                    if let currentUser = authService.currentUser {
                        Section {
                            VStack(spacing: 8) {
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
                                    .accessibilityLabel("Reviews")
                                    .accessibilityHint("View your reviews")

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
                                    .accessibilityLabel("Flight Packages")
                                    .accessibilityHint("View your flight packages")
                                }
                                
                                HStack(spacing: 8) {
                                    Button(action: {
                                        navigateToConnections = true
                                    }) {
                                        ProfileCard(
                                            icon: "person.2.fill",
                                            iconColor: .green,
                                            title: "Connections"
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .frame(maxWidth: .infinity)
                                    .accessibilityLabel("Connections")
                                    .accessibilityHint("View your connections")

                                    Button(action: {
                                        navigateToShop = true
                                    }) {
                                        ProfileCard(
                                            icon: "bag.fill",
                                            iconColor: .pink,
                                            title: "Shop"
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .frame(maxWidth: .infinity)
                                    .accessibilityLabel("Shop")
                                    .accessibilityHint("Browse the shop")
                                }
                                
                                // Become a Pilot Button
                                Button(action: {
                                    navigateToBecomePilot = true
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "person.badge.plus")
                                            .font(.system(size: 24))
                                            .foregroundColor(.blue)
                                            .frame(width: 40, height: 40)
                                            .background(Color.blue.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Text("Become a Pilot")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 100)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(.separator).opacity(0.2), lineWidth: 0.5)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel("Become a Pilot")
                                .accessibilityHint("Double tap to start the pilot application process")
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
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
                        .accessibilityLabel("Settings")

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
                        .accessibilityLabel("Saved Payments")

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
                        .accessibilityLabel("Get Help")

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
                        .accessibilityLabel("Sign Out")
                        .accessibilityHint("Double tap to sign out of your account")
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
            
            // Load ratings summary
            isLoadingRatings = true
            do {
                ratingSummary = try await ratingService.getUserRatingSummary(userId: userId)
            } catch {
                print("Error loading rating summary: \(error)")
            }
            
            // Load completed bookings count
            do {
                customerBookingsCount = try await bookingService.getCompletedBookingsCount(userId: userId, isPilot: false)
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
                print("DEBUG CustomerProfileView: Starting profile picture upload...")
                let url = try await profilePictureService.uploadProfilePicture(userId: currentUser.id, image: image)
                print("DEBUG CustomerProfileView: Upload completed, URL: \(url)")
                await authService.checkAuthStatus()
                print("DEBUG CustomerProfileView: Auth status refreshed")
            } catch {
                print("DEBUG CustomerProfileView: Upload error: \(error.localizedDescription)")
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
                await authService.checkAuthStatus()
            } catch {
                print("Error removing profile picture: \(error)")
            }
        }
    }
}

