//
//  TestCenterView.swift
//  Buzz
//
//  Test Center view showing available exams with eligibility status
//

import SwiftUI
import Auth

struct TestCenterView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var examService = ExamService()
    @StateObject private var uploadService = ExamResultUploadService()
    @State private var prerequisitesStatus: ExamPrerequisitesStatus?
    @State private var isCheckingPrerequisites = true
    @State private var existingAppointments: [ExamType: Bool] = [:]
    @State private var selectedAppointment: ExamAppointment?
    @State private var testResultStatuses: [ExamType: TestResult] = [:]
    @State private var showPassedExams = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Test Center")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Schedule and take your certification exams")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Prerequisites Status Card
                if isCheckingPrerequisites {
                    ProgressView("Checking eligibility...")
                        .padding()
                } else if let status = prerequisitesStatus {
                    PrerequisitesStatusCard(status: status)
                        .padding(.horizontal)
                }
                
                // Available Exams (non-passed exams)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Available Exams")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(ExamType.allCases) { examType in
                        let config = examService.getConfig(for: examType)
                        let testResult = testResultStatuses[examType]
                        let hasPassed = testResult?.passed == true && testResult?.uploadStatusEnum == .approved
                        
                        // Only show if not passed
                        if !hasPassed {
                            // Ground School Test is free and doesn't require scheduling
                            if examType == .groundSchoolTest {
                                if !(prerequisitesStatus?.passedGroundSchoolTest ?? false) {
                                    GroundSchoolTestCard(
                                        config: config,
                                        hasPassedTest: false
                                    )
                                    .padding(.horizontal)
                                }
                            } else {
                                // Regular paid exams (Flight Review, ROC-A)
                                ExamCard(
                                    examType: examType,
                                    config: config,
                                    isEligible: prerequisitesStatus?.isEligible ?? false,
                                    hasExistingAppointment: existingAppointments[examType] ?? false,
                                    testResult: testResult
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                
                // Passed Exams (collapsible)
                VStack(alignment: .leading, spacing: 16) {
                    Button(action: {
                        withAnimation {
                            showPassedExams.toggle()
                        }
                    }) {
                        HStack {
                            Text("Passed Exams")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: showPassedExams ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        .padding(.horizontal)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if showPassedExams {
                        ForEach(ExamType.allCases) { examType in
                            let config = examService.getConfig(for: examType)
                            let testResult = testResultStatuses[examType]
                            let hasPassed = testResult?.passed == true && testResult?.uploadStatusEnum == .approved
                            
                            // Only show passed exams
                            if hasPassed || (examType == .groundSchoolTest && (prerequisitesStatus?.passedGroundSchoolTest ?? false)) {
                                if examType == .groundSchoolTest {
                                    GroundSchoolTestCard(
                                        config: config,
                                        hasPassedTest: true
                                    )
                                    .padding(.horizontal)
                                } else {
                                    ExamCard(
                                        examType: examType,
                                        config: config,
                                        isEligible: prerequisitesStatus?.isEligible ?? false,
                                        hasExistingAppointment: existingAppointments[examType] ?? false,
                                        testResult: testResult
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                
                // Scheduled Appointments Section
                if !examService.appointments.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Appointments")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(examService.appointments.filter { $0.status != .cancelled }) { appointment in
                            AppointmentCard(appointment: appointment)
                                .padding(.horizontal)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedAppointment = appointment
                                }
                        }
                    }
                    .padding(.top, 8)
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Test Center")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .sheet(item: $selectedAppointment) { appointment in
            AppointmentDetailSheet(
                appointment: appointment,
                examService: examService,
                onCancelled: {
                    selectedAppointment = nil
                    Task {
                        await loadData()
                    }
                }
            )
            .environmentObject(authService)
        }
    }
    
    private func loadData() async {
        guard let currentUser = authService.currentUser else { return }
        
        isCheckingPrerequisites = true
        
        // Load exam configurations from backend
        await examService.fetchExamConfigs()
        
        // Check prerequisites
        do {
            prerequisitesStatus = try await examService.checkPrerequisites(pilotId: currentUser.id)
        } catch {
            print("Error checking prerequisites: \(error)")
        }
        
        // Check for existing appointments
        for examType in ExamType.allCases {
            existingAppointments[examType] = await examService.hasExistingAppointment(
                pilotId: currentUser.id,
                examType: examType
            )
        }
        
        // Fetch test result statuses for upload-required exams
        await loadTestResultStatuses(pilotId: currentUser.id)
        
        // Fetch appointments
        await examService.fetchAppointments(pilotId: currentUser.id)
        
        isCheckingPrerequisites = false
    }
    
    private func loadTestResultStatuses(pilotId: UUID) async {
        // Test IDs for Flight Review and ROC-A
        let flightReviewTestId = UUID(uuidString: "f1a2b3c4-d5e6-7890-abcd-f11ab0000001")!
        let rocATestId = UUID(uuidString: "a0c4a5b6-c7d8-9012-efab-a0ca00000001")!
        
        // Fetch Flight Review test result (part of UAS Pilot Course)
        if let flightReviewResult = try? await uploadService.getTestResultStatus(
            pilotId: pilotId,
            testId: flightReviewTestId
        ) {
            testResultStatuses[.flightReview] = flightReviewResult
        }
        
        // Fetch ROC-A test result (part of UAS Pilot Course)
        if let rocAResult = try? await uploadService.getTestResultStatus(
            pilotId: pilotId,
            testId: rocATestId
        ) {
            testResultStatuses[.rocA] = rocAResult
        }
    }
}

// MARK: - Prerequisites Status Card

struct PrerequisitesStatusCard: View {
    let status: ExamPrerequisitesStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: status.isEligible ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(status.isEligible ? .green : .orange)
                    .font(.title2)
                
                Text(status.isEligible ? "You're Eligible!" : "Prerequisites Required")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            if status.isEligible {
                Text("You have met all prerequisites and can schedule your exams.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Complete the following to unlock exams:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    PrerequisiteRow(
                        title: "Pass Ground School Test",
                        isCompleted: status.passedGroundSchoolTest
                    )
                    PrerequisiteRow(
                        title: "Complete Unit 4",
                        isCompleted: status.completedUnit4
                    )
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(status.isEligible ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(status.isEligible ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

struct PrerequisiteRow: View {
    let title: String
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? .green : .gray)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(isCompleted ? .primary : .secondary)
                .strikethrough(isCompleted)
        }
    }
}

// MARK: - Exam Card

struct ExamCard: View {
    let examType: ExamType
    let config: ExamTypeConfig
    let isEligible: Bool
    let hasExistingAppointment: Bool
    let testResult: TestResult?
    
    @EnvironmentObject var authService: AuthService
    
    var isLocked: Bool {
        !isEligible || hasExistingAppointment
    }
    
    var uploadStatus: TestUploadStatus {
        testResult?.uploadStatusEnum ?? .notSubmitted
    }
    
    var hasPassed: Bool {
        testResult?.passed == true
    }
    
    var body: some View {
        NavigationLink(destination: ExamIntroView(examType: examType)) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isLocked ? Color.gray.opacity(0.2) : examType.color.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: config.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isLocked ? .gray : examType.color)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(config.displayName)
                            .font(.headline)
                            .foregroundColor(isLocked ? .secondary : .primary)
                        
                        // Show status badges based on test result
                        if hasPassed && uploadStatus == .approved {
                            // Passed and approved
                            Text("Passed")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        } else if uploadStatus == .pending {
                            // Under review
                            Text("Pending")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        } else if hasExistingAppointment {
                            // Scheduled
                            Text("Scheduled")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(config.shortDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        Label("\(config.durationMinutes) min", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if config.allowsOnline {
                            Label("In-person or Online", systemImage: "video")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Label("In-person only", systemImage: "mappin")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Lock/Arrow indicator
                if isLocked {
                    if hasExistingAppointment {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    } else {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                            .font(.title3)
                    }
                } else if hasPassed && uploadStatus == .approved {
                    // Show checkmark for passed exams
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                } else {
                    // Removed clock icon for pending - just show chevron
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .disabled(isLocked)
    }
}

// MARK: - Appointment Card

struct AppointmentCard: View {
    let appointment: ExamAppointment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: appointment.examType.icon)
                    .foregroundColor(appointment.examType.color)
                    .font(.title3)
                
                Text(appointment.examType.displayName)
                    .font(.headline)
                
                Spacer()
                
                ExamStatusBadge(status: appointment.status)
            }
            
            Divider()
            
            HStack(spacing: 16) {
                Label(appointment.formattedDate, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label(
                    appointment.locationType.displayName,
                    systemImage: appointment.locationType.icon
                )
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            if let address = appointment.locationAddress, appointment.locationType == .inPerson {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.secondary)
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ExamStatusBadge: View {
    let status: ExamAppointmentStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption)
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Appointment Detail Sheet

struct AppointmentDetailSheet: View {
    let appointment: ExamAppointment
    let examService: ExamService
    let onCancelled: () -> Void
    
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var showCancelConfirmation = false
    @State private var isCancelling = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showCopiedAlert = false
    @State private var showRescheduleView = false
    
    private var config: ExamTypeConfig {
        examService.getConfig(for: appointment.examType)
    }
    
    private var canReschedule: Bool {
        // Can only reschedule pending or confirmed appointments that are more than 24 hours away
        (appointment.status == .pending || appointment.status == .confirmed) && !isWithin24Hours
    }
    
    private var canCancel: Bool {
        // Can only cancel pending or confirmed appointments
        appointment.status == .pending || appointment.status == .confirmed
    }
    
    private var isWithin24Hours: Bool {
        let hoursUntilExam = Calendar.current.dateComponents([.hour], from: Date(), to: appointment.scheduledDate).hour ?? 0
        return hoursUntilExam < 24
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(appointment.examType.color.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: appointment.examType.icon)
                                .font(.system(size: 36))
                                .foregroundColor(appointment.examType.color)
                        }
                        
                        Text(appointment.examType.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        ExamStatusBadge(status: appointment.status)
                    }
                    .padding(.top, 20)
                    
                    // Appointment Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Appointment Details")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            DetailRow(icon: "calendar", label: "Date & Time", value: appointment.formattedDate)
                            DetailRow(icon: "clock", label: "Duration", value: "\(appointment.durationMinutes) minutes")
                            DetailRow(icon: appointment.locationType.icon, label: "Format", value: appointment.locationType.displayName)
                            
                            if let address = appointment.locationAddress {
                                DetailRow(icon: "mappin.and.ellipse", label: "Location", value: address)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Zoom Link Section (for online exams)
                    if appointment.locationType == .online, appointment.hasValidZoomLink, let meetingLink = appointment.meetingLink {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Zoom Meeting")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "video.fill")
                                        .foregroundColor(.blue)
                                    Text("Meeting Link")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                HStack {
                                    Text(meetingLink)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        UIPasteboard.general.string = meetingLink
                                        showCopiedAlert = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "doc.on.doc")
                                            Text("Copy")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    }
                                }
                                
                                if let password = appointment.zoomMeetingPassword, !password.isEmpty {
                                    HStack {
                                        Text("Password: \(password)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Button(action: {
                                            UIPasteboard.general.string = password
                                            showCopiedAlert = true
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                // Join Meeting Button
                                if let url = URL(string: meetingLink) {
                                    Link(destination: url) {
                                        HStack {
                                            Image(systemName: "video.fill")
                                            Text("Join Zoom Meeting")
                                        }
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                    }
                                    .padding(.top, 8)
                                }
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Reschedule & Cancel Buttons
                    if canCancel {
                        VStack(spacing: 12) {
                            // Reschedule Button (only available more than 24 hours before)
                            if canReschedule {
                                Button(action: {
                                    showRescheduleView = true
                                }) {
                                    HStack {
                                        Image(systemName: "calendar.badge.clock")
                                        Text("Reschedule")
                                    }
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }
                            
                            // Cancel Button
                            Button(action: {
                                showCancelConfirmation = true
                            }) {
                                HStack {
                                    if isCancelling {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "xmark.circle")
                                        Text("Cancel Appointment")
                                    }
                                }
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isCancelling)
                            
                            // Policy notice
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Exam fees are non-refundable. Rescheduling is not available within 24 hours.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Cancel Appointment",
                isPresented: $showCancelConfirmation,
                titleVisibility: .visible
            ) {
                Button("Cancel Appointment", role: .destructive) {
                    Task {
                        await cancelAppointment()
                    }
                }
                Button("Keep Appointment", role: .cancel) {}
            } message: {
                Text("Are you sure you want to cancel this appointment? Exam fees are non-refundable.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Copied!", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            }
            .sheet(isPresented: $showRescheduleView) {
                RescheduleExamView(
                    appointment: appointment,
                    examService: examService,
                    onRescheduled: {
                        showRescheduleView = false
                        onCancelled() // Reuse this callback to refresh the parent view
                    }
                )
                .environmentObject(authService)
            }
        }
    }
    
    private func cancelAppointment() async {
        guard let currentUser = authService.currentUser else { return }
        
        isCancelling = true
        
        do {
            try await examService.cancelAppointment(
                appointmentId: appointment.id,
                pilotId: currentUser.id
            )
            isCancelling = false
            onCancelled()
        } catch {
            isCancelling = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Reschedule Exam View

struct RescheduleExamView: View {
    let appointment: ExamAppointment
    let examService: ExamService
    let onRescheduled: () -> Void
    
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    @State private var selectedTime: Date?
    @State private var locationType: ExamLocationType = .inPerson
    @State private var locationAddress = ""
    @State private var isRescheduling = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    private var config: ExamTypeConfig {
        examService.getConfig(for: appointment.examType)
    }
    
    // Minimum scheduling date is tomorrow
    private var minimumDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }
    
    // Maximum scheduling date is 3 months from now
    private var maximumDate: Date {
        Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    }
    
    private var availableTimeSlots: [Date] {
        examService.getAvailableTimeSlots(for: selectedDate)
    }
    
    private var canProceed: Bool {
        guard selectedTime != nil else { return false }
        
        if locationType == .inPerson {
            return !locationAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        return true
    }
    
    private var scheduledDateTime: Date? {
        guard let time = selectedTime else { return nil }
        
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        return calendar.date(from: combinedComponents)
    }
    
    private var formattedScheduledDateTime: String {
        guard let dateTime = scheduledDateTime else {
            return "Not selected"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateTime)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if showSuccess {
                        // Success View
                        VStack(spacing: 24) {
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.1))
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.green)
                            }
                            
                            Text("Exam Rescheduled!")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Your \(appointment.examType.displayName) has been rescheduled successfully.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Spacer()
                            
                            Button(action: {
                                onRescheduled()
                            }) {
                                Text("Done")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    } else {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 48))
                                .foregroundColor(.blue)
                            
                            Text("Reschedule Exam")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Select a new date and time for your \(appointment.examType.displayName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Date Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("1. Select New Date")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            DatePicker(
                                "Exam Date",
                                selection: $selectedDate,
                                in: minimumDate...maximumDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)
                            .onChange(of: selectedDate) { _, _ in
                                selectedTime = nil
                            }
                        }
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Time Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("2. Select New Time")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(availableTimeSlots, id: \.self) { slot in
                                    TimeSlotButton(
                                        time: slot,
                                        isSelected: selectedTime == slot,
                                        action: {
                                            selectedTime = slot
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Location Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("3. \(config.allowsOnline ? "Select Format" : "Enter Location")")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if config.allowsOnline {
                                VStack(spacing: 12) {
                                    LocationTypeButton(
                                        type: .inPerson,
                                        isSelected: locationType == .inPerson,
                                        action: { locationType = .inPerson }
                                    )
                                    
                                    LocationTypeButton(
                                        type: .online,
                                        isSelected: locationType == .online,
                                        action: { locationType = .online }
                                    )
                                }
                                .padding(.horizontal)
                            }
                            
                            if locationType == .inPerson {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Enter the address where the exam will be conducted:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    TextField("Street address, City, State, ZIP", text: $locationAddress)
                                        .textFieldStyle(.roundedBorder)
                                        .textContentType(.fullStreetAddress)
                                }
                                .padding(.horizontal)
                            } else {
                                HStack(spacing: 12) {
                                    Image(systemName: "video.fill")
                                        .foregroundColor(.blue)
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Online Exam via Zoom")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        
                                        Text("A new Zoom meeting link will be sent to your email.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }
                        }
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Summary
                        VStack(alignment: .leading, spacing: 12) {
                            Text("4. Confirm New Schedule")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                SummaryRow(label: "Exam", value: config.displayName)
                                SummaryRow(label: "Duration", value: "\(config.durationMinutes) minutes")
                                SummaryRow(
                                    label: "New Date & Time",
                                    value: formattedScheduledDateTime,
                                    valueColor: scheduledDateTime == nil ? .orange : .primary
                                )
                                SummaryRow(label: "Format", value: locationType.displayName)
                                
                                if locationType == .inPerson && !locationAddress.isEmpty {
                                    SummaryRow(label: "Location", value: locationAddress)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                        
                        // Reschedule Button
                        Button(action: {
                            Task {
                                await rescheduleAppointment()
                            }
                        }) {
                            HStack {
                                if isRescheduling {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("Rescheduling...")
                                } else {
                                    Image(systemName: "calendar.badge.clock")
                                    Text("Confirm Reschedule")
                                }
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canProceed && !isRescheduling ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!canProceed || isRescheduling)
                        .padding(.horizontal)
                        
                        // Note
                        Text("No additional payment required for rescheduling.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !showSuccess {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // Set initial values from current appointment
                locationType = appointment.locationType
                locationAddress = appointment.locationAddress ?? ""
            }
        }
    }
    
    private func rescheduleAppointment() async {
        guard let currentUser = authService.currentUser,
              let dateTime = scheduledDateTime else { return }
        
        isRescheduling = true
        
        do {
            _ = try await examService.rescheduleAppointment(
                appointmentId: appointment.id,
                pilotId: currentUser.id,
                newScheduledDate: dateTime,
                locationType: locationType,
                locationAddress: locationType == .inPerson ? locationAddress : nil,
                examType: appointment.examType,
                pilotEmail: currentUser.email
            )
            isRescheduling = false
            showSuccess = true
        } catch {
            isRescheduling = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        TestCenterView()
            .environmentObject(AuthService())
    }
}

// MARK: - Ground School Test Card

struct GroundSchoolTestCard: View {
    let config: ExamTypeConfig
    let hasPassedTest: Bool
    
    @EnvironmentObject var authService: AuthService
    @State private var navigateToTest = false
    @State private var showIntroSheet = false
    
    var body: some View {
        Button(action: {
            showIntroSheet = true
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(hasPassedTest ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: hasPassedTest ? "checkmark.seal.fill" : config.icon)
                        .font(.system(size: 24))
                        .foregroundColor(hasPassedTest ? .green : .orange)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(config.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if hasPassedTest {
                            Text("Passed")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(config.shortDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        Label("\(config.durationMinutes) min", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("Free", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showIntroSheet) {
            if let currentUser = authService.currentUser {
                GroundSchoolTestIntroSheetView(
                    config: config,
                    hasPassedTest: hasPassedTest,
                    onStartTest: {
                        showIntroSheet = false
                        navigateToTest = true
                    }
                )
                .environmentObject(authService)
            }
        }
        .background(
            NavigationLink(
                destination: authService.currentUser.map { currentUser in
                    // Need to get the UAS Pilot Course
                    GroundSchoolTestWrapperView(pilotId: currentUser.id)
                        .navigationBarBackButtonHidden(true)
                },
                isActive: $navigateToTest
            ) {
                EmptyView()
            }
            .hidden()
        )
    }
}

// MARK: - Ground School Test Intro Sheet

struct GroundSchoolTestIntroSheetView: View {
    let config: ExamTypeConfig
    let hasPassedTest: Bool
    let onStartTest: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(hasPassedTest ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: hasPassedTest ? "checkmark.seal.fill" : config.icon)
                                .font(.system(size: 36))
                                .foregroundColor(hasPassedTest ? .green : .orange)
                        }
                        
                        Text(config.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if hasPassedTest {
                            Text("Passed")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About This Test")
                            .font(.headline)
                        
                        Text(config.fullDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Test Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Test Details")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            DetailRow(icon: "clock", label: "Duration", value: "\(config.durationMinutes) minutes")
                            DetailRow(icon: "checklist", label: "Questions", value: "Multiple choice")
                            DetailRow(icon: "percent", label: "Passing Score", value: "70%")
                            DetailRow(icon: "dollarsign.circle.fill", label: "Cost", value: "Free")
                            DetailRow(icon: "arrow.clockwise", label: "Retakes", value: "Unlimited")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    if hasPassedTest {
                        // Already passed - show option to retake
                        VStack(spacing: 12) {
                            Text("You've already passed this test!")
                                .font(.subheadline)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                onStartTest()
                            }) {
                                Text("Retake Test")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // Not passed yet - show start button
                        Button(action: {
                            onStartTest()
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start Test")
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Test Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Ground School Test Wrapper View

struct GroundSchoolTestWrapperView: View {
    let pilotId: UUID
    @StateObject private var academyService = AcademyService()
    @State private var course: TrainingCourse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // UAS Pilot Course UUID (fixed)
    private let uasPilotCourseId = UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-ef1234567890")!
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading test...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else if let errorMessage = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    Text("Error Loading Test")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if let course = course {
                GroundSchoolTestView(course: course, pilotId: pilotId)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("Course Not Found")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Unable to load the UAS Pilot Course.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .task {
            await loadCourse()
        }
    }
    
    private func loadCourse() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch the UAS Pilot Course
            try await academyService.fetchCourses()
            course = academyService.courses.first { $0.id == uasPilotCourseId }
            
            if course == nil {
                errorMessage = "UAS Pilot Course not found"
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading course: \(error)")
        }
        
        isLoading = false
    }
}
