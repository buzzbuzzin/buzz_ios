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
                        
                        ForEach(examService.appointments) { appointment in
                            AppointmentCard(appointment: appointment)
                                .padding(.horizontal)
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

#Preview {
    NavigationStack {
        TestCenterView()
            .environmentObject(AuthService())
    }
}

