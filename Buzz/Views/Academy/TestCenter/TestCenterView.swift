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
    @State private var prerequisitesStatus: ExamPrerequisitesStatus?
    @State private var isCheckingPrerequisites = true
    @State private var existingAppointments: [ExamType: Bool] = [:]
    @State private var selectedAppointment: ExamAppointment?
    
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
                
                // Available Exams
                VStack(alignment: .leading, spacing: 16) {
                    Text("Available Exams")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(ExamType.allCases) { examType in
                        ExamCard(
                            examType: examType,
                            isEligible: prerequisitesStatus?.isEligible ?? false,
                            hasExistingAppointment: existingAppointments[examType] ?? false
                        )
                        .padding(.horizontal)
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
        
        // Fetch appointments
        await examService.fetchAppointments(pilotId: currentUser.id)
        
        isCheckingPrerequisites = false
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
    let isEligible: Bool
    let hasExistingAppointment: Bool
    
    @EnvironmentObject var authService: AuthService
    
    var isLocked: Bool {
        !isEligible || hasExistingAppointment
    }
    
    var body: some View {
        NavigationLink(destination: ExamIntroView(examType: examType)) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isLocked ? Color.gray.opacity(0.2) : examType.color.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: examType.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isLocked ? .gray : examType.color)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(examType.displayName)
                            .font(.headline)
                            .foregroundColor(isLocked ? .secondary : .primary)
                        
                        if hasExistingAppointment {
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
                    
                    Text(examType.shortDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        Label("\(examType.durationMinutes) min", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if examType.allowsOnline {
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
                } else {
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
                    
                    // Cancel Button
                    if canCancel {
                        VStack(spacing: 12) {
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
                            
                            if isWithin24Hours {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Cancellation within 24 hours is non-refundable")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            } else {
                                Text("You can cancel up to 24 hours before for a full refund")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                if isWithin24Hours {
                    Text("This cancellation is within 24 hours and is non-refundable. Are you sure you want to cancel?")
                } else {
                    Text("Are you sure you want to cancel this appointment? You will receive a full refund.")
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Copied!", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
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

#Preview {
    NavigationStack {
        TestCenterView()
            .environmentObject(AuthService())
    }
}

