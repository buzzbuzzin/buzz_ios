//
//  ExamIntroView.swift
//  Buzz
//
//  Exam introduction view showing details, prerequisites, and price
//

import SwiftUI
import Auth

struct ExamIntroView: View {
    let examType: ExamType
    
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var examService = ExamService.shared
    @StateObject private var uploadService = ExamResultUploadService()
    @Environment(\.dismiss) private var dismiss
    @State private var priceInfo: ExamPriceResponse?
    @State private var isLoadingPrice = true
    @State private var priceError: String?
    @State private var prerequisitesStatus: ExamPrerequisitesStatus?
    @State private var showSchedulingView = false
    @State private var showUploadView = false
    @State private var testResult: TestResult?
    @State private var isLoadingTestResult = true
    @State private var courseTest: CourseTest?
    @State private var isLoadingTestType = true
    @State private var showProctorInfoView = false
    @State private var showProctoredTest = false
    @State private var proctorName: String = ""
    
    // Test IDs for Flight Review and ROC-A
    private let flightReviewTestId = UUID(uuidString: "f1a2b3c4-d5e6-7890-abcd-f11ab0000001")!
    private let rocATestId = UUID(uuidString: "a0c4a5b6-c7d8-9012-efab-a0ca00000001")!
    // Course IDs
    private let uasPilotCourseId = UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-ef1234567890")!
    private let rocACourseId = UUID(uuidString: "c3d4e5f6-a7b8-9012-cdef-345678901234")!
    
    // Check if this exam requires upload (non-multiple-choice)
    // Only practical, oral, and written exams require upload
    private var requiresUpload: Bool {
        guard let courseTest = courseTest else {
            // Fallback to old behavior while loading
            return examType == .flightReview || examType == .rocA
        }
        // Upload is required for all test types except multiple_choice
        return courseTest.testType != "multiple_choice"
    }
    
    // Check if this is a proctored multiple-choice exam
    private var isProctored: Bool {
        guard let courseTest = courseTest else { return false }
        return courseTest.testType == "multiple_choice" && courseTest.needsProctor
    }
    
    private var testId: UUID {
        examType == .flightReview ? flightReviewTestId : rocATestId
    }
    
    private var courseId: UUID {
        // Flight Review belongs to UAS Pilot Course, ROC-A belongs to standalone ROC-A Course
        switch examType {
        case .flightReview:
            return uasPilotCourseId
        case .rocA:
            return rocACourseId
        case .groundSchoolTest:
            return uasPilotCourseId
        }
    }
    
    private var hasPassed: Bool {
        testResult?.passed == true
    }
    
    private var uploadStatus: TestUploadStatus {
        testResult?.uploadStatusEnum ?? .notSubmitted
    }
    
    private var config: ExamTypeConfig {
        examService.getConfig(for: examType)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Image/Icon
                ZStack {
                    LinearGradient(
                        colors: [examType.color.opacity(0.6), examType.color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 200)
                    
                    VStack(spacing: 12) {
                        Image(systemName: config.icon)
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        
                        Text(config.displayName)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 24) {
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About This Exam")
                            .font(.headline)
                        
                        Text(config.fullDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Exam Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Exam Details")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ExamDetailRow(
                                icon: "clock",
                                label: "Duration",
                                value: "\(courseTest?.duration ?? config.durationMinutes) minutes"
                            )
                            
                            ExamDetailRow(
                                icon: config.allowsOnline ? "video" : "mappin.and.ellipse",
                                label: "Format",
                                value: config.allowsOnline ? "In-person or Online" : "In-person only"
                            )
                            
                            // Price Row
                            if isLoadingPrice {
                                HStack {
                                    Image(systemName: "dollarsign.circle")
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    Text("Price")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            } else if let price = priceInfo {
                                ExamDetailRow(
                                    icon: "dollarsign.circle",
                                    label: "Price",
                                    value: price.formattedPrice,
                                    valueColor: .green
                                )
                            } else if let error = priceError {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                        .frame(width: 24)
                                    Text("Price unavailable")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Prerequisites
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Prerequisites")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ForEach(Array(config.prerequisites.enumerated()), id: \.offset) { index, prerequisite in
                                PrerequisiteDetailRow(
                                    number: index + 1,
                                    title: prerequisite,
                                    isCompleted: getPrerequisiteStatus(index: index)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // What to Expect Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What to Expect")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            WhatToExpectRow(text: "Confirm your appointment 24 hours before")
                            WhatToExpectRow(text: config.allowsOnline ? "Join via Zoom or arrive at the location 10 minutes early" : "Arrive at the location 10 minutes early")
                            WhatToExpectRow(text: "Bring valid identification")
                            if examType == .flightReview {
                                WhatToExpectRow(text: "Bring your drone and necessary equipment")
                            }
                            WhatToExpectRow(text: "Results provided immediately after completion")
                        }
                        .padding(.horizontal)
                    }
                    
                    // Test Result Status (for upload-required exams)
                    if requiresUpload && !isLoadingTestResult {
                        if hasPassed {
                            // Passed - Show success message
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                        .font(.title2)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("You've passed this exam!")
                                            .font(.headline)
                                            .foregroundColor(.green)
                                        Text("Congratulations on completing your \(config.displayName).")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        } else if uploadStatus == .pending {
                            // Pending Review
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.orange)
                                        .font(.title2)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Results Under Review")
                                            .font(.headline)
                                            .foregroundColor(.orange)
                                        Text("Your uploaded test results are being reviewed by our team. You'll be notified once approved.")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        } else if uploadStatus == .rejected {
                            // Rejected - Show reason and allow re-upload
                            VStack(spacing: 12) {
                                HStack(alignment: .top) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.title2)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Results Not Approved")
                                            .font(.headline)
                                            .foregroundColor(.red)
                                        if let notes = testResult?.reviewerNotes {
                                            Text(notes)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("Please upload your test results again or schedule a new exam.")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Schedule Button (only show if not passed, not under review, and prerequisites met)
                    // Hide if results are under review (pending) unless they failed
                    if !hasPassed && uploadStatus != .pending {
                    Button(action: {
                        showSchedulingView = true
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Schedule Exam")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            prerequisitesStatus?.isEligible == true
                            ? examType.color
                            : Color.gray
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(prerequisitesStatus?.isEligible != true || priceInfo == nil)
                    .padding(.horizontal)
                        
                        // Start Exam Button (for proctored multiple-choice exams)
                        if isProctored && !hasPassed && uploadStatus != .pending {
                            Button(action: {
                                showProctorInfoView = true
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Start Exam")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(prerequisitesStatus?.isEligible == true ? Color.orange : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(prerequisitesStatus?.isEligible != true)
                            .padding(.horizontal)
                        }
                        
                        // Upload Button (for non-multiple-choice exams)
                        // Only show if: not passed, not under review, and (never submitted OR rejected)
                        if requiresUpload && uploadStatus != .pending && !hasPassed {
                            Button(action: {
                                showUploadView = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.up.doc.fill")
                                    Text(uploadStatus == .rejected ? "Re-upload Test Results" : "Upload Test Results")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(prerequisitesStatus?.isEligible == true ? Color.green : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(prerequisitesStatus?.isEligible != true)
                            .padding(.horizontal)
                        }
                    
                    if prerequisitesStatus?.isEligible != true {
                        Text("Complete all prerequisites to schedule this exam")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle(config.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showProctorInfoView) {
            if isProctored, let currentUser = authService.currentUser {
                ProctorInfoView(
                    testId: testId,
                    course: TrainingCourse(
                        id: courseId,
                        title: config.displayName,
                        description: config.fullDescription,
                        duration: "\(config.durationMinutes) minutes",
                        level: .advanced,
                        category: .advanced,
                        instructor: "Buzz",
                        instructorPictureUrl: nil,
                        rating: 5.0,
                        studentsCount: 0,
                        isEnrolled: true,
                        provider: .buzz,
                        badgeId: nil,
                        isRecurrent: false,
                        recurrentDueDate: nil,
                        requiresUasGroundSchool: false,
                        requiresFlightReviewPassed: false,
                        requiresRocAPassed: false,
                        externalUrl: nil,
                        coverImageUrl: nil,
                        region: .global,
                        active: true
                    ),
                    pilotId: currentUser.id,
                    testName: courseTest?.testName ?? config.displayName,
                    passingScore: courseTest?.passingScore ?? 70,
                    durationMinutes: courseTest?.duration ?? config.durationMinutes,
                    onStartTest: { name in
                        proctorName = name
                        showProctorInfoView = false
                        // Delay to ensure sheet dismisses before fullscreen cover
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showProctoredTest = true
                        }
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showProctoredTest) {
            if isProctored, let currentUser = authService.currentUser {
                ProctoredMultipleChoiceTestView(
                    testId: testId,
                    course: TrainingCourse(
                        id: courseId,
                        title: config.displayName,
                        description: config.fullDescription,
                        duration: "\(config.durationMinutes) minutes",
                        level: .advanced,
                        category: .advanced,
                        instructor: "Buzz",
                        instructorPictureUrl: nil,
                        rating: 5.0,
                        studentsCount: 0,
                        isEnrolled: true,
                        provider: .buzz,
                        badgeId: nil,
                        isRecurrent: false,
                        recurrentDueDate: nil,
                        requiresUasGroundSchool: false,
                        requiresFlightReviewPassed: false,
                        requiresRocAPassed: false,
                        externalUrl: nil,
                        coverImageUrl: nil,
                        region: .global,
                        active: true
                    ),
                    pilotId: currentUser.id,
                    testName: courseTest?.testName ?? config.displayName,
                    passingScore: courseTest?.passingScore ?? 70,
                    durationMinutes: courseTest?.duration ?? config.durationMinutes,
                    proctorName: proctorName,
                    onDismiss: {
                        showProctoredTest = false
                    }
                )
                .environmentObject(authService)
            }
        }
        .sheet(isPresented: $showUploadView) {
            if requiresUpload {
                TestResultUploadView(
                    examType: examType,
                    testId: testId,
                    courseId: courseId,
                    onUploadComplete: {
                        Task {
                            await loadTestResultStatus()
                        }
                    }
                )
                .environmentObject(authService)
            }
        }
        .navigationDestination(isPresented: $showSchedulingView) {
            if let price = priceInfo {
                ExamSchedulingView(
                    examType: examType,
                    priceInfo: price,
                    onBookingComplete: {
                        // First dismiss child views
                        showSchedulingView = false
                        // Then dismiss this view to go back to Test Center
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            dismiss()
                        }
                    }
                )
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadTestResultStatus()
        }
    }
    
    private func loadData() async {
        guard let currentUser = authService.currentUser else { return }
        
        // Load exam configurations from backend
        await examService.fetchExamConfigs()
        
        // Load test type from database
        await loadTestType()
        
        // Load prerequisites status
        do {
            prerequisitesStatus = try await examService.checkPrerequisites(pilotId: currentUser.id)
        } catch {
            print("Error checking prerequisites: \(error)")
        }
        
        // Load price
        isLoadingPrice = true
        do {
            priceInfo = try await examService.fetchExamPrice(examType: examType)
            priceError = nil
        } catch {
            priceError = error.localizedDescription
            print("Error fetching price: \(error)")
        }
        isLoadingPrice = false
        
        // Load test result status for upload-required exams
        await loadTestResultStatus()
    }
    
    private func loadTestType() async {
        isLoadingTestType = true
        let academyService = AcademyService()
        
        do {
            let tests = try await academyService.fetchCourseTests(courseId: courseId)
            // Find the test matching this exam's test ID
            courseTest = tests.first { $0.id == testId }
            print("✅ [ExamIntroView] Loaded test type for \(examType.displayName): \(courseTest?.testType ?? "none")")
        } catch {
            print("⚠️ [ExamIntroView] Error loading test type: \(error)")
        }
        
        isLoadingTestType = false
    }
    
    private func loadTestResultStatus() async {
        guard requiresUpload, let currentUser = authService.currentUser else {
            isLoadingTestResult = false
            return
        }
        
        isLoadingTestResult = true
        do {
            testResult = try await uploadService.getTestResultStatus(
                pilotId: currentUser.id,
                testId: testId
            )
        } catch {
            print("Error loading test result status: \(error)")
        }
        isLoadingTestResult = false
    }
    
    private func getPrerequisiteStatus(index: Int) -> Bool {
        guard let status = prerequisitesStatus else { return false }
        switch index {
        case 0:
            return status.passedGroundSchoolTest
        case 1:
            return status.completedUnit4
        default:
            return false
        }
    }
}

// MARK: - Supporting Views

struct ExamDetailRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .primary
    
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
                .foregroundColor(valueColor)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct PrerequisiteDetailRow: View {
    let number: Int
    let title: String
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 28, height: 28)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.caption.bold())
                } else {
                    Text("\(number)")
                        .foregroundColor(.gray)
                        .font(.caption.bold())
                }
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(isCompleted ? .primary : .secondary)
                .strikethrough(isCompleted)
            
            Spacer()
            
            if isCompleted {
                Text("Completed")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text("Required")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct WhatToExpectRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        ExamIntroView(examType: .flightReview)
            .environmentObject(AuthService())
    }
}

