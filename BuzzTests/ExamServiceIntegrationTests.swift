//
//  ExamServiceIntegrationTests.swift
//  BuzzTests
//
//  Integration tests for ExamService calling real Supabase.
//

import XCTest
@testable import Buzz

@MainActor
final class ExamServiceIntegrationTests: IntegrationTestCase {

    private var service: ExamService!

    override func setUp() async throws {
        try await super.setUp()
        service = ExamService.shared
    }

    override func tearDown() async throws {
        service = nil
        try await super.tearDown()
    }

    // MARK: - Fetch Exam Configs

    func testFetchExamConfigs_completesAndReturnsConfigs() async {
        await service.fetchExamConfigs()
        XCTAssertFalse(service.isLoadingConfigs, "isLoadingConfigs should be false after fetch")
        XCTAssertFalse(service.examConfigs.isEmpty, "examConfigs should not be empty")
    }

    func testFetchExamConfigs_containsKnownExamType() async {
        await service.fetchExamConfigs()
        // At least one of the known exam types should have a config
        let hasKnownType = service.examConfigs.keys.contains(.flightReview)
            || service.examConfigs.keys.contains(.rocA)
            || service.examConfigs.keys.contains(.groundSchoolTest)
        XCTAssertTrue(hasKnownType, "Should contain at least one known exam type config")
    }

    // MARK: - Check Prerequisites

    func testCheckPrerequisites_returnsStatus() async throws {
        let status = try await service.checkPrerequisites(pilotId: TestUser.id)
        XCTAssertNotNil(status, "Should return a non-nil ExamPrerequisitesStatus")
        // Verify the published property was also set
        XCTAssertNotNil(service.prerequisitesStatus)
        XCTAssertFalse(service.isLoading, "isLoading should be false after fetch")
    }

    // MARK: - Fetch Appointments

    func testFetchAppointments_completesWithoutError() async {
        await service.fetchAppointments(pilotId: TestUser.id)
        XCTAssertFalse(service.isLoading, "isLoading should be false after fetch")
        XCTAssertNil(service.errorMessage, "errorMessage should be nil on success")
        // appointments may be empty but should be accessible
        XCTAssertNotNil(service.appointments)
    }

    // MARK: - Has Existing Appointment

    func testHasExistingAppointment_returnsBoolForEachExamType() async {
        for examType in ExamType.allCases {
            let result = await service.hasExistingAppointment(pilotId: TestUser.id, examType: examType)
            // Should return a Bool without throwing — value depends on test user state
            XCTAssertNotNil(result, "hasExistingAppointment should return a Bool for \(examType.rawValue)")
        }
    }

    // MARK: - Get Available Time Slots

    func testGetAvailableTimeSlots_returnsNonEmptyForTomorrow() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let slots = service.getAvailableTimeSlots(for: tomorrow)
        XCTAssertFalse(slots.isEmpty, "Should return available time slots for tomorrow")
        // Should have slots from 9 AM to 5 PM every 30 min = 16 slots
        XCTAssertEqual(slots.count, 16, "Should have 16 half-hour slots from 9 AM to 5 PM")
    }
}
