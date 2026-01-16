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
        isLoading = true
        errorMessage = nil
        
        do {
            let response: [TrainingCourseResponse] = try await supabase
                .from("training_courses")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            // Convert to TrainingCourse models
            courses = response.map { courseResponse in
                TrainingCourse(
                    id: courseResponse.id,
                    title: courseResponse.title,
                    description: courseResponse.description,
                    duration: courseResponse.duration,
                    level: TrainingCourse.CourseLevel(rawValue: courseResponse.level) ?? .beginner,
                    category: TrainingCourse.CourseCategory(rawValue: courseResponse.category) ?? .mandatory,
                    instructor: courseResponse.instructor,
                    instructorPictureUrl: courseResponse.instructorPictureUrl,
                    rating: courseResponse.rating,
                    studentsCount: courseResponse.studentsCount,
                    isEnrolled: false,
                    provider: TrainingCourse.CourseProvider(rawValue: courseResponse.provider ?? "Buzz") ?? .buzz,
                    badgeId: nil,
                    isRecurrent: false,
                    recurrentDueDate: nil,
                    requiresUasGroundSchool: courseResponse.requiresUasGroundSchool ?? false,
                    requiresFlightReviewPassed: courseResponse.requiresFlightReviewPassed ?? false,
                    requiresRocAPassed: courseResponse.requiresRocAPassed ?? false
                )
            }
            
            isLoading = false
        } catch {
            isLoading = false
            // Check if error is a cancellation (user refreshed while loading)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                // Request was cancelled - don't set error message or throw
                print("Course fetch cancelled (likely due to refresh)")
                return // Exit silently, don't throw error
            }
            errorMessage = error.localizedDescription
            print("Error fetching courses: \(error)")
            throw error
        }
    }
    
    // MARK: - Fetch Courses with Enrollment Status
    
    func fetchCoursesWithEnrollment(pilotId: UUID) async throws {
        let startTime = Date()
        print("📊 [AcademyService] Starting fetchCoursesWithEnrollment for pilot: \(pilotId)")
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch all courses
            print("🔍 [AcademyService] Step 1: Fetching all courses...")
            let step1Start = Date()
            let coursesResponse: [TrainingCourseResponse] = try await supabase
                .from("training_courses")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            let step1Duration = Date().timeIntervalSince(step1Start)
            print("✅ [AcademyService] Step 1 complete: Fetched \(coursesResponse.count) courses in \(String(format: "%.2f", step1Duration))s")
            
            // Fetch enrollments for this pilot
            print("🔍 [AcademyService] Step 2: Fetching enrollments...")
            let step2Start = Date()
            let enrollmentsResponse = try await supabase
                .from("course_enrollments")
                .select("course_id, completed_at")
                .eq("pilot_id", value: pilotId.uuidString)
                .execute()
            
            let enrollmentsData = try JSONDecoder().decode([CourseEnrollmentResponse].self, from: enrollmentsResponse.data)
            let step2Duration = Date().timeIntervalSince(step2Start)
            print("✅ [AcademyService] Step 2 complete: Fetched \(enrollmentsData.count) enrollments in \(String(format: "%.2f", step2Duration))s")
            
            // Process data
            print("🔄 [AcademyService] Step 3: Processing course data...")
            let step3Start = Date()
            let enrolledCourseIds = Set(enrollmentsData.map { $0.courseId })
            
            // Convert to TrainingCourse models with enrollment status
            courses = coursesResponse.map { courseResponse in
                let isEnrolled = enrolledCourseIds.contains(courseResponse.id)
                return TrainingCourse(
                    id: courseResponse.id,
                    title: courseResponse.title,
                    description: courseResponse.description,
                    duration: courseResponse.duration,
                    level: TrainingCourse.CourseLevel(rawValue: courseResponse.level) ?? .beginner,
                    category: TrainingCourse.CourseCategory(rawValue: courseResponse.category) ?? .mandatory,
                    instructor: courseResponse.instructor,
                    instructorPictureUrl: courseResponse.instructorPictureUrl,
                    rating: courseResponse.rating,
                    studentsCount: courseResponse.studentsCount,
                    isEnrolled: isEnrolled,
                    provider: TrainingCourse.CourseProvider(rawValue: courseResponse.provider ?? "Buzz") ?? .buzz,
                    badgeId: nil,
                    isRecurrent: false,
                    recurrentDueDate: nil,
                    requiresUasGroundSchool: courseResponse.requiresUasGroundSchool ?? false,
                    requiresFlightReviewPassed: courseResponse.requiresFlightReviewPassed ?? false,
                    requiresRocAPassed: courseResponse.requiresRocAPassed ?? false
                )
            }
            let step3Duration = Date().timeIntervalSince(step3Start)
            print("✅ [AcademyService] Step 3 complete: Processed data in \(String(format: "%.2f", step3Duration))s")
            
            let totalDuration = Date().timeIntervalSince(startTime)
            print("🎉 [AcademyService] fetchCoursesWithEnrollment completed successfully in \(String(format: "%.2f", totalDuration))s")
            
            isLoading = false
        } catch {
            isLoading = false
            let duration = Date().timeIntervalSince(startTime)
            // Check if error is a cancellation (user refreshed while loading)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                // Request was cancelled - don't set error message or throw
                print("❌ [AcademyService] fetchCoursesWithEnrollment cancelled after \(String(format: "%.2f", duration))s")
                return // Exit silently, don't throw error
            }
            errorMessage = error.localizedDescription
            print("❌ [AcademyService] fetchCoursesWithEnrollment failed after \(String(format: "%.2f", duration))s: \(error)")
            throw error
        }
    }
    
    // MARK: - Fetch Course Sections
    
    func fetchCourseSections(courseId: UUID) async throws -> [CourseSection] {
        do {
            let response: [CourseSection] = try await supabase
                .from("course_sections")
                .select()
                .eq("course_id", value: courseId.uuidString)
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value
            
            print("✅ [AcademyService] Fetched \(response.count) sections for course")
            return response
        } catch {
            print("Error fetching course sections: \(error)")
            throw error
        }
    }
    
    // MARK: - Fetch Course Units
    
    func fetchCourseUnits(courseId: UUID) async throws -> [CourseUnit] {
        do {
            let response: [CourseUnit] = try await supabase
                .from("course_units")
                .select()
                .eq("course_id", value: courseId.uuidString)
                .order("order_index", ascending: true)
                .execute()
                .value
            
            return response
        } catch {
            print("Error fetching course units: \(error)")
            throw error
        }
    }
    
    // MARK: - Fetch Units for Section
    
    func fetchUnitsForSection(sectionId: UUID) async throws -> [CourseUnit] {
        do {
            let response: [CourseUnit] = try await supabase
                .from("course_units")
                .select()
                .eq("section_id", value: sectionId.uuidString)
                .order("order_index", ascending: true)
                .execute()
                .value
            
            return response
        } catch {
            print("Error fetching units for section: \(error)")
            throw error
        }
    }
    
    // MARK: - Check Ground School Test Status
    
    func checkGroundSchoolTestStatus(pilotId: UUID, courseId: UUID) async throws -> Bool {
        print("🔍 [AcademyService] Checking ground school test status for pilot: \(pilotId)")
        
        do {
            // Check test_results table for passed ground school test
            let response = try await supabase
                .from("test_results")
                .select("passed")
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("course_id", value: courseId.uuidString)
                .execute()
            
            let data = response.data
            
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                print("⚠️ [AcademyService] No test results found")
                return false
            }
            
            guard let firstResult = jsonArray.first,
                  let passed = firstResult["passed"] as? Bool else {
                print("⚠️ [AcademyService] No test record found or invalid format")
                return false
            }
            
            print("✅ [AcademyService] Ground school test status: \(passed ? "PASSED" : "NOT PASSED")")
            return passed
        } catch {
            print("❌ [AcademyService] Error checking ground school test status: \(error)")
            return false
        }
    }
    
    // MARK: - Check Flight Review Test Status
    
    /// Check if pilot has passed the Flight Review test
    /// - Parameter pilotId: The pilot's UUID
    /// - Returns: true if the pilot has passed the Flight Review test
    func checkFlightReviewTestStatus(pilotId: UUID) async throws -> Bool {
        let flightReviewCourseId = UUID(uuidString: "b2c3d4e5-f6a7-8901-bcde-f23456789012")!
        print("🔍 [AcademyService] Checking Flight Review test status for pilot: \(pilotId)")
        
        do {
            let response = try await supabase
                .from("test_results")
                .select("passed")
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("course_id", value: flightReviewCourseId.uuidString)
                .eq("passed", value: true)
                .execute()
            
            let data = response.data
            
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                print("⚠️ [AcademyService] No Flight Review test results found")
                return false
            }
            
            let hasPassed = !jsonArray.isEmpty
            print("✅ [AcademyService] Flight Review test status: \(hasPassed ? "PASSED" : "NOT PASSED")")
            return hasPassed
        } catch {
            print("❌ [AcademyService] Error checking Flight Review test status: \(error)")
            return false
        }
    }
    
    // MARK: - Check ROC-A Test Status
    
    /// Check if pilot has passed the ROC-A test
    /// - Parameter pilotId: The pilot's UUID
    /// - Returns: true if the pilot has passed the ROC-A test
    func checkRocATestStatus(pilotId: UUID) async throws -> Bool {
        let rocACourseId = UUID(uuidString: "c3d4e5f6-a7b8-9012-cdef-345678901234")!
        print("🔍 [AcademyService] Checking ROC-A test status for pilot: \(pilotId)")
        
        do {
            let response = try await supabase
                .from("test_results")
                .select("passed")
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("course_id", value: rocACourseId.uuidString)
                .eq("passed", value: true)
                .execute()
            
            let data = response.data
            
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                print("⚠️ [AcademyService] No ROC-A test results found")
                return false
            }
            
            let hasPassed = !jsonArray.isEmpty
            print("✅ [AcademyService] ROC-A test status: \(hasPassed ? "PASSED" : "NOT PASSED")")
            return hasPassed
        } catch {
            print("❌ [AcademyService] Error checking ROC-A test status: \(error)")
            return false
        }
    }
    
    // MARK: - Check All Prerequisites Status
    
    /// Check all prerequisite test statuses for a pilot
    /// - Parameter pilotId: The pilot's UUID
    /// - Returns: A tuple containing the status of all three prerequisites
    func checkAllPrerequisites(pilotId: UUID) async -> (groundSchool: Bool, flightReview: Bool, rocA: Bool) {
        let uasPilotCourseId = UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-ef1234567890")!
        
        async let groundSchoolStatus = (try? checkGroundSchoolTestStatus(pilotId: pilotId, courseId: uasPilotCourseId)) ?? false
        async let flightReviewStatus = (try? checkFlightReviewTestStatus(pilotId: pilotId)) ?? false
        async let rocAStatus = (try? checkRocATestStatus(pilotId: pilotId)) ?? false
        
        let results = await (groundSchoolStatus, flightReviewStatus, rocAStatus)
        print("📋 [AcademyService] All prerequisites - Ground School: \(results.0), Flight Review: \(results.1), ROC-A: \(results.2)")
        return results
    }
    
    // MARK: - Fetch Course Tests
    
    func fetchCourseTests(courseId: UUID) async throws -> [CourseTest] {
        do {
            let response: [CourseTest] = try await supabase
                .from("course_tests")
                .select()
                .eq("course_id", value: courseId.uuidString)
                .eq("is_active", value: true)
                .order("order_index", ascending: true)
                .execute()
                .value
            
            return response
        } catch {
            print("Error fetching course tests: \(error)")
            throw error
        }
    }
    
    // MARK: - Check Test Status by Test ID
    
    func checkTestStatus(pilotId: UUID, testId: UUID) async throws -> Bool {
        do {
            let response = try await supabase
                .from("test_results")
                .select("passed")
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("test_id", value: testId.uuidString)
                .execute()
            
            let data = response.data
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let firstResult = jsonArray.first,
                  let passed = firstResult["passed"] as? Bool else {
                return false
            }
            
            return passed
        } catch {
            print("Error checking test status: \(error)")
            return false
        }
    }
    
    // MARK: - Enroll in Course
    
    func enrollInCourse(pilotId: UUID, courseId: UUID) async throws {
        // Check all prerequisite requirements for the course
        if let course = courses.first(where: { $0.id == courseId }) {
            var missingPrerequisites: [String] = []
            
            // Check Ground School prerequisite
            if course.requiresUasGroundSchool {
                let uasPilotCourseId = UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-ef1234567890")!
                let hasPassedGroundSchool = try await checkGroundSchoolTestStatus(
                    pilotId: pilotId,
                    courseId: uasPilotCourseId
                )
                if !hasPassedGroundSchool {
                    missingPrerequisites.append("UAS Pilot Ground School Test")
                }
            }
            
            // Check Flight Review prerequisite
            if course.requiresFlightReviewPassed {
                let hasPassedFlightReview = try await checkFlightReviewTestStatus(pilotId: pilotId)
                if !hasPassedFlightReview {
                    missingPrerequisites.append("Flight Review Test")
                }
            }
            
            // Check ROC-A prerequisite
            if course.requiresRocAPassed {
                let hasPassedRocA = try await checkRocATestStatus(pilotId: pilotId)
                if !hasPassedRocA {
                    missingPrerequisites.append("ROC-A Test")
                }
            }
            
            // If any prerequisites are missing, throw an error
            if !missingPrerequisites.isEmpty {
                let prerequisiteList = missingPrerequisites.joined(separator: ", ")
                throw NSError(
                    domain: "AcademyService",
                    code: 403,
                    userInfo: [
                        NSLocalizedDescriptionKey: "You must pass the following before enrolling: \(prerequisiteList)"
                    ]
                )
            }
        }
        
        do {
            let enrollment: [String: AnyJSON] = [
                "pilot_id": .string(pilotId.uuidString),
                "course_id": .string(courseId.uuidString)
            ]
            
            try await supabase
                .from("course_enrollments")
                .insert(enrollment)
                .execute()
            
            // Refresh courses to get updated students_count
            try await fetchCoursesWithEnrollment(pilotId: pilotId)
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
                let category = TrainingCourse.CourseCategory(rawValue: categoryString) ?? .mandatory
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
                    recurrentDueDate: nil,
                    requiresUasGroundSchool: courseJson["requires_uas_ground_school"] as? Bool ?? false,
                    requiresFlightReviewPassed: courseJson["requires_flight_review_passed"] as? Bool ?? false,
                    requiresRocAPassed: courseJson["requires_roc_a_passed"] as? Bool ?? false
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
    
    // MARK: - Fetch Completed Units for Pilot
    
    func fetchCompletedUnits(pilotId: UUID) async throws -> [CompletedUnit] {
        do {
            // Fetch unit completions with unit details for this pilot
            // Filter for unit_number >= 4
            let response = try await supabase
                .from("unit_completions")
                .select("*, course_units!inner(unit_number, title)")
                .eq("pilot_id", value: pilotId.uuidString)
                .gte("course_units.unit_number", value: 4)
                .order("completed_at", ascending: false)
                .execute()
            
            // Parse the response
            let data = response.data
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                print("❌ [AcademyService] Failed to parse completed units response")
                return []
            }
            
            var completedUnits: [CompletedUnit] = []
            
            for unitJson in jsonArray {
                guard let idString = unitJson["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let pilotIdString = unitJson["pilot_id"] as? String,
                      let pilotId = UUID(uuidString: pilotIdString),
                      let unitIdString = unitJson["unit_id"] as? String,
                      let unitId = UUID(uuidString: unitIdString),
                      let courseIdString = unitJson["course_id"] as? String,
                      let courseId = UUID(uuidString: courseIdString),
                      let completedAtString = unitJson["completed_at"] as? String,
                      let courseUnitsJson = unitJson["course_units"] as? [String: Any],
                      let unitNumber = courseUnitsJson["unit_number"] as? Int,
                      let unitTitle = courseUnitsJson["title"] as? String else {
                    continue
                }
                
                // Parse the completedAt date
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                guard let completedAt = formatter.date(from: completedAtString) else {
                    print("⚠️ [AcademyService] Failed to parse date: \(completedAtString)")
                    continue
                }
                
                let completedUnit = CompletedUnit(
                    id: id,
                    pilotId: pilotId,
                    unitId: unitId,
                    courseId: courseId,
                    unitNumber: unitNumber,
                    unitTitle: unitTitle,
                    completedAt: completedAt
                )
                
                completedUnits.append(completedUnit)
            }
            
            print("✅ [AcademyService] Loaded \(completedUnits.count) completed units")
            return completedUnits
        } catch {
            print("❌ [AcademyService] Error loading completed units: \(error)")
            throw error
        }
    }
}

// MARK: - Response Models

struct TrainingCourseResponse: Codable {
    let id: UUID
    let title: String
    let description: String
    let duration: String
    let level: String
    let category: String
    let instructor: String
    let instructorPictureUrl: String?
    let rating: Double
    let studentsCount: Int
    let provider: String?
    let requiresUasGroundSchool: Bool?
    let requiresFlightReviewPassed: Bool?
    let requiresRocAPassed: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case duration
        case level
        case category
        case instructor
        case instructorPictureUrl = "instructor_picture_url"
        case rating
        case studentsCount = "students_count"
        case provider
        case requiresUasGroundSchool = "requires_uas_ground_school"
        case requiresFlightReviewPassed = "requires_flight_review_passed"
        case requiresRocAPassed = "requires_roc_a_passed"
    }
}

struct CourseEnrollmentResponse: Codable {
    let courseId: UUID
    let completedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case courseId = "course_id"
        case completedAt = "completed_at"
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

