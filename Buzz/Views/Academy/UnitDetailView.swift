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
    @State private var selectedPDF: PDFSelection?
    @State private var isCompleted = false
    @State private var showTestView = false
    @State private var canTakeTest = false
    @State private var isLoading = false
    @State private var showCompletionSuccess = false
    
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
                                selectedPDF = PDFSelection(url: pdfUrl)
                            }) {
                                ModuleButtonContent(title: getPDFName(index: index))
                            }
                        }
                    }
                    .padding(.horizontal)
                    .sheet(item: $selectedPDF) { pdfSelection in
                        NavigationView {
                            FileViewer(
                                fileUrl: pdfSelection.url,
                                fileType: .pdf,
                                bucketName: "course-materials"
                            )
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
                    .transition(.opacity)
                }
                
                // Success Message (temporary)
                if showCompletionSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Unit marked as completed!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .transition(.opacity)
                }
                
                // Mark as Complete Button (for all units)
                if !isCompleted {
                    Button(action: {
                        Task {
                            await markUnitComplete()
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.circle")
                            }
                            Text(isLoading ? "Marking as Complete..." : "Mark as Completed")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isLoading ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
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
            showCompletionSuccess = true
            
            // Hide success message after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showCompletionSuccess = false

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
            let academyService = AcademyService()
            
            // Fetch the Ground School Test for this course
            let courseTests = try await academyService.fetchCourseTests(courseId: course.id)
            
            // Find the Ground School Test (assuming it's the first test or has a specific name)
            guard let groundSchoolTest = courseTests.first else {
                print("No Ground School Test found for this course")
                canTakeTest = false
                return
            }
            
            // Get the required units from the test
            let requiredUnitNumbers = groundSchoolTest.requiredUnits
            
            if requiredUnitNumbers.isEmpty {
                // If no required units specified, default to checking mandatory units (legacy behavior)
                let allUnits = try await academyService.fetchCourseUnits(courseId: course.id)
                let mandatoryUnits = allUnits.filter { $0.isMandatory }
                
                // Check if all mandatory units are completed
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
            } else {
                // Check if all required units (by unit number) are completed
                let completedUnitNumbers = await academyService.checkUnitCompletionsByNumber(
                    pilotId: currentUser.id,
                    courseId: course.id,
                    unitNumbers: requiredUnitNumbers
                )
                
                // Check if all required units are in the completed set
                canTakeTest = requiredUnitNumbers.allSatisfy { completedUnitNumbers.contains($0) }
            }
            
            print("✅ [UnitDetailView] Can take test: \(canTakeTest)")
        } catch {
            print("Error checking if can take test: \(error)")
        }
    }
    
    // Helper function to get PDF name from backend or return empty string if not available
    private func getPDFName(index: Int) -> String {
        // Check if we have a name in the pdfNames array at this index
        if index < unit.pdfNames.count {
            let name = unit.pdfNames[index]
            // Return the name if it's not empty, otherwise return empty string
            return name.isEmpty ? "" : name
        }
        // If pdfNames is null or index is out of bounds, return empty string
        return ""
    }
}

struct ModuleButtonContent: View {
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: "doc.fill")
                .font(.title3)
            Text(title)
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

struct ComingSoonModuleView: View {
    let title: String
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 64, weight: .semibold))
                .foregroundColor(.orange)
            Text("Coming Soon!")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("The \(title) content will be available soon. Check back later for updates.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .padding()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - PDF Selection Wrapper

private struct PDFSelection: Identifiable {
    let id = UUID()
    let url: String
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
