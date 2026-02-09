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
        // 2. Within each group (unlocked/locked):
        //    - UAS Pilot
        //    - Flight Review
        //    - ROC-A
        //    - Part 107 Recurrent Training
        //    - Extension Courses
        //    - Everything else
        return filtered.sorted { course1, course2 in
            let isLocked1 = !getMissingPrerequisites(for: course1).isEmpty
            let isLocked2 = !getMissingPrerequisites(for: course2).isEmpty
            
            // First sort by lock status (unlocked first)
            if isLocked1 != isLocked2 {
                return !isLocked1 // false (unlocked) comes before true (locked)
            }
            
            // Then sort by priority
            let priority1 = courseSortPriority(course1)
            let priority2 = courseSortPriority(course2)
            
            if priority1 != priority2 {
                return priority1 < priority2
            }
            
            // Same priority - maintain original order
            return false
        }
    }
    
    /// Returns sort priority for a course (lower number = higher priority)
    private func courseSortPriority(_ course: TrainingCourse) -> Int {
        // UAS Pilot Course
        if course.id.uuidString.lowercased() == "a1b2c3d4-e5f6-7890-abcd-ef1234567890" {
            return 1
        }
        
        // Flight Review
        if course.title.lowercased().contains("flight review") {
            return 2
        }
        
        // ROC-A (with or without "Exam")
        if course.title.lowercased().contains("roc-a") || course.title.lowercased().contains("roc a") {
            return 3
        }
        
        // Part 107 Recurrent Training (matches both "FAA 107" and "Part 107")
        if course.title.lowercased().contains("107 recurrent") {
            return 4
        }
        
        // Extension Courses
        if course.title.lowercased().contains("extension courses") {
            return 5
        }
        
        // Everything else
        return 999
    }
    
    var body: some View {
        // Check if user needs to complete region onboarding
        if let currentUser = authService.currentUser,
           authService.userProfile?.selectedRegion == nil {
            return AnyView(
                RegionOnboardingView()
                    .navigationBarBackButtonHidden(true)
            )
        }

        return AnyView(
            NavigationStack {
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

                // // Region Filter
                // ScrollView(.horizontal, showsIndicators: false) {
                //     HStack(spacing: 12) {
                //         // All Regions Button
                //         RegionChip(
                //             title: "All Regions",
                //             icon: "🌐",
                //             isSelected: selectedRegion == nil
                //         ) {
                //             selectedRegion = nil
                //         }
                //
                //         ForEach(allRegions, id: \.self) { region in
                //             RegionChip(
                //                 title: region.rawValue,
                //                 icon: region.icon,
                //                 isSelected: selectedRegion == region || (selectedRegion == nil && region == userSelectedRegion)
                //             ) {
                //                 selectedRegion = region
                //             }
                //         }
                //     }
                //     .padding(.horizontal)
                //     .padding(.vertical, 8)
                // }
                // .background(Color(.systemGray6))
                
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
                            selectedCategory = nil // Reset category when changing provider
                        }
                        
                        ForEach(allProviders, id: \.self) { provider in
                            ProviderChip(
                                title: provider.rawValue,
                                icon: provider.icon,
                                isSelected: selectedProvider == provider,
                                color: provider.color
                            ) {
                                selectedProvider = provider
                                // Reset category when changing to a non-Buzz provider
                                if provider != .buzz {
                                    selectedCategory = nil
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemGray6))
                
                // Category Filter - Only show when Buzz is selected as provider
                if selectedProvider == .buzz {
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
                }
                
                // Courses List (always present to keep navigation state stable)
                ZStack {
                    List {
                        ForEach(filteredCourses) { course in
                            let missingPrerequisites = getMissingPrerequisites(for: course)
                            let isLocked = !missingPrerequisites.isEmpty
                            
                            if isLocked {
                                // Show locked course card (not tappable)
                                CourseCard(
                                    course: courses.first(where: { $0.id == course.id }) ?? course,
                                    isLocked: true,
                                    missingPrerequisites: missingPrerequisites
                                )
                            } else {
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
                    }
                    .listStyle(PlainListStyle())
                    .opacity(filteredCourses.isEmpty ? 0.01 : 1)
                    .allowsHitTesting(!filteredCourses.isEmpty)
                    
                    if isLoading {
                        LoadingView(message: "Loading courses...")
                    } else if filteredCourses.isEmpty {
                        EmptyStateView(
                            icon: "book.closed",
                            title: "No Courses Available",
                            message: "Check back soon for new training courses"
                        )
                    }
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
                            }
                        }
                }
            }
            .task {
                await loadCourses()
                await checkGroundSchoolTestStatus()
                await loadRecurrentNotices()
                // Check ALL subscription sources (Apple + Stripe backend)
                if let currentUser = authService.currentUser {
                    _ = await storeKitManager.checkAllSubscriptions(pilotId: currentUser.id)
                }
            }
            .onAppear {
                // Reset promotion card dismissal when view appears (so it shows again)
                isPromotionCardDismissed = false

                // Refresh courses when view appears (e.g., after returning from course detail)
                Task {
                    await loadCourses()
                    await checkGroundSchoolTestStatus()
                    // Check ALL subscription sources (Apple + Stripe backend)
                    if let currentUser = authService.currentUser {
                        _ = await storeKitManager.checkAllSubscriptions(pilotId: currentUser.id)
                    }
                    }
                }
            }
        )
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
        var missing: [String] = []
        
        // Check Ground School prerequisite
        if course.requiresUasGroundSchool && !hasPassedGroundSchoolTest {
            missing.append("UAS Pilot Ground School Test")
        }
        
        // Check Flight Review prerequisite
        if course.requiresFlightReviewPassed && !hasPassedFlightReview {
            missing.append("Flight Review Test")
        }
        
        // Check ROC-A prerequisite
        if course.requiresRocAPassed && !hasPassedRocA {
            missing.append("ROC-A Test")
        }
        
        return missing
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
            .background(isSelected ? Color.orange : Color(.systemBackground))
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
            .background(isSelected ? Color.green : Color(.systemBackground))
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
            }
        }
        .padding(.vertical, 8)
        .opacity(isLocked ? 0.7 : 1.0)
    }
}

// MARK: - Course Detail View

struct CourseDetailView: View {
    let course: TrainingCourse
    let onEnrollmentChange: () -> Void
    @State private var isEnrolled: Bool
    @State private var showUnenrollConfirmation = false
    @State private var showExternalCourseConfirmation = false
    @State private var isUnenrolling = false
    @State private var unenrollError: String?
    @State private var enrollError: String?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
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
                        
                        InfoRow(icon: "star.fill", label: "Rating", value: String(format: "%.1f / 5.0", course.rating))
                        // Students count - temporarily hidden
                        // InfoRow(icon: "person.2.fill", label: "Students", value: "\(course.studentsCount)")
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
        .task {
            await checkIdentityVerification()
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
