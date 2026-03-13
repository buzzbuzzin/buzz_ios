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

    private func makeCourse(
        from courseResponse: TrainingCourseResponse,
        isEnrolled: Bool,
        sectionSnapshots: [CourseSectionAccessSnapshot]
    ) -> TrainingCourse {
        TrainingCourse(
            id: courseResponse.id,
            title: courseResponse.title,
            description: courseResponse.description,
            duration: courseResponse.duration,
            level: TrainingCourse.CourseLevel(rawValue: courseResponse.level) ?? .beginner,
            category: TrainingCourse.CourseCategory(rawValue: courseResponse.category) ?? .general,
            instructor: courseResponse.instructor,
            instructorPictureUrl: courseResponse.instructorPictureUrl,
            rating: courseResponse.rating,
            studentsCount: courseResponse.studentsCount,
            isEnrolled: isEnrolled,
            provider: TrainingCourse.CourseProvider(rawValue: courseResponse.provider ?? "Buzz") ?? .buzz,
            requiresUasGroundSchool: courseResponse.requiresUasGroundSchool ?? false,
            requiresFlightReviewPassed: courseResponse.requiresFlightReviewPassed ?? false,
            requiresRocAPassed: courseResponse.requiresRocAPassed ?? false,
            externalUrl: courseResponse.externalUrl,
            coverImageUrl: courseResponse.coverImageUrl,
            region: TrainingCourse.CourseRegion(rawValue: courseResponse.region ?? "Global") ?? .global,
            active: courseResponse.active ?? false,
            requiresSubscriptionToEnroll: AcademyCourseAccessPolicy.requiresSubscriptionToEnroll(
                courseTitle: courseResponse.title,
                provider: courseResponse.provider,
                externalUrl: courseResponse.externalUrl,
                sectionSnapshots: sectionSnapshots
            )
        )
    }

    private func fetchSectionSnapshots(courseIds: [UUID]) async throws -> [CourseSectionAccessSnapshot] {
        guard !courseIds.isEmpty else {
            return []
        }

        return try await supabase
            .from("course_sections")
            .select("course_id, name, exam_type, requires_subscription")
            .in("course_id", values: courseIds.map(\.uuidString))
            .eq("is_active", value: true)
            .is("deleted_at", value: nil)
            .execute()
            .value
    }

    private func sectionSnapshotsByCourse(
        for courseIds: [UUID]
    ) async throws -> [UUID: [CourseSectionAccessSnapshot]] {
        let snapshots = try await fetchSectionSnapshots(courseIds: courseIds)
        return Dictionary(grouping: snapshots, by: \.courseId)
    }

    private func fetchCourseDefinition(courseId: UUID) async throws -> TrainingCourse {
        if let cachedCourse = courses.first(where: { $0.id == courseId }) {
            return cachedCourse
        }

        let response: TrainingCourseResponse = try await supabase
            .from("training_courses")
            .select()
            .eq("id", value: courseId.uuidString)
            .eq("active", value: true)
            .single()
            .execute()
            .value

        let sectionSnapshots = try await fetchSectionSnapshots(courseIds: [response.id])
        return makeCourse(from: response, isEnrolled: false, sectionSnapshots: sectionSnapshots)
    }
    
    // MARK: - Fetch All Courses
    
    func fetchCourses() async throws {
        if DemoModeManager.shared.isDemoModeEnabled {
            return
        }

        isLoading = true
        errorMessage = nil
        
        do {
            let response: [TrainingCourseResponse] = try await supabase
                .from("training_courses")
                .select()
                .eq("active", value: true) // Only fetch active courses
                .order("created_at", ascending: false)
                .execute()
                .value

            let snapshotsByCourse = try await sectionSnapshotsByCourse(for: response.map(\.id))
            
            // Convert to TrainingCourse models
            courses = response.map { courseResponse in
                makeCourse(
                    from: courseResponse,
                    isEnrolled: false,
                    sectionSnapshots: snapshotsByCourse[courseResponse.id] ?? []
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
                .eq("active", value: true) // Only fetch active courses
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

            let snapshotsByCourse = try await sectionSnapshotsByCourse(for: coursesResponse.map(\.id))
            
            // Process data
            print("🔄 [AcademyService] Step 3: Processing course data...")
            let step3Start = Date()
            let enrolledCourseIds = Set(enrollmentsData.map { $0.courseId })
            
            // Convert to TrainingCourse models with enrollment status
            courses = coursesResponse.map { courseResponse in
                makeCourse(
                    from: courseResponse,
                    isEnrolled: enrolledCourseIds.contains(courseResponse.id),
                    sectionSnapshots: snapshotsByCourse[courseResponse.id] ?? []
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
        if DemoModeManager.shared.isDemoModeEnabled {
            return []
        }

        do {
            let response: [CourseSection] = try await supabase
                .from("course_sections")
                .select()
                .eq("course_id", value: courseId.uuidString)
                .eq("is_active", value: true)
                .is("deleted_at", value: nil)
                .order("display_order", ascending: true)
                .execute()
                .value
            
            print("✅ [AcademyService] Fetched \(response.count) active sections for course")
            return response
        } catch {
            print("Error fetching course sections: \(error)")
            throw error
        }
    }
    
    // MARK: - Fetch Course Units
    
    func fetchCourseUnits(courseId: UUID) async throws -> [CourseUnit] {
        if DemoModeManager.shared.isDemoModeEnabled {
            return []
        }

        do {
            let response: [CourseUnit] = try await supabase
                .from("course_units")
                .select()
                .eq("course_id", value: courseId.uuidString)
                .is("deleted_at", value: nil)
                .order("order_index", ascending: true)
                .execute()
                .value
            
            print("✅ [AcademyService] Fetched \(response.count) units for course")
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
                .is("deleted_at", value: nil)
                .order("order_index", ascending: true)
                .execute()
                .value
            
            return response
        } catch {
            print("Error fetching units for section: \(error)")
            throw error
        }
    }
    
    // MARK: - Check Ground School Test Status (via RPC)
    
    /// Check if pilot has passed the Ground School test using backend RPC function
    /// - Parameter pilotId: The pilot's UUID
    /// - Returns: true if the pilot has passed the Ground School test
    func checkGroundSchoolTestStatus(pilotId: UUID) async throws -> Bool {
        if DemoModeManager.shared.isDemoModeEnabled {
            return false
        }

        print("🔍 [AcademyService] Checking Ground School test status via RPC for pilot: \(pilotId)")
        
        do {
            let response = try await supabase
                .rpc("has_passed_ground_school_test", params: ["p_pilot_id": pilotId.uuidString])
                .execute()
            
            let hasPassed = try JSONDecoder().decode(Bool.self, from: response.data)
            print("✅ [AcademyService] Ground School test status (RPC): \(hasPassed ? "PASSED" : "NOT PASSED")")
            return hasPassed
        } catch {
            print("❌ [AcademyService] Error checking Ground School test status via RPC: \(error)")
            return false
        }
    }
    
    // MARK: - Check Flight Review Test Status (via RPC)
    
    /// Check if pilot has passed the Flight Review test using backend RPC function
    /// - Parameter pilotId: The pilot's UUID
    /// - Returns: true if the pilot has passed the Flight Review test
    func checkFlightReviewTestStatus(pilotId: UUID) async throws -> Bool {
        if DemoModeManager.shared.isDemoModeEnabled {
            return false
        }

        print("🔍 [AcademyService] Checking Flight Review test status via RPC for pilot: \(pilotId)")
        
        do {
            let response = try await supabase
                .rpc("has_passed_flight_review", params: ["p_pilot_id": pilotId.uuidString])
                .execute()
            
            let hasPassed = try JSONDecoder().decode(Bool.self, from: response.data)
            print("✅ [AcademyService] Flight Review test status (RPC): \(hasPassed ? "PASSED" : "NOT PASSED")")
            return hasPassed
        } catch {
            print("❌ [AcademyService] Error checking Flight Review test status via RPC: \(error)")
            return false
        }
    }
    
    // MARK: - Check ROC-A Test Status (via RPC)
    
    /// Check if pilot has passed the ROC-A test using backend RPC function
    /// - Parameter pilotId: The pilot's UUID
    /// - Returns: true if the pilot has passed the ROC-A test
    func checkRocATestStatus(pilotId: UUID) async throws -> Bool {
        if DemoModeManager.shared.isDemoModeEnabled {
            return false
        }

        print("🔍 [AcademyService] Checking ROC-A test status via RPC for pilot: \(pilotId)")
        
        do {
            let response = try await supabase
                .rpc("has_passed_roc_a", params: ["p_pilot_id": pilotId.uuidString])
                .execute()
            
            let hasPassed = try JSONDecoder().decode(Bool.self, from: response.data)
            print("✅ [AcademyService] ROC-A test status (RPC): \(hasPassed ? "PASSED" : "NOT PASSED")")
            return hasPassed
        } catch {
            print("❌ [AcademyService] Error checking ROC-A test status via RPC: \(error)")
            return false
        }
    }
    
    // MARK: - Check All Prerequisites Status (via RPC)
    
    /// Check all prerequisite test statuses for a pilot using backend RPC functions
    /// - Parameter pilotId: The pilot's UUID
    /// - Returns: A tuple containing the status of all three prerequisites
    func checkAllPrerequisites(pilotId: UUID) async -> (groundSchool: Bool, flightReview: Bool, rocA: Bool) {
        // Call all RPC functions in parallel
        async let groundSchoolStatus = (try? checkGroundSchoolTestStatus(pilotId: pilotId)) ?? false
        async let flightReviewStatus = (try? checkFlightReviewTestStatus(pilotId: pilotId)) ?? false
        async let rocAStatus = (try? checkRocATestStatus(pilotId: pilotId)) ?? false
        
        let (groundSchool, flightReview, rocA) = await (groundSchoolStatus, flightReviewStatus, rocAStatus)
        print("📋 [AcademyService] All prerequisites (RPC) - Ground School: \(groundSchool), Flight Review: \(flightReview), ROC-A: \(rocA)")
        return (groundSchool, flightReview, rocA)
    }
    
    // MARK: - Fetch Course Tests
    
    func fetchCourseTests(courseId: UUID) async throws -> [CourseTest] {
        if DemoModeManager.shared.isDemoModeEnabled {
            return []
        }

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
    
    /// Fetch all active tests across all courses (for Test Center)
    func fetchAllActiveTests() async throws -> [CourseTest] {
        do {
            let response: [CourseTest] = try await supabase
                .from("course_tests")
                .select()
                .eq("is_active", value: true)
                .order("order_index", ascending: true)
                .execute()
                .value
            
            print("✅ [AcademyService] Fetched \(response.count) active tests across all courses")
            return response
        } catch {
            print("❌ [AcademyService] Error fetching all active tests: \(error)")
            throw error
        }
    }
    
    /// Fetch active tests only from courses the pilot is enrolled in
    func fetchTestsForEnrolledCourses(pilotId: UUID) async throws -> [CourseTest] {
        if DemoModeManager.shared.isDemoModeEnabled {
            return []
        }

        do {
            // First, fetch the pilot's course enrollments for active courses
            let enrollmentsResponse = try await supabase
                .from("course_enrollments")
                .select("course_id, training_courses!inner(active)")
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("training_courses.active", value: true)
                .execute()
            
            let enrollmentsData = try JSONDecoder().decode([CourseEnrollmentResponse].self, from: enrollmentsResponse.data)
            let enrolledCourseIds = enrollmentsData.map { $0.courseId.uuidString }
            
            print("📚 [AcademyService] Pilot is enrolled in \(enrolledCourseIds.count) active courses")
            
            // If no enrollments, return empty array
            guard !enrolledCourseIds.isEmpty else {
                print("⚠️ [AcademyService] No course enrollments found for active courses")
                return []
            }
            
            // Fetch tests for enrolled courses only (test must also be active)
            let response: [CourseTest] = try await supabase
                .from("course_tests")
                .select()
                .eq("is_active", value: true)
                .in("course_id", values: enrolledCourseIds)
                .order("order_index", ascending: true)
                .execute()
                .value
            
            print("✅ [AcademyService] Fetched \(response.count) active tests from active enrolled courses")
            return response
        } catch {
            print("❌ [AcademyService] Error fetching tests for enrolled courses: \(error)")
            throw error
        }
    }
    
    // MARK: - Fetch Test Questions
    
    /// Fetch questions for a specific test from the test_questions table
    /// If the test uses problem sets, randomly selects one set for the student
    /// - Parameter testId: The UUID of the test
    /// - Returns: Array of TestQuestion objects ordered by question_number
    func fetchTestQuestions(testId: UUID) async throws -> [TestQuestion] {
        print("🔍 [AcademyService] Fetching questions for test: \(testId)")
        
        do {
            let response: [TestQuestion] = try await supabase
                .from("test_questions")
                .select()
                .eq("test_id", value: testId.uuidString)
                .order("question_number", ascending: true)
                .execute()
                .value
            
            print("✅ [AcademyService] Successfully fetched \(response.count) questions for test: \(testId)")
            
            // Check if this test uses problem sets
            let filteredQuestions = filterQuestionsByProblemSet(questions: response)
            
            if filteredQuestions.count < response.count {
                print("📋 [AcademyService] Problem set filtering applied: \(filteredQuestions.count) of \(response.count) questions selected")
            }
            
            return filteredQuestions
        } catch {
            print("❌ [AcademyService] Error fetching test questions: \(error)")
            throw error
        }
    }
    
    /// Filter questions by problem set if applicable
    /// If any question has problem sets assigned, randomly select one set
    /// - Parameter questions: All questions from the test
    /// - Returns: Filtered questions (or all questions if no problem sets)
    private func filterQuestionsByProblemSet(questions: [TestQuestion]) -> [TestQuestion] {
        // Check if any question has problem sets
        let questionsWithProblemSets = questions.filter { question in
            if let sets = question.problemSets, !sets.isEmpty {
                return true
            }
            return false
        }
        
        // If no questions have problem sets, return all questions
        guard !questionsWithProblemSets.isEmpty else {
            print("ℹ️ [AcademyService] No problem sets found, returning all questions")
            return questions
        }
        
        // Find all unique problem set numbers
        var allProblemSets = Set<Int>()
        for question in questionsWithProblemSets {
            if let sets = question.problemSets {
                allProblemSets.formUnion(sets)
            }
        }
        
        // Randomly select one problem set
        guard let selectedSet = allProblemSets.randomElement() else {
            print("⚠️ [AcademyService] Could not select a random problem set, returning all questions")
            return questions
        }
        
        print("🎲 [AcademyService] Selected problem set: \(selectedSet) from available sets: \(allProblemSets.sorted())")
        
        // Filter questions: include if problemSets is nil/empty OR contains the selected set
        let filteredQuestions = questions.filter { question in
            guard let sets = question.problemSets, !sets.isEmpty else {
                // Questions without problem sets are always included
                return true
            }
            // Include if this question belongs to the selected set
            return sets.contains(selectedSet)
        }
        
        return filteredQuestions
    }
    
    // MARK: - Check Test Status by Test ID
    
    func checkTestStatus(pilotId: UUID, testId: UUID) async throws -> Bool {
        if DemoModeManager.shared.isDemoModeEnabled {
            return false
        }

        do {
            let response = try await supabase
                .from("test_results")
                .select("passed")
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("test_id", value: testId.uuidString)
                .eq("passed", value: true)
                .limit(1)
                .execute()

            let jsonArray = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] ?? []
            return !jsonArray.isEmpty
        } catch {
            print("Error checking test status: \(error)")
            return false
        }
    }
    
    // MARK: - Check Multiple Test Statuses
    
    /// Check if pilot has passed all specified tests
    /// - Parameters:
    ///   - pilotId: The pilot's UUID
    ///   - testIds: Array of test UUIDs to check
    /// - Returns: Dictionary mapping test ID to pass status
    func checkTestStatuses(pilotId: UUID, testIds: [UUID]) async -> [UUID: Bool] {
        if DemoModeManager.shared.isDemoModeEnabled {
            return [:]
        }

        var results: [UUID: Bool] = [:]
        
        // Check all tests in parallel
        await withTaskGroup(of: (UUID, Bool).self) { group in
            for testId in testIds {
                group.addTask {
                    let passed = (try? await self.checkTestStatus(pilotId: pilotId, testId: testId)) ?? false
                    return (testId, passed)
                }
            }
            
            for await (testId, passed) in group {
                results[testId] = passed
            }
        }
        
        return results
    }
    
    // MARK: - Check Unit Completion
    
    /// Check if a unit has been completed by the pilot
    /// - Parameters:
    ///   - pilotId: The pilot's UUID
    ///   - unitId: The unit's UUID
    /// - Returns: true if the unit has been completed
    func checkUnitCompletion(pilotId: UUID, unitId: UUID) async -> Bool {
        do {
            let response = try await supabase
                .from("unit_completions")
                .select("id")
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("unit_id", value: unitId.uuidString)
                .execute()
            
            let data = response.data
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return false
            }
            
            return !jsonArray.isEmpty
        } catch {
            print("Error checking unit completion: \(error)")
            return false
        }
    }
    
    // MARK: - Check Multiple Unit Completions by Unit Number

    /// Check if pilot has completed all specified units (by unit number)
    /// - Parameters:
    ///   - pilotId: The pilot's UUID
    ///   - courseId: The course UUID
    ///   - unitNumbers: Array of unit numbers to check
    /// - Returns: Set of completed unit numbers
    func checkUnitCompletionsByNumber(pilotId: UUID, courseId: UUID, unitNumbers: [Int]) async -> Set<Int> {
        do {
            let response = try await supabase
                .from("unit_completions")
                .select("*, course_units!inner(unit_number)")
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("course_id", value: courseId.uuidString)
                .execute()

            let data = response.data
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }

            var completedNumbers: Set<Int> = []
            for item in jsonArray {
                if let courseUnits = item["course_units"] as? [String: Any],
                   let unitNumber = courseUnits["unit_number"] as? Int {
                    completedNumbers.insert(unitNumber)
                }
            }

            return completedNumbers
        } catch {
            print("Error checking unit completions by number: \(error)")
            return []
        }
    }

    // MARK: - Check Multiple Unit Completions by Unit UUID

    /// Check if pilot has completed all specified units (by unit UUID)
    /// - Parameters:
    ///   - pilotId: The pilot's UUID
    ///   - courseId: The course UUID
    ///   - unitIds: Array of unit UUIDs to check
    /// - Returns: Set of completed unit UUIDs
    func checkUnitCompletionsByUUID(pilotId: UUID, courseId: UUID, unitIds: [UUID]) async -> Set<UUID> {
        do {
            let response = try await supabase
                .from("unit_completions")
                .select("unit_id")
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("course_id", value: courseId.uuidString)
                .execute()

            let data = response.data
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }

            var completedUnitIds: Set<UUID> = []
            for item in jsonArray {
                if let unitIdString = item["unit_id"] as? String,
                   let unitId = UUID(uuidString: unitIdString) {
                    completedUnitIds.insert(unitId)
                }
            }

            return completedUnitIds
        } catch {
            print("Error checking unit completions by UUID: \(error)")
            return []
        }
    }
    
    // MARK: - Enroll in Course
    
    func enrollInCourse(pilotId: UUID, courseId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled {
            return
        }

        // Check all prerequisite requirements for the course using RPC functions
        let course = try await fetchCourseDefinition(courseId: courseId)

        var missingPrerequisites: [String] = []

        // Check Ground School prerequisite via RPC
        if course.requiresUasGroundSchool {
            let hasPassedGroundSchool = try await checkGroundSchoolTestStatus(pilotId: pilotId)
            if !hasPassedGroundSchool {
                missingPrerequisites.append("UAS Pilot Ground School Test")
            }
        }

        // Check Flight Review prerequisite via RPC
        if course.requiresFlightReviewPassed {
            let hasPassedFlightReview = try await checkFlightReviewTestStatus(pilotId: pilotId)
            if !hasPassedFlightReview {
                missingPrerequisites.append("Flight Review Test")
            }
        }

        // Check ROC-A prerequisite via RPC
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

        if course.requiresSubscriptionToEnroll {
            let hasActiveSubscription = await EntitlementManager.shared.checkAllSubscriptionSources(
                pilotId: pilotId,
                appleProductIDs: ProductIdentifiers.academyPassProductIDs
            )

            if !hasActiveSubscription {
                throw NSError(
                    domain: "AcademyService",
                    code: 402,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Buzz Academy Pass is required before enrolling in this course."
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
        if DemoModeManager.shared.isDemoModeEnabled {
            return []
        }

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
                // Only include courses that have been completed (completed_at is not null) and are active
                guard let completedAt = enrollmentJson["completed_at"] as? String,
                      !completedAt.isEmpty,
                      let courseJson = enrollmentJson["training_courses"] as? [String: Any],
                      let courseIdString = courseJson["id"] as? String,
                      let courseId = UUID(uuidString: courseIdString),
                      let title = courseJson["title"] as? String,
                      courseJson["active"] as? Bool == true else {
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
                let regionString = courseJson["region"] as? String ?? "Global"
                
                let level = TrainingCourse.CourseLevel(rawValue: levelString) ?? .beginner
                let category = TrainingCourse.CourseCategory(rawValue: categoryString) ?? .mandatory
                let provider = TrainingCourse.CourseProvider(rawValue: providerString) ?? .buzz
                let region = TrainingCourse.CourseRegion(rawValue: regionString) ?? .global
                
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
                    requiresUasGroundSchool: courseJson["requires_uas_ground_school"] as? Bool ?? false,
                    requiresFlightReviewPassed: courseJson["requires_flight_review_passed"] as? Bool ?? false,
                    requiresRocAPassed: courseJson["requires_roc_a_passed"] as? Bool ?? false,
                    externalUrl: courseJson["external_url"] as? String,
                    coverImageUrl: courseJson["cover_image_url"] as? String,
                    region: region,
                    active: courseJson["active"] as? Bool ?? true
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
        if DemoModeManager.shared.isDemoModeEnabled {
            return []
        }

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
                let formatterNoFrac = ISO8601DateFormatter()
                formatterNoFrac.formatOptions = [.withInternetDateTime]
                guard let completedAt = formatter.date(from: completedAtString) ?? formatterNoFrac.date(from: completedAtString) else {
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

    // MARK: - Sync All Course Progress

    /// Syncs progress for all enrolled courses for a pilot.
    /// Call this on profile load to ensure existing completions are reflected.
    func syncAllCourseProgress(pilotId: UUID) async {
        do {
            let response = try await supabase
                .from("course_enrollments")
                .select("course_id")
                .eq("pilot_id", value: pilotId.uuidString)
                .execute()

            let data = response.data
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return
            }

            let courseIds = jsonArray.compactMap { item -> UUID? in
                guard let idString = item["course_id"] as? String else { return nil }
                return UUID(uuidString: idString)
            }

            print("📊 [AcademyService] Syncing progress for \(courseIds.count) enrolled courses")

            await withTaskGroup(of: Void.self) { group in
                for courseId in courseIds {
                    group.addTask {
                        await self.updateCourseProgress(pilotId: pilotId, courseId: courseId)
                    }
                }
            }

            print("✅ [AcademyService] Finished syncing all course progress")
        } catch {
            print("❌ [AcademyService] Error syncing all course progress: \(error)")
        }
    }

    // MARK: - Update Course Progress

    /// Calculates course progress based on completed units and passed tests,
    /// then syncs with remote (only updates if local >= remote).
    /// Sets `completed_at` when progress reaches 100%.
    @discardableResult
    func updateCourseProgress(pilotId: UUID, courseId: UUID) async -> Int {
        if DemoModeManager.shared.isDemoModeEnabled {
            return 0
        }

        do {
            // Fetch all units and tests for this course
            let allUnits = try await fetchCourseUnits(courseId: courseId)
            let allTests = try await fetchCourseTests(courseId: courseId)
            let progressionTests = allTests.filter(\.requiredForProgression)

            let totalItems = allUnits.count + progressionTests.count

            guard totalItems > 0 else {
                print("⚠️ [AcademyService] Course \(courseId) has no units or tests to track")
                return 0
            }

            // Check which units are completed
            let unitIds = allUnits.map { $0.id }
            let completedUnitIds = await checkUnitCompletionsByUUID(
                pilotId: pilotId,
                courseId: courseId,
                unitIds: unitIds
            )

            // Check which tests are passed
            let testIds = progressionTests.map { $0.id }
            let testStatuses = await checkTestStatuses(pilotId: pilotId, testIds: testIds)
            let passedTestCount = testStatuses.values.filter { $0 }.count

            // Calculate progress
            let completedItems = completedUnitIds.count + passedTestCount
            let localProgress = Int((Double(completedItems) / Double(totalItems)) * 100)

            print("📊 [AcademyService] Progress for course \(courseId): \(completedItems)/\(totalItems) = \(localProgress)% (units: \(completedUnitIds.count)/\(allUnits.count), required tests: \(passedTestCount)/\(progressionTests.count))")

            // Fetch current remote progress
            let remoteProgress = await fetchRemoteProgress(pilotId: pilotId, courseId: courseId)

            // Sync: only update if local >= remote
            if localProgress >= remoteProgress {
                await pushProgressToRemote(pilotId: pilotId, courseId: courseId, progress: localProgress)
                print("✅ [AcademyService] Updated remote progress to \(localProgress)% (was \(remoteProgress)%)")
            } else {
                print("ℹ️ [AcademyService] Remote progress \(remoteProgress)% is higher than local \(localProgress)%, keeping remote value")
            }

            return localProgress
        } catch {
            print("❌ [AcademyService] Error updating course progress: \(error)")
            return 0
        }
    }

    /// Fetches the current progress_percentage from course_enrollments on the remote
    private func fetchRemoteProgress(pilotId: UUID, courseId: UUID) async -> Int {
        do {
            let response = try await supabase
                .from("course_enrollments")
                .select("progress_percentage")
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("course_id", value: courseId.uuidString)
                .execute()

            let data = response.data
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let first = jsonArray.first,
                  let progress = first["progress_percentage"] as? Int else {
                return 0
            }

            return progress
        } catch {
            print("❌ [AcademyService] Error fetching remote progress: \(error)")
            return 0
        }
    }

    /// Updates course_enrollments with the new progress value.
    /// If progress reaches 100, also sets completed_at to current timestamp.
    private func pushProgressToRemote(pilotId: UUID, courseId: UUID, progress: Int) async {
        do {
            if progress >= 100 {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let now = formatter.string(from: Date())
                try await supabase
                    .from("course_enrollments")
                    .update([
                        "progress_percentage": AnyJSON.integer(progress),
                        "completed_at": AnyJSON.string(now)
                    ] as [String: AnyJSON])
                    .eq("pilot_id", value: pilotId.uuidString)
                    .eq("course_id", value: courseId.uuidString)
                    .execute()
            } else {
                try await supabase
                    .from("course_enrollments")
                    .update([
                        "progress_percentage": AnyJSON.integer(progress)
                    ] as [String: AnyJSON])
                    .eq("pilot_id", value: pilotId.uuidString)
                    .eq("course_id", value: courseId.uuidString)
                    .execute()
            }
        } catch {
            print("❌ [AcademyService] Error pushing progress to remote: \(error)")
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
    let externalUrl: String?
    let coverImageUrl: String?
    let region: String?
    let active: Bool?
    
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
        case externalUrl = "external_url"
        case coverImageUrl = "cover_image_url"
        case region
        case active
    }
}

struct CourseEnrollmentResponse: Codable {
    let courseId: UUID
    let completedAt: String?
    let progressPercentage: Int?

    enum CodingKeys: String, CodingKey {
        case courseId = "course_id"
        case completedAt = "completed_at"
        case progressPercentage = "progress_percentage"
    }
}

// MARK: - Course Enrollment Model

struct CourseEnrollment: Codable, Identifiable {
    let id: UUID
    let pilotId: UUID
    let courseId: UUID
    let enrolledAt: Date
    let progressPercentage: Int
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case courseId = "course_id"
        case enrolledAt = "enrolled_at"
        case progressPercentage = "progress_percentage"
        case completedAt = "completed_at"
    }
}
