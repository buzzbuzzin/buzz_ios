//
//  ProctorInfoView.swift
//  Buzz
//
//  View for entering proctor information before starting a proctored exam
//

import SwiftUI

struct ProctorInfoView: View {
    let testId: UUID
    let course: TrainingCourse
    let pilotId: UUID
    let testName: String
    let passingScore: Int
    let durationMinutes: Int
    let onStartTest: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var proctorName: String = ""
    @State private var showValidationError = false
    @FocusState private var isProctorNameFocused: Bool
    
    var canProceed: Bool {
        !proctorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                        }
                        
                        Text("Proctor Information")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("This exam requires supervision by a certified proctor. Please enter the proctor's information below.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // Proctor Information Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Proctor Details")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Proctor's Full Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            TextField("Enter proctor's full name", text: $proctorName)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.name)
                                .autocapitalization(.words)
                                .focused($isProctorNameFocused)
                                .submitLabel(.done)
                                .onSubmit {
                                    if canProceed {
                                        startExam()
                                    } else {
                                        showValidationError = true
                                    }
                                }
                            
                            if showValidationError && !canProceed {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    Text("Proctor name is required")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Important Notice
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            Text("Important")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InfoBulletPoint(text: "The proctor must be present during the entire exam")
                            InfoBulletPoint(text: "Ensure you have a stable internet connection")
                            InfoBulletPoint(text: "The exam timer starts immediately after you begin")
                            InfoBulletPoint(text: "You cannot pause the exam once started")
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Exam Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Exam Details")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ExamInfoRow(icon: "doc.text", label: "Exam", value: testName)
                            ExamInfoRow(icon: "clock", label: "Duration", value: "\(durationMinutes) minutes")
                            ExamInfoRow(icon: "percent", label: "Passing Score", value: "\(passingScore)%")
                            ExamInfoRow(icon: "arrow.clockwise", label: "Attempts", value: "Unlimited")
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Start Proctored Exam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Start Exam") {
                        if canProceed {
                            startExam()
                        } else {
                            showValidationError = true
                            isProctorNameFocused = true
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canProceed)
                }
            }
            .onAppear {
                // Auto-focus the text field when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isProctorNameFocused = true
                }
            }
        }
    }
    
    private func startExam() {
        let trimmedName = proctorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showValidationError = true
            return
        }
        
        onStartTest(trimmedName)
        dismiss()
    }
}

// MARK: - Supporting Views

struct InfoBulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundColor(.secondary)
                .padding(.top, 6)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct ExamInfoRow: View {
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

#Preview {
    ProctorInfoView(
        testId: UUID(),
        course: TrainingCourse(
            id: UUID(),
            title: "ROC-A Exam",
            description: "Remote Operations Commander - Advanced",
            duration: "2 hours",
            level: .advanced,
            category: .advanced,
            instructor: "Buzz",
            instructorPictureUrl: nil,
            rating: 4.8,
            studentsCount: 150,
            isEnrolled: true,
            provider: .buzz,
            badgeId: nil,
            isRecurrent: false,
            recurrentDueDate: nil,
            requiresUasGroundSchool: true,
            requiresFlightReviewPassed: false,
            requiresRocAPassed: false,
            externalUrl: nil,
            coverImageUrl: nil
        ),
        pilotId: UUID(),
        testName: "ROC-A Multiple Choice Exam",
        passingScore: 70,
        durationMinutes: 60,
        onStartTest: { _ in }
    )
}
