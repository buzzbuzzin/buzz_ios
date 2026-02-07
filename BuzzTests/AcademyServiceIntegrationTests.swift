//
//  AcademyServiceIntegrationTests.swift
//  BuzzTests
//
//  Integration tests for AcademyService calling real Supabase.
//

import XCTest
@testable import Buzz

@MainActor
final class AcademyServiceIntegrationTests: IntegrationTestCase {

    private var service: AcademyService!

    override func setUp() async throws {
        try await super.setUp()
        service = AcademyService()
    }

    override func tearDown() async throws {
        service = nil
        try await super.tearDown()
    }

    // MARK: - Fetch Courses

    func testFetchCourses_completesWithoutError() async throws {
        try await service.fetchCourses()
        XCTAssertFalse(service.isLoading, "isLoading should be false after fetch")
        XCTAssertNil(service.errorMessage, "errorMessage should be nil on success")
        XCTAssertNotNil(service.courses)
    }

    func testFetchCourses_returnsCoursesArray() async throws {
        try await service.fetchCourses()
        // If courses exist, verify basic structure
        for course in service.courses {
            XCTAssertFalse(course.title.isEmpty, "Course title should not be empty")
            XCTAssertNotNil(course.level)
            XCTAssertNotNil(course.category)
        }
    }

    func testFetchCoursesWithEnrollment_completesWithoutError() async throws {
        try await service.fetchCoursesWithEnrollment(pilotId: TestUser.id)
        XCTAssertFalse(service.isLoading)
        XCTAssertNil(service.errorMessage)
    }

    func testFetchAllActiveTests_returnsArray() async throws {
        let tests = try await service.fetchAllActiveTests()
        // May be empty, but should not throw
        XCTAssertNotNil(tests)
    }

    func testCheckAllPrerequisites_returnsTuple() async throws {
        let result = await service.checkAllPrerequisites(pilotId: TestUser.id)
        // Should return three booleans without crashing
        // Values can be true or false depending on test user state
        XCTAssertNotNil(result.groundSchool)
        XCTAssertNotNil(result.flightReview)
        XCTAssertNotNil(result.rocA)
    }
}
