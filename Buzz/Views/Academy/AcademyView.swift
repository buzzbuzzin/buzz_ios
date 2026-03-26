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
    @StateObject private var storeKitManager = StoreKitManager()
    @StateObject private var badgeService = BadgeService()
    @ObservedObject private var entitlementManager = EntitlementManager.shared
    @State private var selectedCategory: TrainingCourse.CourseCategory? = nil
    @State private var selectedProvider: TrainingCourse.CourseProvider? = nil
    @State private var selectedRegion: TrainingCourse.CourseRegion? = nil

    // Computed property to get user's selected region for default filtering
    private var userSelectedRegion: TrainingCourse.CourseRegion? {
        if let regionString = authService.userProfile?.selectedRegion {
            return TrainingCourse.CourseRegion(rawValue: regionString)
        }
        return nil
    }
    @State private var courses: [TrainingCourse] = []
    @State private var recurrentNotices: [RecurrentTrainingNotice] = []
    @State private var isLoading = false
    @State private var isFetching = false // Track if fetch is in progress
    @State private var fetchTask: Task<Void, Never>? = nil // Store the current fetch task
    @State private var showHangerHelp = false
    @State private var showRecurrentNotices = true
    @State private var isPromotionCardDismissed = false
    @State private var isPreparingAcademy = false
    @State private var hasPassedGroundSchoolTest = false
    @State private var hasPassedFlightReview = false
    @State private var hasPassedRocA = false
    
    // Course ID constants
    private let uasPilotCourseId = UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-ef1234567890")!
    private let flightReviewCourseId = UUID(uuidString: "b2c3d4e5-f6a7-8901-bcde-f23456789012")!
    private let rocACourseId = UUID(uuidString: "c3d4e5f6-a7b8-9012-cdef-345678901234")!
    
    /// Check if user has active subscription from any source (Apple or Stripe)
    var hasSubscription: Bool {
        entitlementManager.hasAcademyPass
    }

    private var isAwaitingAuth: Bool {
        authService.activeUserId == nil && !authService.hasResolvedInitialSession
    }

    private var refreshIdentity: String {
        "\(authService.activeUserId?.uuidString ?? "anonymous"):\(authService.userProfile?.selectedRegion ?? "unscoped")"
    }
    
    func toggleEnrollment(for courseId: UUID) {
        if let index = courses.firstIndex(where: { $0.id == courseId }) {
            courses[index].isEnrolled.toggle()
        }
    }
    
    private let allCategories: [TrainingCourse.CourseCategory] = [
        .mandatory, .extensions, .intermediate, .advanced, .specialized
    ]
    
    private let allProviders: [TrainingCourse.CourseProvider] = [
        .buzz, .redCross, .usfa, .fema, .amazon, .tmobile, .other
    ]
    
    private let allRegions: [TrainingCourse.CourseRegion] = [
        .global, .canada, .usa, .uk, .australia, .newZealand, .southAfrica
    ]
    
    var filteredCourses: [TrainingCourse] {
        var filtered = courses
        
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        if let provider = selectedProvider {
            filtered = filtered.filter { $0.provider == provider }
        }
        
        if let regionString = authService.userProfile?.selectedRegion,
           let region = TrainingCourse.CourseRegion(rawValue: regionString) {
            filtered = filtered.filter { $0.region == region || $0.region == .global }
        }
        
        // Sort courses in specific order:
        // 1. Unlocked courses first, then locked courses
        // 2. Buzz courses first, then other providers alphabetically
        // 3. Buzz courses sorted by category: mandatory → extension → intermediate → advanced → specialized → general
        return filtered.sorted { course1, course2 in
            let isLocked1 = !getMissingPrerequisites(for: course1).isEmpty
            let isLocked2 = !getMissingPrerequisites(for: course2).isEmpty

            // First sort by lock status (unlocked first)
            if isLocked1 != isLocked2 {
                return !isLocked1
            }

            // Then sort by provider: Buzz first, others alphabetically
            let isBuzz1 = course1.provider == .buzz
            let isBuzz2 = course2.provider == .buzz

            if isBuzz1 != isBuzz2 {
                return isBuzz1
            }

            // For Buzz courses, sort by category priority
            if isBuzz1 && isBuzz2 {
                let catPriority1 = categorySort(course1.category)
                let catPriority2 = categorySort(course2.category)
                if catPriority1 != catPriority2 {
                    return catPriority1 < catPriority2
                }
            }

            // For non-Buzz courses with different providers, sort alphabetically
            if !isBuzz1 && !isBuzz2 && course1.provider != course2.provider {
                return course1.provider.rawValue < course2.provider.rawValue
            }

            // Same group - maintain original order
            return false
        }
    }

    /// Returns sort priority for a course category (lower number = higher priority)
    private func categorySort(_ category: TrainingCourse.CourseCategory) -> Int {
        switch category {
        case .mandatory: return 0
        case .general: return 1
        case .extensions: return 2
        case .intermediate: return 3
        case .advanced: return 4
        case .specialized: return 5
        }
    }
    
    var body: some View {
        Group {
            if isAwaitingAuth {
                LoadingView(message: "Loading academy...")
            } else if authService.currentUser != nil,
                      let userProfile = authService.userProfile,
                      userProfile.selectedRegion == nil {
                RegionOnboardingView()
                    .navigationBarBackButtonHidden(true)
            } else {
                academyNavigationContent
            }
        }
    }

    private var academyNavigationContent: some View {
        NavigationStack {
            ZStack {
                List {
                    // Recurrent Training Notices Section
                    if showRecurrentNotices && !recurrentNotices.isEmpty {
                        Section {
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
                                    .accessibilityLabel("Dismiss recurrent training notices")
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                                }

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(recurrentNotices) { notice in
                                            RecurrentTrainingCard(notice: notice)
                                        }
                                    }
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color(.systemGray6))
                    }

                    // UAS Pilot Course Promotion Section
                    if let uasCourse = courses.first(where: {
                        $0.id.uuidString.lowercased() == "a1b2c3d4-e5f6-7890-abcd-ef1234567890" ||
                        $0.title.lowercased().contains("uas pilot")
                    }), !hasSubscription && !isPromotionCardDismissed {
                        Section {
                            UASPilotCoursePromotionCard(
                                course: uasCourse,
                                hasSubscription: hasSubscription,
                                onDismiss: {
                                    isPromotionCardDismissed = true
                                }
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color(.systemGray6))
                    }

                    // Provider Filter
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ProviderChip(
                                    title: "All Providers",
                                    icon: "square.grid.2x2",
                                    isSelected: selectedProvider == nil
                                ) {
                                    selectedProvider = nil
                                    selectedCategory = nil
                                }

                                ForEach(allProviders, id: \.self) { provider in
                                    ProviderChip(
                                        title: provider.rawValue,
                                        icon: provider.icon,
                                        isSelected: selectedProvider == provider,
                                        color: provider.color
                                    ) {
                                        selectedProvider = provider
                                        if provider != .buzz {
                                            selectedCategory = nil
                                        }
                                    }
                                }
                            }
                        }

                        if selectedProvider == .buzz {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
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
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color(.systemGray6))

                    // Courses
                    Section {
                        if !isLoading && !isPreparingAcademy && filteredCourses.isEmpty {
                            EmptyStateView(
                                icon: "book.closed",
                                title: "No Courses Available",
                                message: "Check back soon for new training courses"
                            )
                            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(filteredCourses) { course in
                                let missingPrerequisites = getMissingPrerequisites(for: course)
                                let isLocked = !missingPrerequisites.isEmpty

                                if isLocked {
                                    CourseCard(
                                        course: courses.first(where: { $0.id == course.id }) ?? course,
                                        isLocked: true,
                                        missingPrerequisites: missingPrerequisites
                                    )
                                    .accessibilityHint("Course is locked. Complete prerequisites to unlock.")
                                } else {
                                    NavigationLink(destination: CourseDetailView(
                                        course: courses.first(where: { $0.id == course.id }) ?? course,
                                        onEnrollmentChange: {
                                            toggleEnrollment(for: course.id)
                                            Task {
                                                await loadCourses()
                                            }
                                        }
                                    )) {
                                        CourseCard(course: courses.first(where: { $0.id == course.id }) ?? course)
                                    }
                                    .accessibilityHint("Double tap to view course details")
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())

                if isLoading || isPreparingAcademy {
                    LoadingView(message: "Loading courses...")
                }
            }
            .navigationTitle("Academy")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHangerHelp = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                            Text("Hanger Help")
                                .font(.subheadline)
                        }
                        .foregroundColor(.mint)
                    }
                    .accessibilityLabel("Hanger Help")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: TestCenterView()) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal")
                            Text("Test Center")
                                .font(.subheadline)
                        }
                        .foregroundColor(.blue)
                    }
                    .accessibilityLabel("Test Center")
                }
            }
            .fullScreenCover(isPresented: $showHangerHelp) {
                NavigationView {
                    HangerHelpView()
                        .environmentObject(authService)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    showHangerHelp = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                }
                                .accessibilityLabel("Close Hanger Help")
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                            }
                        }
                }
            }
            .task(id: refreshIdentity) {
                await refreshAcademy()
            }
        }
    }

    private func refreshAcademy() async {
        guard !isAwaitingAuth else { return }

        isPreparingAcademy = true
        defer { isPreparingAcademy = false }

        await loadCourses()
        await checkGroundSchoolTestStatus()
        await loadRecurrentNotices()

        if let currentUser = authService.currentUser {
            _ = await storeKitManager.checkAllSubscriptions(pilotId: currentUser.id)
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
    
    private func checkGroundSchoolTestStatus() async {
        guard let currentUser = authService.currentUser else {
            hasPassedGroundSchoolTest = false
            hasPassedFlightReview = false
            hasPassedRocA = false
            return
        }
        
        let academyService = AcademyService()
        
        // Check all prerequisites in parallel
        let results = await academyService.checkAllPrerequisites(pilotId: currentUser.id)
        hasPassedGroundSchoolTest = results.groundSchool
        hasPassedFlightReview = results.flightReview
        hasPassedRocA = results.rocA
        
        print("📋 [AcademyView] Prerequisites - Ground School: \(hasPassedGroundSchoolTest), Flight Review: \(hasPassedFlightReview), ROC-A: \(hasPassedRocA)")
    }
    
    /// Get the list of missing prerequisites for a course
    private func getMissingPrerequisites(for course: TrainingCourse) -> [String] {
        AcademyCourseAccessPolicy.missingEnrollmentRequirements(
            for: course,
            hasSubscription: hasSubscription,
            hasPassedGroundSchool: hasPassedGroundSchoolTest,
            hasPassedFlightReview: hasPassedFlightReview,
            hasPassedRocA: hasPassedRocA
        )
    }
    
    private func loadRecurrentNotices() async {
        guard let currentUser = authService.currentUser else {
            recurrentNotices = []
            return
        }

        do {
            try await badgeService.fetchPilotBadges(pilotId: currentUser.id)

            recurrentNotices = badgeService.badges.compactMap { badge in
                guard badge.isRecurrent,
                      let dueDate = badge.expiresAt,
                      badge.isExpired || (badge.daysUntilExpiration ?? .max) <= 30 else {
                    return nil
                }

                return RecurrentTrainingNotice(
                    id: badge.id,
                    courseTitle: badge.courseTitle ?? badge.badgeType?.displayName ?? "Recurrent Training",
                    courseCategory: badge.courseCategory ?? "Training",
                    dueDate: dueDate,
                    provider: TrainingCourse.CourseProvider(rawValue: badge.provider.rawValue) ?? .other
                )
            }
            .sorted { $0.dueDate < $1.dueDate }
        } catch {
            recurrentNotices = []
            print("❌ [AcademyView] Error loading recurrent notices: \(error)")
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
            .frame(minHeight: 44)
            .background(isSelected ? color : Color(.systemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(title) provider filter\(isSelected ? ", selected" : "")")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(notice.courseTitle), \(notice.provider.rawValue), \(notice.isOverdue ? "Overdue" : "Due in \(notice.daysUntilDue) days")")
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
            .frame(minHeight: 44)
            .background(isSelected ? Color.orange : Color(.systemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(title) category filter\(isSelected ? ", selected" : "")")
    }
}

// MARK: - Region Chip

struct RegionChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(isSelected ? Color.green : Color(.systemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(title) region filter\(isSelected ? ", selected" : "")")
    }
}

// MARK: - Course Card

struct CourseCard: View {
    let course: TrainingCourse
    var isLocked: Bool = false
    var missingPrerequisites: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                        } else {
                            Image(systemName: course.category.icon)
                                .foregroundColor(.blue)
                                .font(.system(size: 16))
                        }
                        
                        Text(course.title)
                            .font(.headline)
                            .foregroundColor(isLocked ? .secondary : .primary)
                            .lineLimit(2)
                    }
                    
                    Text(course.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    // Missing prerequisites if locked
                    if isLocked && !missingPrerequisites.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Missing prerequisite\(missingPrerequisites.count > 1 ? "s" : ""):")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                            }
                            
                            ForEach(missingPrerequisites, id: \.self) { prerequisite in
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption2)
                                    Text(prerequisite)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 4)
                            }
                        }
                        .padding(.top, 2)
                    }
                    
                    // Provider and Category badges
                    HStack(spacing: 8) {
                        // Provider badge
                        HStack(spacing: 4) {
                            Image(systemName: course.provider.icon)
                                .foregroundColor(isLocked ? .gray : course.provider.color)
                                .font(.caption)
                            Text(course.provider.rawValue)
                                .font(.caption)
                                .foregroundColor(isLocked ? .gray : course.provider.color)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((isLocked ? Color.gray : course.provider.color).opacity(0.1))
                        .cornerRadius(6)
                        
                        // Category badge (only for Buzz provider)
                        if course.provider == .buzz {
                            HStack(spacing: 4) {
                                Image(systemName: course.category.icon)
                                    .foregroundColor(isLocked ? .gray : .orange)
                                    .font(.caption)
                                Text(course.category.rawValue)
                                    .font(.caption)
                                    .foregroundColor(isLocked ? .gray : .orange)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((isLocked ? Color.gray : Color.orange).opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
                
                if isLocked {
                    VStack(spacing: 4) {
                        Image(systemName: "lock.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                        Text("Locked")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                } else if course.isEnrolled {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 20))
                        Text("Enrolled")
                            .font(.caption2)
                            .foregroundColor(.green)
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
            }
        }
        .padding(.vertical, 8)
        .opacity(isLocked ? 0.7 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(courseAccessibilityLabel)
    }

    private var courseAccessibilityLabel: String {
        var parts: [String] = []
        parts.append(course.title)
        if isLocked {
            parts.append("Locked")
            if !missingPrerequisites.isEmpty {
                parts.append("Missing prerequisites: \(missingPrerequisites.joined(separator: ", "))")
            }
        } else if course.isEnrolled {
            parts.append("Enrolled")
        }
        parts.append("Provider: \(course.provider.rawValue)")
        parts.append("Level: \(course.level.rawValue)")
        parts.append("Duration: \(course.duration)")
        parts.append("Rating: \(String(format: "%.1f", course.rating)) out of 5")
        return parts.joined(separator: ", ")
    }
}

// MARK: - Course Detail View

struct CourseDetailView: View {
    let course: TrainingCourse
    let onEnrollmentChange: () -> Void
    @State private var isEnrolled: Bool
    @State private var showUnenrollConfirmation = false
    @State private var showExternalCourseConfirmation = false
    @State private var showSubscriptionSheet = false
    @State private var isUnenrolling = false
    @State private var unenrollError: String?
    @State private var enrollError: String?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var storeKitManager = StoreKitManager()
    @ObservedObject private var entitlementManager = EntitlementManager.shared
    @StateObject private var badgeService = BadgeService()
    @StateObject private var academyService = AcademyService()
    @StateObject private var identityService = IdentityVerificationService()
    @State private var isIdentityVerified = false
    @State private var showVerificationRequiredAlert = false

    init(course: TrainingCourse, onEnrollmentChange: @escaping () -> Void) {
        self.course = course
        self.onEnrollmentChange = onEnrollmentChange
        _isEnrolled = State(initialValue: course.isEnrolled)
    }

    private var hasSubscription: Bool {
        entitlementManager.hasAcademyPass
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
                                .frame(height: 250)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: UIScreen.main.bounds.width, height: 250)
                                .clipped()
                        case .failure:
                            Color.blue.opacity(0.3)
                                .frame(height: 250)
                        @unknown default:
                            Color.blue.opacity(0.3)
                                .frame(height: 250)
                        }
                    }
                    .frame(height: 250)
                    
                    // Gradient overlay
                    LinearGradient(
                        gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.7)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 250)
                    
                    // Title overlay
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
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
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(20)
                                .accessibilityLabel("You are enrolled in this course")
                            }
                        }
                        
                        Spacer()
                        
                        Text(course.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                        
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
                    .frame(height: 250)
                }
                .frame(height: 250)
                
                VStack(alignment: .leading, spacing: 24) {
                    // Description
                    Text(course.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // External course disclaimer
                    if let externalUrl = course.externalUrl, !externalUrl.isEmpty {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("External Course Notice")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("This course is hosted by a third-party provider, not Buzz. It is not covered by the Buzz Academy subscription. Additional costs may apply to take this course.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Course Info Cards
                    VStack(spacing: 12) {
                        InfoRow(icon: "clock.fill", label: "Duration", value: course.duration)
                        InfoRow(icon: "graduationcap.fill", label: "Level", value: course.level.rawValue)
                        
                        // Provider
                        InfoRow(icon: course.provider.icon, label: "Provider", value: course.provider.rawValue)
                        
                        // Region with flag
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Region")
                                .foregroundColor(.secondary)
                            Spacer()
                            HStack(spacing: 8) {
                                Text(course.region.icon)
                                    .font(.system(size: 24))
                                Text(course.region.rawValue)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Region: \(course.region.rawValue)")
                        
                        InfoRow(icon: "star.fill", label: "Rating", value: String(format: "%.1f / 5.0", course.rating))
                    }
                    .padding(.horizontal)
                    
                    // Enroll/Unenroll/Complete/Renew Button
                    if isEnrolled {
                        VStack(spacing: 12) {
                            NavigationLink(destination: CourseContentView(course: course)) {
                                Text("Continue Learning")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            .accessibilityLabel("Continue learning \(course.title)")

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
                            .accessibilityLabel("Unenroll from \(course.title)")
                        }
                        .padding(.horizontal)
                    } else {
                        // Check if this is an external course (non-Buzz with external URL)
                        if let externalUrl = course.externalUrl, !externalUrl.isEmpty {
                            // External course - show "Go to Course" button with confirmation
                            Button(action: {
                                if isIdentityVerified {
                                    showExternalCourseConfirmation = true
                                } else {
                                    showVerificationRequiredAlert = true
                                }
                            }) {
                                Text("Go to Course")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            .accessibilityLabel("Go to external course \(course.title)")
                            .padding(.horizontal)
                        } else if course.requiresSubscriptionToEnroll && !hasSubscription {
                            VStack(alignment: .leading, spacing: 12) {
                                Button(action: {
                                    showSubscriptionSheet = true
                                }) {
                                    Text("Unlock with Academy Pass")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(Color.orange)
                                        .cornerRadius(12)
                                }
                                .accessibilityLabel("Unlock \(course.title) with Academy Pass")

                                Text("An active Buzz Academy Pass is required before you can enroll in this course.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        } else {
                            // Buzz course - show "Enroll Now" button
                            Button(action: {
                                if isIdentityVerified {
                                    Task {
                                        await enrollInCourse()
                                    }
                                } else {
                                    showVerificationRequiredAlert = true
                                }
                            }) {
                                Text("Enroll Now")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            .accessibilityLabel("Enroll in \(course.title)")
                            .padding(.horizontal)
                        }
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
        .alert("Enrollment Error", isPresented: .constant(enrollError != nil)) {
            Button("OK") {
                enrollError = nil
            }
        } message: {
            if let error = enrollError {
                Text(error)
            }
        }
        .alert("External Course Warning", isPresented: $showExternalCourseConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Got it", role: .none) {
                // Open the external URL
                if let externalUrl = course.externalUrl, let url = URL(string: externalUrl) {
                    #if os(iOS)
                    UIApplication.shared.open(url)
                    #elseif os(macOS)
                    NSWorkspace.shared.open(url)
                    #endif
                }
            }
        } message: {
            Text("You are going to a third-party website to take the course. This is not covered by the Buzz Academy subscription.")
        }
        .alert("Verification Required", isPresented: $showVerificationRequiredAlert) {
            Button("Go to Settings", role: .none) { }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You must verify your identity before enrolling in courses. Please complete identity verification in your Profile settings under Personal Info.")
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            if let currentUser = authService.currentUser {
                CourseSubscriptionView(course: course, pilotId: currentUser.id)
            }
        }
        .task {
            await checkIdentityVerification()
            if let currentUser = authService.currentUser {
                _ = await storeKitManager.checkAllSubscriptions(pilotId: currentUser.id)
            }
        }
    }

    private func checkIdentityVerification() async {
        guard let userId = authService.currentUser?.id else { return }
        isIdentityVerified = await identityService.isIdentityVerified(userId: userId)
    }

    private func enrollInCourse() async {
        guard let currentUser = authService.currentUser else { return }
        
        enrollError = nil
        
        do {
            try await academyService.enrollInCourse(
                pilotId: currentUser.id,
                courseId: course.id
            )
            
            // Update local state on success
            isEnrolled = true
            onEnrollmentChange()
        } catch {
            // Show error alert
            enrollError = error.localizedDescription
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
        // Use cover image URL from database if available, otherwise fall back to category-based images
        if let coverImageUrl = course.coverImageUrl, !coverImageUrl.isEmpty {
            return coverImageUrl
        }
        
        // Return relevant background images based on course category
        switch course.category {
        case .mandatory:
            return "https://images.unsplash.com/photo-1518611012118-696072aa971a?w=800&h=400&fit=crop"
        case .extensions:
            return "https://images.unsplash.com/photo-1473968512647-3e447244af8f?w=800&h=400&fit=crop"
        case .intermediate:
            return "https://images.unsplash.com/photo-1502920917128-1aa500764cbd?w=800&h=400&fit=crop"
        case .advanced:
            return "https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=800&h=400&fit=crop"
        case .specialized:
            return "https://images.unsplash.com/photo-1581094794329-c8112a89af12?w=800&h=400&fit=crop"
        case .general:
            return "https://images.unsplash.com/photo-1518611012118-696072aa971a?w=800&h=400&fit=crop"
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
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
                Image(systemName: "graduationcap.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                
                Text("Academy Pass")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .accessibilityLabel("Dismiss Academy Pass promotion")
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }

            if hasSubscription {
                Text("🎓 You have full access to all course units!")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            } else {
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
                    .accessibilityLabel("Subscribe to Academy Pass for $9.99 per month")
                    .frame(minHeight: 44)
                }
            }

            Text("✓ More perks and benefits for future courses")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("✓ Get full access to the Pilot Academy")
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
