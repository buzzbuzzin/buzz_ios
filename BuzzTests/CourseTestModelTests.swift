//
//  CourseTestModelTests.swift
//  BuzzTests
//
//  Tests for CourseTest model and TestUploadStatus.
//

import XCTest
@testable import Buzz

final class CourseTestModelTests: XCTestCase {

    // MARK: - CourseTest formattedPrice

    func testFormattedPrice_withPrice() {
        let test = makeCourseTest(priceOfSchedule: 9900)
        XCTAssertEqual(test.formattedPrice, "$99.00")
    }

    func testFormattedPrice_free() {
        let test = makeCourseTest(priceOfSchedule: 0)
        XCTAssertEqual(test.formattedPrice, "Free")
    }

    func testFormattedPrice_nil() {
        let test = makeCourseTest(priceOfSchedule: nil)
        XCTAssertEqual(test.formattedPrice, "Free")
    }

    func testFormattedPrice_smallAmount() {
        let test = makeCourseTest(priceOfSchedule: 199)
        XCTAssertEqual(test.formattedPrice, "$1.99")
    }

    func testFormattedPrice_largeAmount() {
        let test = makeCourseTest(priceOfSchedule: 25000)
        XCTAssertEqual(test.formattedPrice, "$250.00")
    }

    // MARK: - TestUploadStatus

    func testUploadStatusDisplayNames() {
        XCTAssertEqual(TestUploadStatus.notSubmitted.displayName, "Not Submitted")
        XCTAssertEqual(TestUploadStatus.pending.displayName, "Under Review")
        XCTAssertEqual(TestUploadStatus.approved.displayName, "Approved")
        XCTAssertEqual(TestUploadStatus.rejected.displayName, "Rejected")
    }

    func testUploadStatusRawValues() {
        XCTAssertEqual(TestUploadStatus.notSubmitted.rawValue, "not_submitted")
        XCTAssertEqual(TestUploadStatus.pending.rawValue, "pending")
        XCTAssertEqual(TestUploadStatus.approved.rawValue, "approved")
        XCTAssertEqual(TestUploadStatus.rejected.rawValue, "rejected")
    }

    // MARK: - TestResult uploadStatusEnum

    func testTestResult_uploadStatusEnum_nil() {
        let result = makeTestResult(uploadStatus: nil)
        XCTAssertEqual(result.uploadStatusEnum, .notSubmitted)
    }

    func testTestResult_uploadStatusEnum_valid() {
        let result = makeTestResult(uploadStatus: "approved")
        XCTAssertEqual(result.uploadStatusEnum, .approved)
    }

    func testTestResult_uploadStatusEnum_invalid() {
        let result = makeTestResult(uploadStatus: "invalid_status")
        XCTAssertEqual(result.uploadStatusEnum, .notSubmitted)
    }

    // MARK: - TestQuestion Initialization

    func testTestQuestionManualInit() {
        let testId = UUID()
        let question = TestQuestion(
            id: UUID(),
            testId: testId,
            questionNumber: 1,
            questionArea: "Safety",
            questionText: "What is the max altitude?",
            options: ["100ft", "200ft", "400ft", "500ft"],
            correctAnswerIndex: 2,
            explanation: "400ft is the FAA limit",
            imageUrls: [],
            problemSets: [1, 2]
        )
        XCTAssertEqual(question.testId, testId)
        XCTAssertEqual(question.questionNumber, 1)
        XCTAssertEqual(question.options.count, 4)
        XCTAssertEqual(question.correctAnswerIndex, 2)
        XCTAssertEqual(question.problemSets, [1, 2])
    }

    // MARK: - Helpers

    private func makeCourseTest(priceOfSchedule: Int?) -> CourseTest {
        // Use manual JSON decoding since CourseTest requires Decoder init
        let testId = UUID()
        let courseId = UUID()
        let json: [String: Any] = [
            "id": testId.uuidString,
            "course_id": courseId.uuidString,
            "test_name": "Test Exam",
            "test_type": "multiple_choice",
            "passing_score": 80,
            "required_for_progression": true,
            "required_units": [],
            "order_index": 1,
            "is_active": true,
            "needs_proctor": false,
            "price_of_schedule": priceOfSchedule as Any
        ]

        // Filter out NSNull for nil values
        var filteredJson: [String: Any] = [:]
        for (key, value) in json {
            if value is NSNull { continue }
            if let optionalValue = value as? Int? {
                if let v = optionalValue {
                    filteredJson[key] = v
                }
            } else {
                filteredJson[key] = value
            }
        }

        let data = try! JSONSerialization.data(withJSONObject: filteredJson)
        let decoder = JSONDecoder()
        return try! decoder.decode(CourseTest.self, from: data)
    }

    private func makeTestResult(uploadStatus: String?) -> TestResult {
        let json: [String: Any?] = [
            "id": UUID().uuidString,
            "pilot_id": UUID().uuidString,
            "test_id": UUID().uuidString,
            "course_id": UUID().uuidString,
            "score": 85,
            "passed": true,
            "attempt_number": 1,
            "completed_at": ISO8601DateFormatter().string(from: Date()),
            "upload_status": uploadStatus
        ]
        let filteredJson = json.compactMapValues { $0 }
        let data = try! JSONSerialization.data(withJSONObject: filteredJson)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(TestResult.self, from: data)
    }
}
