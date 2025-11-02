//
//  AcademyService.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import Supabase
import Combine

@MainActor
class AcademyService: ObservableObject {
    @Published var courses: [TrainingCourse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    
    // MARK: - Fetch All Courses
    
    func fetchCourses() async throws {
        // TODO: This method is not yet implemented - courses are currently hardcoded in AcademyView
        // When ready, implement Supabase query here
        isLoading = true
        errorMessage = nil
        
        // Placeholder - will be implemented when backend is ready
        isLoading = false
    }
    
    // MARK: - Fetch Courses with Enrollment Status
    
    func fetchCoursesWithEnrollment(pilotId: UUID) async throws {
        // TODO: This method is not yet implemented - courses are currently hardcoded in AcademyView
        // When ready, implement Supabase query here
        isLoading = true
        errorMessage = nil
        
        // Placeholder - will be implemented when backend is ready
        isLoading = false
    }
    
    // MARK: - Enroll in Course
    
    func enrollInCourse(pilotId: UUID, courseId: UUID) async throws {
        do {
            let enrollment: [String: AnyJSON] = [
                "id": .string(UUID().uuidString),
                "pilot_id": .string(pilotId.uuidString),
                "course_id": .string(courseId.uuidString),
                "enrolled_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            
            try await supabase
                .from("course_enrollments")
                .insert(enrollment)
                .execute()
            
            // Update local state
            if let index = courses.firstIndex(where: { $0.id == courseId }) {
                courses[index].isEnrolled = true
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Unenroll from Course
    
    func unenrollFromCourse(pilotId: UUID, courseId: UUID) async throws {
        do {
            try await supabase
                .from("course_enrollments")
                .delete()
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("course_id", value: courseId.uuidString)
                .execute()
            
            // Update local state
            if let index = courses.firstIndex(where: { $0.id == courseId }) {
                courses[index].isEnrolled = false
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

// MARK: - Course Enrollment Model

struct CourseEnrollment: Codable, Identifiable {
    let id: UUID
    let pilotId: UUID
    let courseId: UUID
    let enrolledAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case courseId = "course_id"
        case enrolledAt = "enrolled_at"
    }
}

