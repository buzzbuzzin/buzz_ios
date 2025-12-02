//
//  CourseContentView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/14/25.
//

import SwiftUI
import Auth

struct CourseContentView: View {
    let course: TrainingCourse
    @StateObject private var academyService = AcademyService()
    @StateObject private var storeKitManager = StoreKitManager()
    @EnvironmentObject var authService: AuthService
    @State private var sections: [CourseSection] = []
    @State private var unitsBySection: [UUID: [CourseUnit]] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSubscriptionSheet = false
    @State private var hasPassedGroundSchoolTest = false
    @State private var navigateToTest = false
    
    var hasSubscription: Bool {
        storeKitManager.hasAcademyPassSubscription()
    }
    
    // Check if this is the UAS Pilot Course
    var isUASPilotCourse: Bool {
        let isUAS = course.id.uuidString.lowercased() == "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        return isUAS
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Course Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(course.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(course.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    // Render sections dynamically from database
                    ForEach(sections) { section in
                        DynamicSectionView(
                            section: section,
                            units: unitsBySection[section.id] ?? [],
                            course: course,
                            hasSubscription: hasSubscription,
                            hasPassedTest: hasPassedGroundSchoolTest,
                            onSubscribe: {
                                showSubscriptionSheet = true
                            },
                            onNavigateToTest: {
                                navigateToTest = true
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle("Course Content")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            print("🚀 [CourseContentView] Loading course content...")
            await loadSectionsAndUnits()
            if let currentUser = authService.currentUser {
                print("👤 [CourseContentView] Current user ID: \(currentUser.id)")
                
                // Update StoreKit subscriptions
                await storeKitManager.updatePurchasedProducts()
                print("📋 [CourseContentView] Subscription status: \(hasSubscription)")
                
                do {
                    print("🔄 [CourseContentView] Checking Ground School Test status...")
                    hasPassedGroundSchoolTest = try await academyService.checkGroundSchoolTestStatus(pilotId: currentUser.id, courseId: course.id)
                    print("📋 [CourseContentView] Ground School Test passed: \(hasPassedGroundSchoolTest)")
                } catch {
                    print("❌ [CourseContentView] Error checking test status: \(error)")
                }
            }
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            if let currentUser = authService.currentUser {
                CourseSubscriptionView(course: course, pilotId: currentUser.id)
            }
        }
        .background(
            NavigationLink(
                destination: authService.currentUser.map { currentUser in
                    GroundSchoolTestView(course: course, pilotId: currentUser.id)
                        .navigationBarBackButtonHidden(true)
                        .onDisappear {
                            Task {
                                if let user = authService.currentUser {
                                    do {
                                        hasPassedGroundSchoolTest = try await academyService.checkGroundSchoolTestStatus(pilotId: user.id, courseId: course.id)
                                    } catch {
                                        print("Error refreshing test status: \(error)")
                                    }
                                }
                            }
                        }
                },
                isActive: $navigateToTest
            ) {
                EmptyView()
            }
            .hidden()
        )
    }
    
    private func loadSectionsAndUnits() async {
        print("📚 [CourseContentView] Loading sections and units for course: \(course.title)")
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch sections from database
            sections = try await academyService.fetchCourseSections(courseId: course.id)
            print("✅ [CourseContentView] Loaded \(sections.count) sections")
            
            // Fetch all units for the course
            let allUnits = try await academyService.fetchCourseUnits(courseId: course.id)
            print("✅ [CourseContentView] Loaded \(allUnits.count) units")
            
            // Group units by section_id
            var grouped: [UUID: [CourseUnit]] = [:]
            for unit in allUnits {
                if let sectionId = unit.sectionId {
                    if grouped[sectionId] == nil {
                        grouped[sectionId] = []
                    }
                    grouped[sectionId]?.append(unit)
                }
            }
            unitsBySection = grouped
            
            for section in sections {
                let unitCount = unitsBySection[section.id]?.count ?? 0
                print("📊 [CourseContentView] Section '\(section.name)': \(unitCount) units")
            }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [CourseContentView] Error loading course content: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Dynamic Section View (renders based on section type from database)

struct DynamicSectionView: View {
    let section: CourseSection
    let units: [CourseUnit]
    let course: TrainingCourse
    let hasSubscription: Bool
    let hasPassedTest: Bool
    let onSubscribe: () -> Void
    let onNavigateToTest: () -> Void
    
    var isLocked: Bool {
        (section.requiresTestPassed && !hasPassedTest) ||
        (section.requiresSubscription && !hasSubscription)
    }
    
    var lockReason: String {
        let needsTest = section.requiresTestPassed && !hasPassedTest
        let needsSub = section.requiresSubscription && !hasSubscription
        
        if needsTest && needsSub {
            return "Pass Ground School Test & Subscribe to unlock"
        } else if needsTest {
            return "Complete Ground School Test to unlock"
        } else if needsSub {
            return "Subscribe to unlock"
        }
        return ""
    }
    
    var body: some View {
        switch section.sectionType {
        case "test":
            // Render test section (Ground School Test)
            NavigationLink(destination: GroundSchoolTestIntroView(
                course: course,
                onStartTest: onNavigateToTest
            )) {
                GroundSchoolTestSectionContent(sectionName: section.name, hasPassedTest: hasPassedTest)
            }
            .buttonStyle(PlainButtonStyle())
            
        case "recurrent":
            // Render recurrent training section
            RecurrentTrainingSectionContent(
                sectionName: section.name,
                hasPassedTest: hasPassedTest,
                hasSubscription: hasSubscription,
                onSubscribe: onSubscribe
            )
            
        default:
            // Render regular units section
            if !units.isEmpty {
                DynamicUnitsSectionView(
                    section: section,
                    units: units,
                    course: course,
                    hasSubscription: hasSubscription,
                    hasPassedTest: hasPassedTest,
                    onSubscribe: onSubscribe
                )
            }
        }
    }
}

// MARK: - Dynamic Units Section View

struct DynamicUnitsSectionView: View {
    let section: CourseSection
    let units: [CourseUnit]
    let course: TrainingCourse
    let hasSubscription: Bool
    let hasPassedTest: Bool
    let onSubscribe: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(section.name)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(units) { unit in
                    let (isLocked, lockReason, requiresAction) = getLockStatus(for: unit)
                    
                    if isLocked {
                        if requiresAction == .subscribe {
                            Button(action: onSubscribe) {
                                UnitRow(unit: unit, isLocked: true, lockReason: lockReason)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            UnitRow(unit: unit, isLocked: true, lockReason: lockReason)
                        }
                    } else {
                        NavigationLink(destination: UnitDetailView(unit: unit, course: course)) {
                            UnitRow(unit: unit, isLocked: false)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func getLockStatus(for unit: CourseUnit) -> (isLocked: Bool, lockReason: String, requiresAction: LockAction) {
        let needsTest = section.requiresTestPassed && !hasPassedTest
        let needsSubscription = section.requiresSubscription && !hasSubscription
        
        if needsTest && needsSubscription {
            return (true, "Pass Ground School Test & Subscribe to unlock", .subscribe)
        } else if needsTest {
            return (true, "Complete Ground School Test to unlock", .test)
        } else if needsSubscription {
            return (true, "Subscribe to unlock", .subscribe)
        }
        
        return (false, "", .none)
    }
    
    private enum LockAction {
        case none
        case test
        case subscribe
    }
}

// MARK: - Unit Row

struct UnitRow: View {
    let unit: CourseUnit
    var isLocked: Bool = false
    var lockReason: String = "Subscribe to unlock"
    
    var body: some View {
        HStack(spacing: 16) {
            // Unit Number Badge
            ZStack {
                Circle()
                    .fill(isLocked ? Color.gray.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                        .font(.headline)
                } else {
                    Text("\(unit.unitNumber)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(unit.title)
                        .font(.headline)
                        .foregroundColor(isLocked ? .secondary : .primary)
                    
                    if isLocked {
                        Text("🔒")
                            .font(.caption)
                    }
                }
                
                if let description = unit.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if isLocked {
                    Text(lockReason)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
            
            if isLocked {
                Image(systemName: "lock.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(isLocked ? Color(.systemGray5) : Color(.systemGray6))
        .cornerRadius(12)
        .opacity(isLocked ? 0.7 : 1.0)
    }
}

// MARK: - Ground School Test Section Content

struct GroundSchoolTestSectionContent: View {
    var sectionName: String = "GROUND SCHOOL TEST"  // Default for backward compatibility
    let hasPassedTest: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(sectionName)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Test Icon
                    ZStack {
                        Circle()
                            .fill(hasPassedTest ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: hasPassedTest ? "checkmark.seal.fill" : "pencil.line")
                            .foregroundColor(hasPassedTest ? .green : .orange)
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ground School Test")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(hasPassedTest 
                             ? "You've passed the test! Continue to next section." 
                             : "Complete units 1-3, then take this test to continue.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        if hasPassedTest {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("Passed")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .fontWeight(.semibold)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Required to continue")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if !hasPassedTest {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .padding()
                .background(hasPassedTest ? Color.green.opacity(0.1) : Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Recurrent Training Section Content

struct RecurrentTrainingSectionContent: View {
    var sectionName: String = "RECURRENT TRAINING"  // Default for backward compatibility
    let hasPassedTest: Bool
    let hasSubscription: Bool
    let onSubscribe: () -> Void
    
    // Recurrent Training requires BOTH test passed AND subscription
    private var isLocked: Bool {
        !hasPassedTest || !hasSubscription
    }
    
    private var lockReason: String {
        if !hasPassedTest && !hasSubscription {
            return "Pass Ground School Test & Subscribe to unlock"
        } else if !hasPassedTest {
            return "Complete Ground School Test to unlock"
        } else if !hasSubscription {
            return "Subscribe to unlock"
        }
        return ""
    }
    
    private var isTappable: Bool {
        // Tappable if only subscription is missing (can subscribe)
        // Not tappable if test is missing (must take test first)
        !hasPassedTest ? false : !hasSubscription
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(sectionName)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                if isTappable {
                    // Tappable - can subscribe
                    Button(action: onSubscribe) {
                        RecurrentTrainingCardContent(
                            isLocked: isLocked,
                            lockReason: lockReason
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Not tappable - test required or already unlocked
                    RecurrentTrainingCardContent(
                        isLocked: isLocked,
                        lockReason: lockReason
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Recurrent Training Card Content

struct RecurrentTrainingCardContent: View {
    let isLocked: Bool
    let lockReason: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Recurrent Training Icon
            ZStack {
                Circle()
                    .fill(isLocked ? Color.gray.opacity(0.2) : Color.purple.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: isLocked ? "lock.fill" : "arrow.clockwise.circle.fill")
                    .foregroundColor(isLocked ? .gray : .purple)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("FAA 107 Recurrent Training")
                    .font(.headline)
                    .foregroundColor(isLocked ? .secondary : .primary)
                
                Text("Comprehensive course material to help you pass the 2-year recurrent training requirement. Stay current with FAA Part 107 regulations and maintain your remote pilot certificate.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                if isLocked {
                    Text(lockReason)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Available")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            Spacer()
            
            if isLocked {
                Image(systemName: "lock.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(isLocked ? Color(.systemGray5) : Color(.systemGray6))
        .cornerRadius(12)
        .opacity(isLocked ? 0.7 : 1.0)
    }
}

