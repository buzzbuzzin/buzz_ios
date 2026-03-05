//
//  ExamServiceTests.swift
//  BuzzTests
//
//  Unit tests for ExamService pure logic (no network calls).
//

import XCTest
@testable import Buzz

@MainActor
final class ExamServiceTests: XCTestCase {

    // MARK: - getAvailableTimeSlots

    private var service: ExamService { ExamService.shared }

    func testGetAvailableTimeSlotsReturns16Slots() {
        let date = Date()
        let slots = service.getAvailableTimeSlots(for: date)
        XCTAssertEqual(slots.count, 16)
    }

    func testGetAvailableTimeSlotsFirstSlotIs9AM() {
        let date = Date()
        let slots = service.getAvailableTimeSlots(for: date)
        let calendar = Calendar.current
        let first = slots.first!
        XCTAssertEqual(calendar.component(.hour, from: first), 9)
        XCTAssertEqual(calendar.component(.minute, from: first), 0)
    }

    func testGetAvailableTimeSlotsLastSlotIs430PM() {
        let date = Date()
        let slots = service.getAvailableTimeSlots(for: date)
        let calendar = Calendar.current
        let last = slots.last!
        XCTAssertEqual(calendar.component(.hour, from: last), 16)
        XCTAssertEqual(calendar.component(.minute, from: last), 30)
    }

    func testGetAvailableTimeSlotsAllOnCorrectDate() {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let slots = service.getAvailableTimeSlots(for: date)

        for slot in slots {
            XCTAssertEqual(calendar.component(.year, from: slot), 2026)
            XCTAssertEqual(calendar.component(.month, from: slot), 6)
            XCTAssertEqual(calendar.component(.day, from: slot), 15)
        }
    }

    func testGetAvailableTimeSlotsAre30MinutesApart() {
        let date = Date()
        let slots = service.getAvailableTimeSlots(for: date)

        for i in 1..<slots.count {
            let diff = slots[i].timeIntervalSince(slots[i - 1])
            XCTAssertEqual(diff, 30 * 60, accuracy: 1.0, "Slots \(i-1) and \(i) should be 30 minutes apart")
        }
    }

    // MARK: - getConfig

    func testGetConfigReturnsMatchingConfigWhenPopulated() {
        let savedConfigs = service.examConfigs
        let custom = ExamTypeConfig(
            examType: "flight_review",
            displayName: "Custom FR",
            shortDescription: "Custom short",
            fullDescription: "Custom full",
            icon: "custom.icon",
            durationMinutes: 99,
            allowsOnline: true,
            stripeProductId: "prod_custom",
            prerequisites: []
        )
        service.examConfigs = [.flightReview: custom]

        let config = service.getConfig(for: .flightReview)
        XCTAssertEqual(config.displayName, "Custom FR")
        XCTAssertEqual(config.durationMinutes, 99)

        service.examConfigs = savedConfigs
    }

    func testGetConfigReturnsDefaultWhenConfigsEmpty() {
        let savedConfigs = service.examConfigs
        service.examConfigs = [:]

        let config = service.getConfig(for: .flightReview)
        XCTAssertEqual(config.displayName, ExamTypeConfig.defaultFlightReview.displayName)
        XCTAssertEqual(config.durationMinutes, ExamTypeConfig.defaultFlightReview.durationMinutes)

        service.examConfigs = savedConfigs
    }

    // MARK: - Default Configs

    func testDefaultFlightReviewConfig() {
        let config = ExamTypeConfig.defaultFlightReview
        XCTAssertEqual(config.examType, "flight_review")
        XCTAssertEqual(config.displayName, "Flight Review")
        XCTAssertEqual(config.durationMinutes, 45)
        XCTAssertFalse(config.allowsOnline)
        XCTAssertEqual(config.icon, "person.text.rectangle.fill")
        XCTAssertFalse(config.stripeProductId.isEmpty)
        XCTAssertFalse(config.prerequisites.isEmpty)
    }

    func testDefaultRocAConfig() {
        let config = ExamTypeConfig.defaultRocA
        XCTAssertEqual(config.examType, "roc_a")
        XCTAssertEqual(config.displayName, "ROC-A")
        XCTAssertEqual(config.durationMinutes, 30)
        XCTAssertTrue(config.allowsOnline)
        XCTAssertEqual(config.icon, "antenna.radiowaves.left.and.right")
        XCTAssertFalse(config.stripeProductId.isEmpty)
        XCTAssertFalse(config.prerequisites.isEmpty)
    }

    func testDefaultGroundSchoolTestConfig() {
        let config = ExamTypeConfig.defaultGroundSchoolTest
        XCTAssertEqual(config.examType, "ground_school_test")
        XCTAssertEqual(config.displayName, "Ground School Test")
        XCTAssertEqual(config.durationMinutes, 60)
        XCTAssertTrue(config.allowsOnline)
        XCTAssertEqual(config.icon, "pencil.line")
        XCTAssertFalse(config.prerequisites.isEmpty)
    }

    func testDefaultConfigForReturnsCorrectDefaults() {
        let fr = ExamTypeConfig.defaultConfig(for: .flightReview)
        XCTAssertEqual(fr.examType, ExamTypeConfig.defaultFlightReview.examType)

        let roc = ExamTypeConfig.defaultConfig(for: .rocA)
        XCTAssertEqual(roc.examType, ExamTypeConfig.defaultRocA.examType)

        let gs = ExamTypeConfig.defaultConfig(for: .groundSchoolTest)
        XCTAssertEqual(gs.examType, ExamTypeConfig.defaultGroundSchoolTest.examType)
    }

    // MARK: - ExamServiceError descriptions

    func testAllErrorsHaveNonEmptyDescriptions() {
        let errors: [ExamServiceError] = [
            .failedToCreateAppointment,
            .failedToRescheduleAppointment,
            .prerequisitesNotMet,
            .examAlreadyScheduled,
            .invalidExamType,
            .cannotRescheduleWithin24Hours
        ]

        for error in errors {
            let desc = error.errorDescription
            XCTAssertNotNil(desc, "\(error) should have an errorDescription")
            XCTAssertFalse(desc!.isEmpty, "\(error) errorDescription should not be empty")
        }
    }

    func testSpecificErrorMessages() {
        XCTAssertEqual(
            ExamServiceError.failedToCreateAppointment.errorDescription,
            "Failed to create exam appointment. Please try again."
        )
        XCTAssertEqual(
            ExamServiceError.failedToRescheduleAppointment.errorDescription,
            "Failed to reschedule exam appointment. Please try again."
        )
        XCTAssertEqual(
            ExamServiceError.prerequisitesNotMet.errorDescription,
            "You must pass the Ground School Test and complete Unit 4 before scheduling this exam."
        )
        XCTAssertEqual(
            ExamServiceError.examAlreadyScheduled.errorDescription,
            "You already have a pending or confirmed appointment for this exam."
        )
        XCTAssertEqual(
            ExamServiceError.invalidExamType.errorDescription,
            "Invalid exam type selected."
        )
        XCTAssertEqual(
            ExamServiceError.cannotRescheduleWithin24Hours.errorDescription,
            "Rescheduling is not available within 24 hours of your scheduled exam."
        )
    }

    // MARK: - ensureConfigsLoaded (smoke test)

    func testEnsureConfigsLoadedIsCallable() async {
        // Just verify the method doesn't crash; it will attempt a network call
        // but we're testing that the method is accessible and callable.
        // The fetch will fail silently and fall back to defaults.
        await service.ensureConfigsLoaded()
    }
}
