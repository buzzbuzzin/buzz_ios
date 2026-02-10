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
    @StateObject private var hangerTalkService = HangerTalkService()

    @State private var pilotProfile: UserProfile?
    @State private var isFollowingPilot = false
    @State private var followerCount = 0
    @State private var followingCount = 0
    @State private var pilotStats: PilotStats?
    @State private var ratingSummary: UserRatingSummary?
    @State private var completedCourses: [TrainingCourse] = []
    @State private var pilotPosts: [HangerTalkPostWithAuthor] = []
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var navigateToProfileId: UUID?
    
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
            // Preview Note Section (only show if viewing own profile)
            if isOwnProfile {
                Section {
                    HStack(spacing: 8) {
                        Text("This is a preview of your public profile as it appears to other pilots.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color(.systemGray6))
            }
            
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

                                // Rank below rating
                                if let stats = pilotStats {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(tierColor(for: stats.tier))
                                            .frame(width: 8, height: 8)
                                        Text(stats.tierName)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(tierColor(for: stats.tier))
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Statistics on the right
                        VStack(alignment: .leading, spacing: 16) {
                            if let stats = pilotStats {
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
                            }

                            // Followers
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(followerCount)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("Followers")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(followingCount)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("Following")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Message & Follow Buttons (only show if not own profile)
                if !isOwnProfile {
                    Section {
                        // Follow / Unfollow
                        Button {
                            Task {
                                guard let myId = authService.currentUser?.id else { return }
                                let nowFollowing = try? await hangerTalkService.toggleFollow(
                                    followerId: myId, followingId: pilotId)
                                isFollowingPilot = nowFollowing ?? false
                                let counts = await hangerTalkService.fetchFollowCounts(userId: pilotId)
                                followerCount = counts.followers
                                followingCount = counts.following
                            }
                        } label: {
                            HStack {
                                Image(systemName: isFollowingPilot ? "person.badge.minus" : "person.badge.plus")
                                    .font(.title3)
                                    .foregroundColor(isFollowingPilot ? .red : .blue)
                                Text(isFollowingPilot ? "Unfollow" : "Follow")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())

                        NavigationLink(destination: DirectMessageView(pilotId: pilotId, pilotProfile: profile)) {
                            HStack {
                                Image(systemName: "message.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                Text("Send Message")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Badges Section
                Section {
                    if badgeService.badges.isEmpty {
                        Text("No badges yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 80), spacing: 12)
                        ], spacing: 12) {
                            ForEach(badgeService.badges) { badge in
                                BadgePreviewCard(badge: badge)
                            }
                        }
                        .padding(.vertical, 4)
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

                // Hanger Talk Section
                Section {
                    if pilotPosts.isEmpty {
                        Text("No posts yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(pilotPosts.prefix(3)) { postWithAuthor in
                            NavigationLink(destination: HangerTalkPostDetailView(postWithAuthor: postWithAuthor).environmentObject(authService)) {
                                CommunityPostRow(postWithAuthor: postWithAuthor)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        if pilotPosts.count > 3 {
                            NavigationLink(destination: PilotPostsListView(pilotId: pilotId).environmentObject(authService)) {
                                HStack {
                                    Text("See All Posts")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                } header: {
                    Text("Hanger Talk")
                }
            } else {
                Section {
                    Text("Profile not found")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 40)
                }
            }
        }
        .navigationTitle("Pilot Profile")
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
    
    private func tierColor(for tier: Int) -> Color {
        switch tier {
        case 0: return .gray
        case 1: return .brown
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        default: return .gray
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
            
            // Load badges
            try? await badgeService.fetchPilotBadges(pilotId: pilotId)
            
            // Load drone registrations
            try? await droneRegistrationService.fetchRegistrations(pilotId: pilotId)
            
            // Sync progress for all enrolled courses, then load completed courses
            await academyService.syncAllCourseProgress(pilotId: pilotId)
            do {
                completedCourses = try await academyService.fetchCompletedCourses(pilotId: pilotId)
            } catch {
                print("Error loading completed courses: \(error)")
                completedCourses = []
            }

            // Load follow state and counts
            if let myId = authService.currentUser?.id, !isOwnProfile {
                isFollowingPilot = await hangerTalkService.isFollowing(followerId: myId, followingId: pilotId)
            }
            let counts = await hangerTalkService.fetchFollowCounts(userId: pilotId)
            followerCount = counts.followers
            followingCount = counts.following

            // Load pilot's hanger talk posts
            let currentUserId = authService.currentUser?.id ?? UUID()
            pilotPosts = await hangerTalkService.fetchUserPosts(authorId: pilotId, currentUserId: currentUserId)

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Community Post Row

struct CommunityPostRow: View {
    let postWithAuthor: HangerTalkPostWithAuthor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(postWithAuthor.post.body)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(3)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "heart")
                        .font(.caption2)
                    Text("\(postWithAuthor.post.likeCount)")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.caption2)
                    Text("\(postWithAuthor.post.replyCount)")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)

                Spacer()

                Text(postWithAuthor.post.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
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
            // Course Image or Icon
            if let coverImageUrl = course.coverImageUrl, !coverImageUrl.isEmpty {
                AsyncImage(url: URL(string: coverImageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Circle()
                                .fill(course.provider.color.opacity(0.2))
                                .frame(width: 50, height: 50)
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(course.provider.color.opacity(0.3), lineWidth: 2)
                            )
                    case .failure:
                        ZStack {
                            Circle()
                                .fill(course.provider.color.opacity(0.2))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: course.category.icon)
                                .font(.system(size: 24))
                                .foregroundColor(course.provider.color)
                        }
                    @unknown default:
                        ZStack {
                            Circle()
                                .fill(course.provider.color.opacity(0.2))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: course.category.icon)
                                .font(.system(size: 24))
                                .foregroundColor(course.provider.color)
                        }
                    }
                }
            } else {
                // Default icon when no cover image
                ZStack {
                    Circle()
                        .fill(course.provider.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: course.category.icon)
                        .font(.system(size: 24))
                        .foregroundColor(course.provider.color)
                }
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


