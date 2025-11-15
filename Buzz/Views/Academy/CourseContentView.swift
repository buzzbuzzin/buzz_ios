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
    
    // Check if this is the UAS Pilot Course
    var isUASPilotCourse: Bool {
        course.id.uuidString == "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
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
                    
                    // Step 1: Pick a Base Program
                    if !step1Units.isEmpty {
                        StepSectionView(
                            stepNumber: 1,
                            title: "PICK A BASE PROGRAM",
                            units: step1Units,
                            course: course,
                            hasSubscription: hasSubscription,
                            isUASPilotCourse: isUASPilotCourse,
                            onSubscribe: {
                                showSubscriptionSheet = true
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
            await loadUnits()
            if isUASPilotCourse, let currentUser = authService.currentUser {
                do {
                    hasSubscription = try await courseSubscriptionService.checkSubscriptionStatus(pilotId: currentUser.id)
                } catch {
                    print("Error checking subscription: \(error)")
                }
            }
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            if let currentUser = authService.currentUser {
                CourseSubscriptionView(course: course, pilotId: currentUser.id)
            }
        }
    }
    
    private func loadUnits() async {
        isLoading = true
        errorMessage = nil
        
        do {
            units = try await academyService.fetchCourseUnits(courseId: course.id)
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading course units: \(error)")
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
    let onSubscribe: () -> Void
    
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
                    if isUASPilotCourse && unit.unitNumber >= 4 && !hasSubscription {
                        // Show locked unit with paywall
                        Button(action: onSubscribe) {
                            UnitRow(unit: unit, isLocked: true)
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
                    Text("Subscribe to unlock")
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

