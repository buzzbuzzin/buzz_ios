//
//  PublicProfileView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct PublicProfileView: View {
    let pilotId: UUID
    @EnvironmentObject var authService: AuthService
    @StateObject private var profileService = ProfileService()
    @StateObject private var rankingService = RankingService()
    @StateObject private var ratingService = RatingService()
    @StateObject private var bookingService = BookingService()
    @StateObject private var badgeService = BadgeService()
    @StateObject private var droneRegistrationService = DroneRegistrationService()
    @StateObject private var academyService = AcademyService()
    
    @State private var pilotProfile: UserProfile?
    @State private var pilotStats: PilotStats?
    @State private var ratingSummary: UserRatingSummary?
    @State private var completedBookingsCount = 0
    @State private var completedCourses: [TrainingCourse] = []
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var showError = false
    
    var isOwnProfile: Bool {
        authService.currentUser?.id == pilotId
    }
    
    var yearsOnBuzz: Int {
        guard let createdAt = pilotProfile?.createdAt else { return 0 }
        let calendar = Calendar.current
        let years = calendar.dateComponents([.year], from: createdAt, to: Date()).year ?? 0
        return max(years, 0)
    }
    
    var body: some View {
        List {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 40)
                }
            } else if let profile = pilotProfile {
                // Profile Header Card
                Section {
                    HStack(spacing: 16) {
                        Spacer()
                        
                        // Profile Picture and Info (centered)
                        VStack(spacing: 8) {
                            // Profile Picture
                            Group {
                                if let pictureUrl = profile.profilePictureUrl,
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
                            
                            // Name, Call Sign, and Ratings below picture
                            VStack(alignment: .center, spacing: 4) {
                                // Show callsign for pilots
                                if let callSign = profile.callSign, !callSign.isEmpty {
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
                                if let summary = ratingSummary {
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
                        if let stats = pilotStats {
                            VStack(alignment: .leading, spacing: 16) {
                                // Flights
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(completedBookingsCount)")
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
                
                // Badges Section
                Section {
                    if badgeService.badges.isEmpty {
                        Text("No badges yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(badgeService.badges) { badge in
                                    BadgePreviewCard(badge: badge)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Badges")
                }
                
                // Equipment Section (Drone Registrations)
                Section {
                    if droneRegistrationService.registrations.isEmpty {
                        Text("No equipment registered")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(droneRegistrationService.registrations) { registration in
                            EquipmentRow(registration: registration)
                        }
                    }
                } header: {
                    Text("Equipment")
                }
                
                // Completed Courses Section
                Section {
                    if completedCourses.isEmpty {
                        Text("No completed courses yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(completedCourses) { course in
                            CompletedCourseRow(course: course)
                        }
                    }
                } header: {
                    Text("Completed Courses")
                }
            } else {
                Section {
                    Text("Profile not found")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 40)
                }
            }
        }
        .navigationTitle(isOwnProfile ? "My Profile" : "Pilot Profile")
        .navigationBarTitleDisplayMode(.large)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            await loadProfileData()
        }
    }
    
    private func loadProfileData() async {
        isLoading = true
        
        do {
            // Load pilot profile
            pilotProfile = try await profileService.getProfile(userId: pilotId)
            
            // Load pilot stats
            try? await rankingService.getPilotStats(pilotId: pilotId)
            pilotStats = rankingService.pilotStats
            
            // Load ratings summary
            ratingSummary = try? await ratingService.getUserRatingSummary(userId: pilotId)
            
            // Load completed bookings count
            do {
                completedBookingsCount = try await bookingService.getCompletedBookingsCount(userId: pilotId, isPilot: true)
            } catch {
                print("Error loading completed bookings count: \(error)")
            }
            
            // Load badges
            try? await badgeService.fetchPilotBadges(pilotId: pilotId)
            
            // Load drone registrations
            try? await droneRegistrationService.fetchRegistrations(pilotId: pilotId)
            
            // Load completed courses
            do {
                completedCourses = try await academyService.fetchCompletedCourses(pilotId: pilotId)
            } catch {
                print("Error loading completed courses: \(error)")
                completedCourses = []
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Equipment Row

struct EquipmentRow: View {
    let registration: DroneRegistration
    
    var body: some View {
        HStack {
            if let manufacturer = registration.manufacturer, let model = registration.model {
                Text("\(manufacturer) \(model)")
                    .font(.headline)
            } else {
                Text("Drone Registration")
                    .font(.headline)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Completed Course Row

struct CompletedCourseRow: View {
    let course: TrainingCourse
    
    var body: some View {
        HStack(spacing: 12) {
            // Course Icon
            ZStack {
                Circle()
                    .fill(course.provider.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: course.category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(course.provider.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(course.category.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: course.provider.icon)
                        .font(.caption)
                        .foregroundColor(course.provider.color)
                    Text(course.provider.rawValue)
                        .font(.caption)
                        .foregroundColor(course.provider.color)
                }
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
        }
        .padding(.vertical, 4)
    }
}

