//
//  AcademyView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Foundation
import Auth

struct AcademyView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedCategory: TrainingCourse.CourseCategory? = nil
    @State private var selectedProvider: TrainingCourse.CourseProvider? = nil
    @State private var courses: [TrainingCourse] = []
    @State private var recurrentNotices: [RecurrentTrainingNotice] = []
    @State private var isLoading = false
    @State private var isFetching = false // Track if fetch is in progress
    @State private var fetchTask: Task<Void, Never>? = nil // Store the current fetch task
    @State private var showRecurrentNotices = true
    @StateObject private var courseSubscriptionService = CourseSubscriptionService()
    @State private var hasSubscription = false
    @State private var isPromotionCardDismissed = false
    
    func toggleEnrollment(for courseId: UUID) {
        if let index = courses.firstIndex(where: { $0.id == courseId }) {
            courses[index].isEnrolled.toggle()
        }
    }
    
    private let allCategories: [TrainingCourse.CourseCategory] = [
        .safety, .operations, .photography, .cinematography, .inspection, .mapping
    ]
    
    private let allProviders: [TrainingCourse.CourseProvider] = [
        .buzz, .amazon, .tmobile, .other
    ]
    
    var filteredCourses: [TrainingCourse] {
        var filtered = courses
        
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        if let provider = selectedProvider {
            filtered = filtered.filter { $0.provider == provider }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Recurrent Training Notices Section
                if showRecurrentNotices && !recurrentNotices.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Recurrent Training Due")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                            Button(action: {
                                showRecurrentNotices.toggle()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(recurrentNotices) { notice in
                                    RecurrentTrainingCard(notice: notice)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                    }
                    .background(Color(.systemGray6))
                }
                
                // UAS Pilot Course Promotion Section
                // Show promotion card for UAS Pilot Course (only if not dismissed and no subscription)
                if let uasCourse = courses.first(where: { 
                    $0.id.uuidString.lowercased() == "a1b2c3d4-e5f6-7890-abcd-ef1234567890" ||
                    $0.title.lowercased().contains("uas pilot")
                }), !hasSubscription && !isPromotionCardDismissed {
                    UASPilotCoursePromotionCard(
                        course: uasCourse,
                        hasSubscription: hasSubscription,
                        onDismiss: {
                            isPromotionCardDismissed = true
                        }
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                }
                
                // Provider Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // All Providers Button
                        ProviderChip(
                            title: "All Providers",
                            icon: "square.grid.2x2",
                            isSelected: selectedProvider == nil
                        ) {
                            selectedProvider = nil
                        }
                        
                        ForEach(allProviders, id: \.self) { provider in
                            ProviderChip(
                                title: provider.rawValue,
                                icon: provider.icon,
                                isSelected: selectedProvider == provider,
                                color: provider.color
                            ) {
                                selectedProvider = provider
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemGray6))
                
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // All Categories Button
                        CategoryChip(
                            title: "All",
                            icon: "square.grid.2x2",
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                        }
                        
                        ForEach(allCategories, id: \.self) { category in
                            CategoryChip(
                                title: category.rawValue,
                                icon: category.icon,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGray6))
                
                // Courses List
                if isLoading {
                    LoadingView(message: "Loading courses...")
                } else if filteredCourses.isEmpty {
                    EmptyStateView(
                        icon: "book.closed",
                        title: "No Courses Available",
                        message: "Check back soon for new training courses"
                    )
                } else {
                    List {
                        ForEach(filteredCourses) { course in
                            NavigationLink(destination: CourseDetailView(
                                course: courses.first(where: { $0.id == course.id }) ?? course,
                                onEnrollmentChange: { 
                                    toggleEnrollment(for: course.id)
                                    // Reload courses from backend to ensure sync
                                    Task {
                                        await loadCourses()
                                    }
                                }
                            )) {
                                CourseCard(course: courses.first(where: { $0.id == course.id }) ?? course)
                            }
                        }
                    }
                    // .refreshable disabled temporarily due to SwiftUI refresh control cancellation issues
                    // TODO: Re-enable once cancellation issue is resolved
                }
            }
            .navigationTitle("Academy")
            .task {
                await loadCourses()
                await loadRecurrentNotices()
                // Check subscription status for promotion card
                if let currentUser = authService.currentUser {
                    do {
                        hasSubscription = try await courseSubscriptionService.checkSubscriptionStatus(pilotId: currentUser.id)
                    } catch {
                        print("Error checking subscription: \(error)")
                    }
                }
            }
            .onAppear {
                // Reset promotion card dismissal when view appears (so it shows again)
                isPromotionCardDismissed = false
                
                // Refresh courses when view appears (e.g., after returning from course detail)
                Task {
                    await loadCourses()
                    // Refresh subscription status
                    if let currentUser = authService.currentUser {
                        do {
                            hasSubscription = try await courseSubscriptionService.checkSubscriptionStatus(pilotId: currentUser.id)
                        } catch {
                            print("Error checking subscription: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    private func loadCourses() async {
        // Prevent overlapping requests - if already fetching, skip this call
        guard !isFetching else {
            print("⚠️ [AcademyView] Course fetch already in progress, skipping duplicate request")
            return
        }
        
        let startTime = Date()
        print("🚀 [AcademyView] Starting course fetch at \(startTime)")
        
        isFetching = true
        isLoading = true
        
        // Always fetch from backend - no demo courses
        let academyService = AcademyService()
        if let currentUser = authService.currentUser {
            print("👤 [AcademyView] Fetching courses for user: \(currentUser.id)")
            do {
                try await academyService.fetchCoursesWithEnrollment(pilotId: currentUser.id)
                // Only update courses if fetch was successful
                courses = academyService.courses
                let duration = Date().timeIntervalSince(startTime)
                print("✅ [AcademyView] Successfully fetched \(courses.count) courses in \(String(format: "%.2f", duration))s")
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                // Check if error is a cancellation (user refreshed while loading)
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    // Request was cancelled (likely due to refresh) - don't clear courses
                    print("❌ [AcademyView] Course fetch cancelled after \(String(format: "%.2f", duration))s")
        } else {
                    // Real error - log it but don't clear courses if we have any
                    print("❌ [AcademyView] Error loading courses after \(String(format: "%.2f", duration))s: \(error)")
                    // Only clear courses if we don't have any (first load failed)
                    if courses.isEmpty {
            courses = []
                    }
                }
            }
        } else {
            print("👤 [AcademyView] Fetching courses without user authentication")
            do {
                try await academyService.fetchCourses()
                // Only update courses if fetch was successful
                courses = academyService.courses
                let duration = Date().timeIntervalSince(startTime)
                print("✅ [AcademyView] Successfully fetched \(courses.count) courses in \(String(format: "%.2f", duration))s")
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                // Check if error is a cancellation (user refreshed while loading)
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    // Request was cancelled (likely due to refresh) - don't clear courses
                    print("❌ [AcademyView] Course fetch cancelled after \(String(format: "%.2f", duration))s")
                } else {
                    // Real error - log it but don't clear courses if we have any
                    print("❌ [AcademyView] Error loading courses after \(String(format: "%.2f", duration))s: \(error)")
                    // Only clear courses if we don't have any (first load failed)
                    if courses.isEmpty {
                        courses = []
                    }
                }
            }
        }
        
        let totalDuration = Date().timeIntervalSince(startTime)
        print("🏁 [AcademyView] Course fetch completed in \(String(format: "%.2f", totalDuration))s")
        
        isLoading = false
        isFetching = false
    }
    
    private func loadRecurrentNotices() async {
        // Find courses that require recurrent training
        let recurrentCourses = courses.filter { $0.isRecurrent && $0.isEnrolled }
        
        recurrentNotices = recurrentCourses.compactMap { course in
            guard let dueDate = course.recurrentDueDate else { return nil }
            
            return RecurrentTrainingNotice(
                id: course.id,
                courseTitle: course.title,
                courseCategory: course.category.rawValue,
                dueDate: dueDate,
                provider: course.provider
            )
        }
    }
}

// MARK: - Provider Chip

struct ProviderChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.systemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recurrent Training Card

struct RecurrentTrainingCard: View {
    let notice: RecurrentTrainingNotice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: notice.provider.icon)
                    .foregroundColor(notice.provider.color)
                    .font(.system(size: 20))
                Text(notice.provider.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(notice.provider.color)
                Spacer()
            }
            
            Text(notice.courseTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
            
            HStack {
                Image(systemName: notice.isOverdue ? "exclamationmark.triangle.fill" : "calendar")
                    .foregroundColor(notice.urgencyColor)
                    .font(.caption)
                
                if notice.isOverdue {
                    Text("Overdue")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(notice.urgencyColor)
                } else {
                    Text("Due in \(notice.daysUntilDue) days")
                        .font(.caption)
                        .foregroundColor(notice.urgencyColor)
                }
            }
        }
        .padding()
        .frame(width: 200)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(notice.urgencyColor.opacity(0.5), lineWidth: 2)
        )
        .shadow(color: notice.urgencyColor.opacity(0.2), radius: 4)
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Course Card

struct CourseCard: View {
    let course: TrainingCourse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: course.category.icon)
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        
                        Text(course.title)
                            .font(.headline)
                            .lineLimit(2)
                    }
                    
                    Text(course.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    // Provider badge
                    HStack(spacing: 4) {
                        Image(systemName: course.provider.icon)
                            .foregroundColor(course.provider.color)
                            .font(.caption)
                        Text(course.provider.rawValue)
                            .font(.caption)
                            .foregroundColor(course.provider.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(course.provider.color.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
                
                if course.isEnrolled {
                    VStack(spacing: 4) {
                        if course.badgeId != nil {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 20))
                            Text("Badge")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 20))
                            Text("Enrolled")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            HStack(spacing: 16) {
                // Level Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(course.level.color)
                        .frame(width: 8, height: 8)
                    Text(course.level.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(course.duration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Rating
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text(String(format: "%.1f", course.rating))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Students Count
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(course.studentsCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 4) {
                if let pictureUrl = course.instructorPictureUrl,
                   let url = URL(string: pictureUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 16, height: 16)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 16, height: 16)
                                .clipShape(Circle())
                        case .failure:
                            Image(systemName: "person.circle.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                Text("Instructor: \(course.instructor)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Course Detail View

struct CourseDetailView: View {
    let course: TrainingCourse
    let onEnrollmentChange: () -> Void
    @State private var isEnrolled: Bool
    @State private var showUnenrollConfirmation = false
    @State private var showCompletionConfirmation = false
    @State private var isUnenrolling = false
    @State private var unenrollError: String?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var badgeService = BadgeService()
    @StateObject private var academyService = AcademyService()
    
    init(course: TrainingCourse, onEnrollmentChange: @escaping () -> Void) {
        self.course = course
        self.onEnrollmentChange = onEnrollmentChange
        _isEnrolled = State(initialValue: course.isEnrolled)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Background Image
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: courseBackgroundImageUrl)) { phase in
                        switch phase {
                        case .empty:
                            Color.blue.opacity(0.3)
                                .frame(height: 200)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                        case .failure:
                            Color.blue.opacity(0.3)
                                .frame(height: 200)
                        @unknown default:
                            Color.blue.opacity(0.3)
                                .frame(height: 200)
                        }
                    }
                    
                    // Gradient overlay
                    LinearGradient(
                        gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.6)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)
                    
                    // Title overlay
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: course.category.icon)
                                .foregroundColor(.white)
                                .font(.system(size: 24))
                            
                            Spacer()
                            
                            if isEnrolled {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Enrolled")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        
                        Text(course.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        // Provider badge
                        HStack(spacing: 4) {
                            Image(systemName: course.provider.icon)
                                .foregroundColor(.white)
                                .font(.caption)
                            Text(course.provider.rawValue)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(course.provider.color.opacity(0.8))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                
                VStack(alignment: .leading, spacing: 24) {
                    // Description
                    Text(course.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Course Info Cards
                    VStack(spacing: 12) {
                        InfoRow(icon: "clock.fill", label: "Duration", value: course.duration)
                        InfoRow(icon: "graduationcap.fill", label: "Level", value: course.level.rawValue)
                        
                        // Provider
                        InfoRow(icon: course.provider.icon, label: "Provider", value: course.provider.rawValue)
                        
                        // Instructor with profile picture
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Instructor")
                                .foregroundColor(.secondary)
                            Spacer()
                            HStack(spacing: 8) {
                                if let pictureUrl = course.instructorPictureUrl,
                                   let url = URL(string: pictureUrl) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(width: 32, height: 32)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 32, height: 32)
                                                .clipShape(Circle())
                                        case .failure:
                                            Image(systemName: "person.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(.blue)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.blue)
                                }
                                Text(course.instructor)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                        InfoRow(icon: "star.fill", label: "Rating", value: String(format: "%.1f / 5.0", course.rating))
                        InfoRow(icon: "person.2.fill", label: "Students", value: "\(course.studentsCount)")
                    }
                    .padding(.horizontal)
                    
                    // Badge Status (if course is completed)
                    if let badgeId = course.badgeId {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                Text("Badge Earned")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            Text("You have completed this course and earned a badge.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    // Recurrent Training Notice
                    if course.isRecurrent, let dueDate = course.recurrentDueDate {
                        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
                        let isUrgent = daysUntilDue <= 7
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: isUrgent ? "exclamationmark.triangle.fill" : "clock.fill")
                                    .foregroundColor(isUrgent ? .red : .orange)
                                Text("Recurrent Training Required")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(isUrgent ? .red : .orange)
                            }
                            
                            if course.badgeId != nil {
                                // Badge expiration warning
                                if daysUntilDue <= 7 && daysUntilDue > 0 {
                                    Text("⚠️ Your badge will expire in \(daysUntilDue) day\(daysUntilDue == 1 ? "" : "s"). Complete the recurrent training to renew your badge.")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                        .padding(.top, 4)
                                } else if daysUntilDue <= 0 {
                                    Text("⚠️ Your badge has expired. Complete the recurrent training to renew it.")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                        .padding(.top, 4)
                                }
                            } else {
                                Text("This course requires periodic recurrent training. Next due: \(dueDate, style: .date)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background((isUrgent ? Color.red : Color.orange).opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    // Enroll/Unenroll/Complete/Renew Button
                    if isEnrolled {
                        VStack(spacing: 12) {
                            if course.badgeId != nil {
                                // Course already completed
                                if course.isRecurrent {
                                    // Show renew badge button for recurrent courses
                                    NavigationLink(destination: CourseContentView(course: course)) {
                                        Text("Renew Badge")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 50)
                                            .background(Color.orange)
                                            .cornerRadius(12)
                                    }
                                    .padding(.horizontal)
                                } else {
                                    NavigationLink(destination: CourseContentView(course: course)) {
                                        Text("View Course Materials")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 50)
                                            .background(Color.blue)
                                            .cornerRadius(12)
                                    }
                                    .padding(.horizontal)
                                }
                            } else {
                                // Enrolled but not completed
                                NavigationLink(destination: CourseContentView(course: course)) {
                                    Text("Continue Learning")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(Color.blue)
                                        .cornerRadius(12)
                                }
                                
                                Button(action: {
                                    showCompletionConfirmation = true
                                }) {
                                    Text("Mark as Completed")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            }
                            
                            Button(action: {
                                showUnenrollConfirmation = true
                            }) {
                                Text("Unenroll from Course")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        NavigationLink(destination: CourseContentView(course: course)) {
                            Text("Enroll Now")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                                isEnrolled = true
                                onEnrollmentChange()
                            // Enroll in course via backend
                            Task {
                                if let currentUser = authService.currentUser {
                                    let academyService = AcademyService()
                                    try? await academyService.enrollInCourse(pilotId: currentUser.id, courseId: course.id)
                                }
                            }
                        })
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle("Course Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Unenroll from Course", isPresented: $showUnenrollConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Unenroll", role: .destructive) {
                Task {
                    await unenrollFromCourse()
                }
            }
        } message: {
            Text("Are you sure you want to unenroll from \"\(course.title)\"? You will lose access to course materials and progress.")
        }
        .alert("Error", isPresented: .constant(unenrollError != nil)) {
            Button("OK") {
                unenrollError = nil
            }
        } message: {
            if let error = unenrollError {
                Text(error)
            }
        }
        .alert("Complete Course", isPresented: $showCompletionConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Complete", role: .none) {
                Task {
                    await completeCourse()
                }
            }
        } message: {
            Text("Mark \"\(course.title)\" as completed? You will earn a badge for this achievement.")
        }
    }
    
    private func completeCourse() async {
        guard let currentUser = authService.currentUser else { return }
        
        do {
            try await badgeService.awardBadge(
                pilotId: currentUser.id,
                courseId: course.id,
                courseTitle: course.title,
                courseCategory: course.category.rawValue,
                provider: Badge.CourseProvider(rawValue: course.provider.rawValue) ?? .buzz
            )
            
            // Show success message
            showCompletionConfirmation = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        } catch {
            print("Error awarding badge: \(error)")
        }
    }
    
    private func unenrollFromCourse() async {
        guard let currentUser = authService.currentUser else { return }
        
        isUnenrolling = true
        unenrollError = nil
        
        do {
            // Call backend service to unenroll
            try await academyService.unenrollFromCourse(
                pilotId: currentUser.id,
                courseId: course.id
            )
            
            // Update local state
            isEnrolled = false
            onEnrollmentChange()
            
            // Dismiss after unenrolling
            isUnenrolling = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        } catch {
            isUnenrolling = false
            unenrollError = "Failed to unenroll: \(error.localizedDescription)"
            print("Error unenrolling from course: \(error)")
        }
    }
    
    private var courseBackgroundImageUrl: String {
        // Return relevant background images based on course category
        switch course.category {
        case .safety:
            return "https://images.unsplash.com/photo-1518611012118-696072aa971a?w=800&h=400&fit=crop"
        case .operations:
            return "https://images.unsplash.com/photo-1473968512647-3e447244af8f?w=800&h=400&fit=crop"
        case .photography:
            return "https://images.unsplash.com/photo-1502920917128-1aa500764cbd?w=800&h=400&fit=crop"
        case .cinematography:
            return "https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=800&h=400&fit=crop"
        case .inspection:
            return "https://images.unsplash.com/photo-1581094794329-c8112a89af12?w=800&h=400&fit=crop"
        case .mapping:
            return "https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=800&h=400&fit=crop"
        }
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - UAS Pilot Course Promotion Card

struct UASPilotCoursePromotionCard: View {
    let course: TrainingCourse
    let hasSubscription: Bool
    let onDismiss: () -> Void
    @EnvironmentObject var authService: AuthService
    @State private var showSubscriptionSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                    .font(.title2)
                
                Text("New Pilot Specials")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            
            if hasSubscription {
                Text("🎓 You have full access to all course units!")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            } else {
                Text("🎓 Get full access to the UAS Pilot Course")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Special Price")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("$9.99/month")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showSubscriptionSheet = true
                    }) {
                        Text("Subscribe Now")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
            
            Text("✓ More perks and benefits for future courses")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("✓ Full course access with subscription")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .sheet(isPresented: $showSubscriptionSheet) {
            if let currentUser = authService.currentUser {
                CourseSubscriptionView(course: course, pilotId: currentUser.id)
            }
        }
    }
}

