//
//  PilotProfileView.swift
//  Buzz
//
//  Created for pilot-specific profile view with Statistics section
//

import SwiftUI
import Auth
import PhotosUI
import UIKit

struct PilotProfileView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var rankingService = RankingService()
    @StateObject private var ratingService = RatingService()
    @StateObject private var profilePictureService = ProfilePictureService()
    @StateObject private var badgeService = BadgeService()
    @State private var examinerStats: ExaminerStats?
    @State private var showSignOutAlert = false
    @State private var showImagePicker = false
    @State private var showImageSourceSheet = false
    @State private var showVerificationWarning = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var profileImage: UIImage?
    @State private var ratingSummary: UserRatingSummary?
    @State private var isLoadingRatings = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var navigateToReviews = false
    @State private var navigateToBalance = false
    @State private var navigateToConnections = false
    @State private var navigateToLicenses = false
    @State private var deepLinkLicenseId: UUID?
    @StateObject private var licenseNotificationService = LicenseUploadService()
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    
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
                    showVerificationWarning = true
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
                                    Image(systemName: "airplane.circle.fill")
                                        .font(.system(size: 90))
                                        .foregroundColor(.blue)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Image(systemName: "airplane.circle.fill")
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
                
                // Call Sign and Ratings below picture
                VStack(alignment: .center, spacing: 4) {
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
            if let stats = rankingService.pilotStats {
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
                        destination: BalanceView(),
                        isActive: $navigateToBalance
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
                        destination: LicenseManagementView(highlightLicenseId: deepLinkLicenseId)
                            .onDisappear {
                                navigateToLicenses = false
                                deepLinkLicenseId = nil
                            },
                        isActive: $navigateToLicenses
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
                
                List {
                    // Profile Header
                    Section {
                        if let currentUser = authService.currentUser {
                            NavigationLink(destination: PublicProfileView(pilotId: currentUser.id)) {
                                profileHeaderContent
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            profileHeaderContent
                        }
                    }
                    
                    // Badges Section
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
                                    let previewBadges = Array(badgeService.badges.prefix(8))
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                                        ForEach(previewBadges) { badge in
                                            BadgePreviewCard(badge: badge)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Reviews and Balance Cards
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
                                    
                                    Button(action: {
                                        navigateToBalance = true
                                    }) {
                                        ProfileCard(
                                            icon: "dollarsign.circle.fill",
                                            iconColor: .green,
                                            title: "Balance"
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .frame(maxWidth: .infinity)
                                }
                                
                                // Connections Button
                                Button(action: {
                                    navigateToConnections = true
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "person.2.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.green)
                                            .frame(width: 40, height: 40)
                                            .background(Color.green.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Text("Connections")
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
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                    }
                
                // Statistics Section
                Section {
                    if let stats = rankingService.pilotStats {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Rank")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(stats.tierName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                                .font(.body)
                                .frame(width: 24)
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
                                .frame(width: 24)
                            Text("Completed Bookings")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(stats.completedBookings)")
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }

                        // Examiner/Proctor stats (only show if user has activity)
                        if let examinerStats = examinerStats, examinerStats.hasActivity {
                            if examinerStats.flightReviewCount > 0 {
                                HStack {
                                    Image(systemName: "person.text.rectangle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.body)
                                        .frame(width: 24)
                                    Text("Flight Reviews Conducted")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(examinerStats.flightReviewCount)")
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                            }

                            if examinerStats.rocAExamCount > 0 {
                                HStack {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .foregroundColor(.secondary)
                                        .font(.body)
                                        .frame(width: 24)
                                    Text("ROC-A Exams Proctored")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(examinerStats.rocAExamCount)")
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    } else if rankingService.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } header: {
                    Text("Statistics")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // License Management
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
                    
                    NavigationLink(destination: LicenseManagementView()
                        .onDisappear {
                            if let userId = authService.currentUser?.id {
                                Task {
                                    await licenseNotificationService.fetchUnreadNotificationCount(pilotId: userId)
                                }
                            }
                        }
                    ) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .foregroundColor(.secondary)
                                .font(.body)
                                .frame(width: 24)
                            Text("Pilot Licenses")
                                .foregroundColor(.primary)
                            Spacer()
                            if licenseNotificationService.unreadNotificationCount > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                            }
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
                    
                    NavigationLink(destination: InsuranceView()) {
                        HStack {
                            Image(systemName: "shield.fill")
                                .foregroundColor(.secondary)
                                .font(.body)
                                .frame(width: 24)
                            Text("Insurance")
                                .foregroundColor(.primary)
                        }
                    }
                } header: {
                    Text("License")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                    
                    // Buzz Academy Pass
                    if let userId = authService.currentUser?.id {
                        NavigationLink(destination: AcademyPassManagementView(pilotId: userId)) {
                            HStack {
                                Image(systemName: "graduationcap.fill")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                    .frame(width: 24)
                                Text("Buzz Academy Pass")
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
            
            // Load pilot stats
            try? await rankingService.getPilotStats(pilotId: userId)
            
            // Load ratings summary
            isLoadingRatings = true
            do {
                ratingSummary = try await ratingService.getUserRatingSummary(userId: userId)
            } catch {
                print("Error loading rating summary: \(error)")
            }
            
            // Load badges
            try? await badgeService.fetchPilotBadges(pilotId: userId)

            // Load examiner/proctor stats
            examinerStats = await ExamService.shared.fetchExaminerStats(examinerId: userId)

            // Load license notification count
            await licenseNotificationService.fetchUnreadNotificationCount(pilotId: userId)

            isLoadingRatings = false
        }
        .onAppear {
            if case .licenseManagement(let licenseId) = deepLinkManager.pendingDestination {
                deepLinkManager.pendingDestination = nil
                deepLinkLicenseId = licenseId
                navigateToLicenses = true
            }
        }
        .onChange(of: deepLinkManager.pendingDestination) { _, destination in
            if case .licenseManagement(let licenseId) = destination {
                deepLinkManager.pendingDestination = nil
                deepLinkLicenseId = licenseId
                navigateToLicenses = true
            }
        }
    }

    private func uploadProfilePicture(image: UIImage) {
        guard let currentUser = authService.currentUser else { return }
        
        Task {
            do {
                print("DEBUG PilotProfileView: Starting profile picture upload...")
                let url = try await profilePictureService.uploadProfilePicture(userId: currentUser.id, image: image)
                print("DEBUG PilotProfileView: Upload completed, URL: \(url)")
                await authService.checkAuthStatus()
                print("DEBUG PilotProfileView: Auth status refreshed")
            } catch {
                print("DEBUG PilotProfileView: Upload error: \(error.localizedDescription)")
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

