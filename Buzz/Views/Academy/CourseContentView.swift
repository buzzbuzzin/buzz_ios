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
    @StateObject private var courseSubscriptionService = CourseSubscriptionService()
    @EnvironmentObject var authService: AuthService
    @State private var units: [CourseUnit] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasSubscription = false
    @State private var showSubscriptionSheet = false
    @State private var hasPassedGroundSchoolTest = false
    @State private var showGroundSchoolTest = false
    
    // Check if this is the UAS Pilot Course
    var isUASPilotCourse: Bool {
        let isUAS = course.id.uuidString.lowercased() == "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        print("🔍 [CourseContentView] Course ID: \(course.id.uuidString)")
        print("🔍 [CourseContentView] Course ID (lowercase): \(course.id.uuidString.lowercased())")
        print("🔍 [CourseContentView] Expected ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890")
        print("🔍 [CourseContentView] Is UAS Pilot Course: \(isUAS)")
        return isUAS
    }
    
    var mandatoryUnits: [CourseUnit] {
        units.filter { $0.isMandatory }
    }
    
    var step1Units: [CourseUnit] {
        units.filter { $0.stepNumber == 1 }
    }
    
    var step2Units: [CourseUnit] {
        units.filter { $0.stepNumber == 2 }
    }
    
    var step3Units: [CourseUnit] {
        units.filter { $0.stepNumber == 3 }
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
                    // Mandatory Units Section
                    if !mandatoryUnits.isEmpty {
                        SectionView(
                            title: "MANDATORY UNITS",
                            units: mandatoryUnits,
                            course: course
                        )
                    }
                    
                    // Ground School Test Section (for UAS Pilot Course only)
                    if isUASPilotCourse {
                        GroundSchoolTestSection(
                            hasPassedTest: hasPassedGroundSchoolTest,
                            onStartTest: {
                                print("🎯 [CourseContentView] Start Test button tapped")
                                showGroundSchoolTest = true
                            }
                        )
                        .onAppear {
                            print("✅ [CourseContentView] Showing Ground School Test section")
                            print("📊 [CourseContentView] Test Status - Passed: \(hasPassedGroundSchoolTest)")
                        }
                    }
                    
                    // Step 1: Pick a Base Program
                    if !step1Units.isEmpty {
                        StepSectionView(
                            stepNumber: 1,
                            title: "PICK A BASE PROGRAM",
                            units: step1Units,
                            course: course,
                            hasSubscription: hasSubscription,
                            isUASPilotCourse: isUASPilotCourse,
                            isLockedByTest: isUASPilotCourse && !hasPassedGroundSchoolTest,
                            onSubscribe: {
                                showSubscriptionSheet = true
                            },
                            onTestRequired: {
                                showGroundSchoolTest = true
                            }
                        )
                    }
                    
                    // Step 2: Extension Courses
                    if !step2Units.isEmpty {
                        StepSectionView(
                            stepNumber: 2,
                            title: "EXTENSION COURSES",
                            units: step2Units,
                            course: course,
                            hasSubscription: hasSubscription,
                            isUASPilotCourse: isUASPilotCourse,
                            onSubscribe: {
                                showSubscriptionSheet = true
                            }
                        )
                    }
                    
                    // Step 3: Further Your Base Training
                    if !step3Units.isEmpty {
                        StepSectionView(
                            stepNumber: 3,
                            title: "FURTHER YOUR BASE TRAINING",
                            units: step3Units,
                            course: course,
                            hasSubscription: hasSubscription,
                            isUASPilotCourse: isUASPilotCourse,
                            onSubscribe: {
                                showSubscriptionSheet = true
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
            await loadUnits()
            if isUASPilotCourse, let currentUser = authService.currentUser {
                print("👤 [CourseContentView] Current user ID: \(currentUser.id)")
                do {
                    print("🔄 [CourseContentView] Checking subscription status...")
                    hasSubscription = try await courseSubscriptionService.checkSubscriptionStatus(pilotId: currentUser.id)
                    print("📋 [CourseContentView] Subscription status: \(hasSubscription)")
                    
                    print("🔄 [CourseContentView] Checking Ground School Test status...")
                    hasPassedGroundSchoolTest = try await academyService.checkGroundSchoolTestStatus(pilotId: currentUser.id, courseId: course.id)
                    print("📋 [CourseContentView] Ground School Test passed: \(hasPassedGroundSchoolTest)")
                } catch {
                    print("❌ [CourseContentView] Error checking subscription or test status: \(error)")
                }
            } else {
                if !isUASPilotCourse {
                    print("⚠️ [CourseContentView] Not UAS Pilot Course")
                }
                if authService.currentUser == nil {
                    print("⚠️ [CourseContentView] No current user")
                }
            }
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            if let currentUser = authService.currentUser {
                CourseSubscriptionView(course: course, pilotId: currentUser.id)
            }
        }
        .sheet(isPresented: $showGroundSchoolTest) {
            if let currentUser = authService.currentUser {
                GroundSchoolTestView(course: course, pilotId: currentUser.id)
                    .onDisappear {
                        // Refresh test status when test view is dismissed
                        Task {
                            do {
                                hasPassedGroundSchoolTest = try await academyService.checkGroundSchoolTestStatus(pilotId: currentUser.id, courseId: course.id)
                            } catch {
                                print("Error refreshing test status: \(error)")
                            }
                        }
                    }
            }
        }
    }
    
    private func loadUnits() async {
        print("📚 [CourseContentView] Loading units for course: \(course.title)")
        isLoading = true
        errorMessage = nil
        
        do {
            units = try await academyService.fetchCourseUnits(courseId: course.id)
            print("✅ [CourseContentView] Loaded \(units.count) units")
            print("📊 [CourseContentView] Mandatory units: \(mandatoryUnits.count)")
            print("📊 [CourseContentView] Step 1 units: \(step1Units.count)")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [CourseContentView] Error loading course units: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Section View

struct SectionView: View {
    let title: String
    let units: [CourseUnit]
    let course: TrainingCourse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(units) { unit in
                    NavigationLink(destination: UnitDetailView(unit: unit, course: course)) {
                        UnitRow(unit: unit)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Step Section View

struct StepSectionView: View {
    let stepNumber: Int
    let title: String
    let units: [CourseUnit]
    let course: TrainingCourse
    let hasSubscription: Bool
    let isUASPilotCourse: Bool
    var isLockedByTest: Bool = false
    let onSubscribe: () -> Void
    var onTestRequired: (() -> Void)? = nil
    
    var stepColor: Color {
        switch stepNumber {
        case 1: return .red
        case 2: return .blue
        case 3: return .black
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(units) { unit in
                    if isLockedByTest {
                        // Locked by ground school test
                        Button(action: {
                            onTestRequired?()
                        }) {
                            UnitRow(unit: unit, isLocked: true, lockReason: "Complete Ground School Test to unlock")
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else if isUASPilotCourse && unit.unitNumber >= 4 && !hasSubscription {
                        // Show locked unit with paywall
                        Button(action: onSubscribe) {
                            UnitRow(unit: unit, isLocked: true, lockReason: "Subscribe to unlock")
                        }
                        .buttonStyle(PlainButtonStyle())
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

// MARK: - Ground School Test Section

struct GroundSchoolTestSection: View {
    let hasPassedTest: Bool
    let onStartTest: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GROUND SCHOOL TEST")
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
                        
                        Image(systemName: hasPassedTest ? "checkmark.seal.fill" : "doc.text.fill")
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
                        Button(action: onStartTest) {
                            Text("Start Test")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.orange)
                                .cornerRadius(8)
                        }
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    }
                }
                .padding()
                .background(hasPassedTest ? Color.green.opacity(0.05) : Color.orange.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(hasPassedTest ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(.horizontal)
        }
    }
}

