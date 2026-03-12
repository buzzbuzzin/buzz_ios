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
    @StateObject private var academyService = AcademyService()
    @State private var selectedMaterial: MaterialSelection?
    @State private var isCompleted = false
    @State private var showTestView = false
    @State private var canTakeTest = false
    @State private var showCompletionSuccess = false
    @State private var courseTest: CourseTest?
    @State private var showSlidePresentation = false
    @State private var isLastMandatoryUnit = false
    @State private var hasExpressPromotion = false
    
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
                
                // Course Material - Interactive Slideshow
                if !unit.materials.isEmpty {
                    VStack(spacing: 16) {
                        Text("Course Materials")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button(action: {
                            showSlidePresentation = true
                        }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Start Lesson")
                                        .font(.headline)
                                    Text("\(unit.materials.count) slide\(unit.materials.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
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
                    .padding(.horizontal)
                    .fullScreenCover(isPresented: $showSlidePresentation) {
                        SlidePresentationView(
                            unit: unit,
                            materials: unit.materials,
                            onComplete: {
                                Task {
                                    await markUnitComplete()
                                }
                                showSlidePresentation = false
                            }
                        )
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
                } else if unit.materials.isEmpty {
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
                
                
                // Take Test Button (after completing required units, or express promotion bypass)
                if ((isLastMandatoryUnit && isCompleted) || hasExpressPromotion) && canTakeTest, let test = courseTest {
                    Button(action: {
                        showTestView = true
                    }) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            Text("Take \(test.testName)")
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
            await loadCourseTest()
            await checkExpressPromotionStatus()
            await checkIfLastMandatoryUnit()
            if isLastMandatoryUnit || hasExpressPromotion {
                await checkIfCanTakeTest()
            }
        }
        .fullScreenCover(isPresented: $showTestView) {
            if let currentUser = authService.currentUser,
               let test = courseTest {
                MultipleChoiceTestView(
                    testId: test.id,
                    course: course,
                    pilotId: currentUser.id,
                    testName: test.testName,
                    passingScore: test.passingScore,
                    durationMinutes: test.duration ?? 60,
                    onDismiss: {
                        showTestView = false
                    }
                )
                .environmentObject(authService)
            }
        }
    }
    
    private func loadCourseTest() async {
        do {
            let tests = try await academyService.fetchCourseTests(courseId: course.id)
            courseTest = tests.first { $0.testType == "multiple_choice" }
            print("✅ [UnitDetailView] Loaded course test: \(courseTest?.testName ?? "none")")
        } catch {
            print("Error loading course test: \(error)")
        }
    }
    
    /// Determines if this unit is the last mandatory unit before a test
    /// by checking if this unit is the highest numbered required unit for the test
    private func checkIfLastMandatoryUnit() async {
        guard let test = courseTest else {
            isLastMandatoryUnit = false
            return
        }
        
        // Get the required units from the test (fetched from backend)
        let requiredUnitIds = test.requiredUnits

        if requiredUnitIds.isEmpty {
            // If no required units specified, this unit cannot trigger the test button
            isLastMandatoryUnit = false
        } else {
            // Only show the test button on the last required unit (by order_index)
            do {
                let allUnits = try await academyService.fetchCourseUnits(courseId: course.id)
                let requiredCourseUnits = allUnits
                    .filter { requiredUnitIds.contains($0.id) }
                    .sorted { $0.orderIndex < $1.orderIndex }
                if let lastRequiredUnitId = requiredCourseUnits.last?.id {
                    isLastMandatoryUnit = unit.id == lastRequiredUnitId
                } else {
                    isLastMandatoryUnit = false
                }
            } catch {
                print("Error fetching course units for last mandatory check: \(error)")
                isLastMandatoryUnit = false
            }
        }

        print("✅ [UnitDetailView] Is last mandatory unit: \(isLastMandatoryUnit) (unit \(unit.unitNumber), required: \(requiredUnitIds))")
    }
    
    private static let uasPilotCourseId = UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-ef1234567890")!

    private func checkExpressPromotionStatus() async {
        // Express promotion bypass only applies to the UAS Pilot course
        guard course.id == Self.uasPilotCourseId else { return }
        guard !DemoModeManager.shared.isDemoModeEnabled else { return }
        guard let currentUser = authService.currentUser else { return }
        let expressPromotionService = ExpressPromotionService()
        hasExpressPromotion = await expressPromotionService.hasLieutenantPromotion(pilotId: currentUser.id)
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

            // Update course progress
            await academyService.updateCourseProgress(pilotId: currentUser.id, courseId: course.id)

            // Hide success message after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showCompletionSuccess = false

            // If this is the last mandatory unit or express promoted, check if can take test
            if isLastMandatoryUnit || hasExpressPromotion {
                await checkIfCanTakeTest()
            }
        } catch {
            print("Error marking unit complete: \(error)")
        }
    }
    
    private func checkIfCanTakeTest() async {
        guard let currentUser = authService.currentUser else { return }
        guard let test = courseTest else {
            canTakeTest = false
            return
        }

        do {
            // Express promotion bypass: if pilot has verified lieutenant promotion,
            // they can take the ground school test without completing prerequisite units
            if hasExpressPromotion {
                canTakeTest = true
                print("✅ [UnitDetailView] Express promotion bypass - can take test")
                return
            }

            let supabase = SupabaseClient.shared.client

            // Get the required units from the test (fetched from backend)
            let requiredUnitIds = test.requiredUnits

            if requiredUnitIds.isEmpty {
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
                // Check if all required units (by UUID) are completed (fetched from backend)
                let completedUnitIds = await academyService.checkUnitCompletionsByUUID(
                    pilotId: currentUser.id,
                    courseId: course.id,
                    unitIds: requiredUnitIds
                )

                // Check if all required units are in the completed set
                canTakeTest = requiredUnitIds.allSatisfy { completedUnitIds.contains($0) }
            }

            print("✅ [UnitDetailView] Can take test: \(canTakeTest)")
        } catch {
            print("Error checking if can take test: \(error)")
        }
    }
    
    // Helper function to get material name - now handled by CourseMaterial struct
    // This function is kept for potential future use but materials are now self-contained
}

struct MaterialButtonContent: View {
    let material: CourseMaterial

    var body: some View {
        HStack {
            Image(systemName: material.iconName)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(material.name)
                    .font(.headline)
                Text(material.type.uppercased())
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
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

// MARK: - Material Selection Wrapper

private struct MaterialSelection: Identifiable {
    let id = UUID()
    let material: CourseMaterial
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
