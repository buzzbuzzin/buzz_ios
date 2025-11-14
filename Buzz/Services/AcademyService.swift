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
    
    // MARK: - Fetch Completed Courses for Pilot
    
    func fetchCompletedCourses(pilotId: UUID) async throws -> [TrainingCourse] {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch enrollments with course details for this pilot
            let response = try await supabase
                .from("course_enrollments")
                .select("*, training_courses(*)")
                .eq("pilot_id", value: pilotId.uuidString)
                .execute()
            
            // Parse the response
            // Since the structure might be nested, we'll decode manually
            let data = response.data
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                isLoading = false
                return []
            }
            
            var completedCourses: [TrainingCourse] = []
            
            for enrollmentJson in jsonArray {
                // Only include courses that have been completed (completed_at is not null)
                guard let completedAt = enrollmentJson["completed_at"] as? String,
                      !completedAt.isEmpty,
                      let courseJson = enrollmentJson["training_courses"] as? [String: Any],
                      let courseIdString = courseJson["id"] as? String,
                      let courseId = UUID(uuidString: courseIdString),
                      let title = courseJson["title"] as? String else {
                    continue
                }
                
                // Extract course details with defaults
                let description = courseJson["description"] as? String ?? ""
                let duration = courseJson["duration"] as? String ?? "N/A"
                let levelString = courseJson["level"] as? String ?? "Beginner"
                let categoryString = courseJson["category"] as? String ?? "Safety & Regulations"
                let instructor = courseJson["instructor"] as? String ?? "Buzz Academy"
                let instructorPictureUrl = courseJson["instructor_picture_url"] as? String
                let rating = (courseJson["rating"] as? Double) ?? 0.0
                let studentsCount = (courseJson["students_count"] as? Int) ?? 0
                let providerString = courseJson["provider"] as? String ?? "Buzz"
                
                let level = TrainingCourse.CourseLevel(rawValue: levelString) ?? .beginner
                let category = TrainingCourse.CourseCategory(rawValue: categoryString) ?? .safety
                let provider = TrainingCourse.CourseProvider(rawValue: providerString) ?? .buzz
                
                let course = TrainingCourse(
                    id: courseId,
                    title: title,
                    description: description,
                    duration: duration,
                    level: level,
                    category: category,
                    instructor: instructor,
                    instructorPictureUrl: instructorPictureUrl,
                    rating: rating,
                    studentsCount: studentsCount,
                    isEnrolled: true,
                    provider: provider,
                    badgeId: nil,
                    isRecurrent: courseJson["is_recurrent"] as? Bool ?? false,
                    recurrentDueDate: nil
                )
                
                completedCourses.append(course)
            }
            
            isLoading = false
            return completedCourses
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            // Return empty array on error (courses might not be fully implemented yet)
            return []
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

