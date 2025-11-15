//
//  UnitDetailView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/14/25.
//

import SwiftUI
import Supabase
import PostgREST

struct UnitDetailView: View {
    let unit: CourseUnit
    let course: TrainingCourse
    @EnvironmentObject var authService: AuthService
    @State private var showPDFViewer = false
    @State private var selectedPDFUrl: String?
    @State private var isCompleted = false
    @State private var showTestView = false
    @State private var canTakeTest = false
    @State private var isLoading = false
    
    // Check if this is the UAS Pilot Course
    var isUASPilotCourse: Bool {
        course.id.uuidString == "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
    }
    
    // Check if this is unit 3 (last mandatory unit)
    var isLastMandatoryUnit: Bool {
        isUASPilotCourse && unit.unitNumber == 3 && unit.isMandatory
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Unit Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        // Unit Number Badge
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 60, height: 60)
                            
                            Text("\(unit.unitNumber)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(unit.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if unit.isMandatory {
                                Text("Mandatory")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(6)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    if let description = unit.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // PDF Course Material Buttons (multiple modules per unit)
                if !unit.pdfUrls.isEmpty {
                    VStack(spacing: 12) {
                        Text("Course Material PDFs")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ForEach(Array(unit.pdfUrls.enumerated()), id: \.offset) { index, pdfUrl in
                            Button(action: {
                                selectedPDFUrl = pdfUrl
                                showPDFViewer = true
                            }) {
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .font(.title3)
                                    Text("Module \(index + 1)")
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .sheet(isPresented: $showPDFViewer) {
                        if let pdfUrl = selectedPDFUrl {
                            NavigationView {
                                FileViewer(
                                    fileUrl: pdfUrl,
                                    fileType: .pdf,
                                    bucketName: "course-materials"
                                )
                            }
                        }
                    }
                }
                
                // Course Material Content (text content)
                if let content = unit.content, !content.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Course Material")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(content)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else if unit.pdfUrls.isEmpty {
                    // Placeholder content (only show if no PDF)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Course Material")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Course material for \(unit.title) will be available here. This section will contain detailed lessons, videos, readings, and assessments.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Completion Status
                if isCompleted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                        Text("Unit Completed")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Mark as Complete Button (for units 1-3)
                if isUASPilotCourse && unit.unitNumber <= 3 && !isCompleted {
                    Button(action: {
                        Task {
                            await markUnitComplete()
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Mark as Complete")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // Take Test Button (after completing units 1-3)
                if isUASPilotCourse && isLastMandatoryUnit && isCompleted && canTakeTest {
                    Button(action: {
                        showTestView = true
                    }) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            Text("Take Ground School Test")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // Course Info Footer
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "book.fill")
                            .foregroundColor(.blue)
                        Text("Course: \(course.title)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let stepNumber = unit.stepNumber {
                        HStack {
                            Image(systemName: "list.number")
                                .foregroundColor(.blue)
                            Text("Step \(stepNumber)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Unit \(unit.unitNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await checkCompletionStatus()
            if isUASPilotCourse {
                await checkIfCanTakeTest()
            }
        }
        .sheet(isPresented: $showTestView) {
            if let currentUser = authService.currentUser {
                GroundSchoolTestView(course: course, pilotId: currentUser.id)
            }
        }
    }
    
    private func checkCompletionStatus() async {
        guard let currentUser = authService.currentUser else { return }
        
        do {
            let supabase = SupabaseClient.shared.client
            let response: [UnitCompletion] = try await supabase
                .from("unit_completions")
                .select()
                .eq("pilot_id", value: currentUser.id.uuidString)
                .eq("unit_id", value: unit.id.uuidString)
                .execute()
                .value
            
            isCompleted = !response.isEmpty
        } catch {
            print("Error checking completion status: \(error)")
        }
    }
    
    private func markUnitComplete() async {
        guard let currentUser = authService.currentUser else { return }
        
        isLoading = true
        
        do {
            let supabase = SupabaseClient.shared.client
            let completion: [String: AnyJSON] = [
                "pilot_id": .string(currentUser.id.uuidString),
                "unit_id": .string(unit.id.uuidString),
                "course_id": .string(course.id.uuidString)
            ]
            
            try await supabase
                .from("unit_completions")
                .upsert(completion, onConflict: "pilot_id,unit_id")
                .execute()
            
            isCompleted = true
            
            // If this is unit 3, check if can take test
            if isLastMandatoryUnit {
                await checkIfCanTakeTest()
            }
        } catch {
            print("Error marking unit complete: \(error)")
        }
        
        isLoading = false
    }
    
    private func checkIfCanTakeTest() async {
        guard let currentUser = authService.currentUser else { return }
        guard isUASPilotCourse else { return }
        
        do {
            let supabase = SupabaseClient.shared.client
            
            // Check if units 1, 2, and 3 are all completed
            // First, get all units for the course
            let academyService = AcademyService()
            let allUnits = try await academyService.fetchCourseUnits(courseId: course.id)
            let mandatoryUnits = allUnits.filter { $0.isMandatory && $0.unitNumber <= 3 }
            
            // Check completions for units 1-3
            var allCompleted = true
            for mandatoryUnit in mandatoryUnits {
                let response: [UnitCompletion] = try await supabase
                    .from("unit_completions")
                    .select()
                    .eq("pilot_id", value: currentUser.id.uuidString)
                    .eq("unit_id", value: mandatoryUnit.id.uuidString)
                    .execute()
                    .value
                
                if response.isEmpty {
                    allCompleted = false
                    break
                }
            }
            
            canTakeTest = allCompleted
        } catch {
            print("Error checking if can take test: \(error)")
        }
    }
}

// MARK: - Unit Completion Model

struct UnitCompletion: Codable {
    let id: UUID
    let pilotId: UUID
    let unitId: UUID
    let courseId: UUID
    let completedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case unitId = "unit_id"
        case courseId = "course_id"
        case completedAt = "completed_at"
    }
}

