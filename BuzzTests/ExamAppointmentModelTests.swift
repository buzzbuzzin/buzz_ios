//
//  ExamAppointmentModelTests.swift
//  BuzzTests
//
//  Tests for ExamAppointment, ExamType, ExamLocationType, ExamAppointmentStatus,
//  ExamPrerequisitesStatus, ExamPriceResponse, ExamPaymentIntentResponse, and ExamTypeConfig models.
//

import XCTest
import SwiftUI
@testable import Buzz

final class ExamAppointmentModelTests: XCTestCase {

    // MARK: - ExamType Raw Values

    func testExamType_rawValues() {
        XCTAssertEqual(ExamType.flightReview.rawValue, "flight_review")
        XCTAssertEqual(ExamType.rocA.rawValue, "roc_a")
        XCTAssertEqual(ExamType.groundSchoolTest.rawValue, "ground_school_test")
    }

    // MARK: - ExamType Display Names

    func testExamType_displayNames() {
        XCTAssertEqual(ExamType.flightReview.displayName, "Flight Review")
        XCTAssertEqual(ExamType.rocA.displayName, "ROC-A")
        XCTAssertEqual(ExamType.groundSchoolTest.displayName, "Ground School Test")
    }

    // MARK: - ExamType Icons

    func testExamType_icons() {
        XCTAssertEqual(ExamType.flightReview.icon, "person.text.rectangle.fill")
        XCTAssertEqual(ExamType.rocA.icon, "antenna.radiowaves.left.and.right")
        XCTAssertEqual(ExamType.groundSchoolTest.icon, "pencil.line")
    }

    // MARK: - ExamType Colors

    func testExamType_colors() {
        XCTAssertEqual(ExamType.flightReview.color, .blue)
        XCTAssertEqual(ExamType.rocA.color, .blue)
        XCTAssertEqual(ExamType.groundSchoolTest.color, .orange)
    }

    // MARK: - ExamType id

    func testExamType_idEqualsRawValue() {
        for examType in ExamType.allCases {
            XCTAssertEqual(examType.id, examType.rawValue)
        }
    }

    // MARK: - ExamLocationType Raw Values

    func testExamLocationType_rawValues() {
        XCTAssertEqual(ExamLocationType.inPerson.rawValue, "in_person")
        XCTAssertEqual(ExamLocationType.online.rawValue, "online")
    }

    // MARK: - ExamLocationType Display Names

    func testExamLocationType_displayNames() {
        XCTAssertEqual(ExamLocationType.inPerson.displayName, "In-Person")
        XCTAssertEqual(ExamLocationType.online.displayName, "Online (Zoom)")
    }

    // MARK: - ExamLocationType Icons

    func testExamLocationType_icons() {
        XCTAssertEqual(ExamLocationType.inPerson.icon, "mappin.and.ellipse")
        XCTAssertEqual(ExamLocationType.online.icon, "video.fill")
    }

    // MARK: - ExamAppointmentStatus Raw Values

    func testExamAppointmentStatus_rawValues() {
        XCTAssertEqual(ExamAppointmentStatus.pending.rawValue, "pending")
        XCTAssertEqual(ExamAppointmentStatus.confirmed.rawValue, "confirmed")
        XCTAssertEqual(ExamAppointmentStatus.completed.rawValue, "completed")
        XCTAssertEqual(ExamAppointmentStatus.cancelled.rawValue, "cancelled")
    }

    // MARK: - ExamAppointmentStatus Display Names

    func testExamAppointmentStatus_displayNames() {
        XCTAssertEqual(ExamAppointmentStatus.pending.displayName, "Pending")
        XCTAssertEqual(ExamAppointmentStatus.confirmed.displayName, "Confirmed")
        XCTAssertEqual(ExamAppointmentStatus.completed.displayName, "Completed")
        XCTAssertEqual(ExamAppointmentStatus.cancelled.displayName, "Cancelled")
    }

    // MARK: - ExamAppointmentStatus Colors

    func testExamAppointmentStatus_colors() {
        XCTAssertEqual(ExamAppointmentStatus.pending.color, .orange)
        XCTAssertEqual(ExamAppointmentStatus.confirmed.color, .green)
        XCTAssertEqual(ExamAppointmentStatus.completed.color, .blue)
        XCTAssertEqual(ExamAppointmentStatus.cancelled.color, .red)
    }

    // MARK: - ExamAppointmentStatus Icons

    func testExamAppointmentStatus_icons() {
        XCTAssertEqual(ExamAppointmentStatus.pending.icon, "clock")
        XCTAssertEqual(ExamAppointmentStatus.confirmed.icon, "checkmark.circle")
        XCTAssertEqual(ExamAppointmentStatus.completed.icon, "checkmark.seal.fill")
        XCTAssertEqual(ExamAppointmentStatus.cancelled.icon, "xmark.circle")
    }

    // MARK: - ExamAppointment JSON Decoding

    func testExamAppointment_jsonDecoding() {
        let appointment = makeExamAppointmentFromJSON()
        XCTAssertEqual(appointment.examType, .flightReview)
        XCTAssertEqual(appointment.durationMinutes, 45)
        XCTAssertEqual(appointment.locationType, .online)
        XCTAssertEqual(appointment.status, .confirmed)
        XCTAssertEqual(appointment.locationAddress, "123 Airport Rd")
        XCTAssertEqual(appointment.meetingLink, "https://zoom.us/j/123456")
        XCTAssertEqual(appointment.zoomMeetingId, "123456")
        XCTAssertEqual(appointment.zoomMeetingPassword, "abc123")
        XCTAssertEqual(appointment.notes, "Test notes")
    }

    // MARK: - ExamAppointment formattedDate

    func testExamAppointment_formattedDate_returnsNonEmpty() {
        let appointment = makeExamAppointment()
        XCTAssertFalse(appointment.formattedDate.isEmpty)
    }

    // MARK: - ExamAppointment formattedPrice

    func testExamAppointment_formattedPrice_returnsCurrencyString() {
        let appointment = makeExamAppointment(paymentAmount: Decimal(99.99))
        XCTAssertTrue(appointment.formattedPrice.contains("99.99"))
    }

    // MARK: - ExamAppointment endDate

    func testExamAppointment_endDate() {
        let startDate = Date()
        let durationMinutes = 45
        let appointment = makeExamAppointment(scheduledDate: startDate, durationMinutes: durationMinutes)
        let expectedEnd = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: startDate)!
        XCTAssertEqual(appointment.endDate, expectedEnd)
    }

    // MARK: - ExamAppointment hasValidZoomLink

    func testExamAppointment_hasValidZoomLink_true() {
        let appointment = makeExamAppointment(meetingLink: "https://zoom.us/j/123456")
        XCTAssertTrue(appointment.hasValidZoomLink)
    }

    func testExamAppointment_hasValidZoomLink_falseWhenNil() {
        let appointment = makeExamAppointment(meetingLink: nil)
        XCTAssertFalse(appointment.hasValidZoomLink)
    }

    func testExamAppointment_hasValidZoomLink_falseWhenPending() {
        let appointment = makeExamAppointment(meetingLink: "https://zoom.us/j/pending")
        XCTAssertFalse(appointment.hasValidZoomLink)
    }

    // MARK: - ExamAppointment zoomMeetingInfo

    func testExamAppointment_zoomMeetingInfo_includesPassword() {
        let appointment = makeExamAppointment(
            meetingLink: "https://zoom.us/j/123456",
            zoomMeetingPassword: "secret"
        )
        let info = appointment.zoomMeetingInfo
        XCTAssertNotNil(info)
        XCTAssertTrue(info!.contains("https://zoom.us/j/123456"))
        XCTAssertTrue(info!.contains("Password: secret"))
    }

    func testExamAppointment_zoomMeetingInfo_nilWhenNoValidLink() {
        let appointment = makeExamAppointment(meetingLink: nil)
        XCTAssertNil(appointment.zoomMeetingInfo)
    }

    // MARK: - ExamAppointment Decimal paymentAmount from Double

    func testExamAppointment_paymentAmountFromDouble() {
        let json = makeExamAppointmentJSON(paymentAmount: 149.99)
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        let appointment = try! decoder.decode(ExamAppointment.self, from: data)
        XCTAssertEqual(appointment.paymentAmount, Decimal(149.99))
    }

    // MARK: - ExamAppointment Decimal paymentAmount from String

    func testExamAppointment_paymentAmountFromString() {
        var json = makeExamAppointmentJSON()
        json["payment_amount"] = "249.50"
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        let appointment = try! decoder.decode(ExamAppointment.self, from: data)
        XCTAssertEqual(appointment.paymentAmount, Decimal(string: "249.50"))
    }

    // MARK: - ExamAppointment ISO8601 Fractional Seconds Date Parsing

    func testExamAppointment_dateParsing_fractionalSeconds() {
        let dateString = "2026-03-15T14:30:00.123Z"
        var json = makeExamAppointmentJSON()
        json["scheduled_date"] = dateString
        json["created_at"] = dateString
        json["updated_at"] = dateString

        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        let appointment = try! decoder.decode(ExamAppointment.self, from: data)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expectedDate = formatter.date(from: dateString)!
        XCTAssertEqual(appointment.scheduledDate, expectedDate)
    }

    // MARK: - ExamPrerequisitesStatus isEligible

    func testPrerequisitesStatus_isEligible_allTrue() {
        let status = ExamPrerequisitesStatus(passedGroundSchoolTest: true, completedUnit4: true)
        XCTAssertTrue(status.isEligible)
    }

    func testPrerequisitesStatus_isEligible_falseWhenTestNotPassed() {
        let status = ExamPrerequisitesStatus(passedGroundSchoolTest: false, completedUnit4: true)
        XCTAssertFalse(status.isEligible)
    }

    func testPrerequisitesStatus_isEligible_falseWhenUnit4NotCompleted() {
        let status = ExamPrerequisitesStatus(passedGroundSchoolTest: true, completedUnit4: false)
        XCTAssertFalse(status.isEligible)
    }

    func testPrerequisitesStatus_isEligible_falseWhenBothFalse() {
        let status = ExamPrerequisitesStatus(passedGroundSchoolTest: false, completedUnit4: false)
        XCTAssertFalse(status.isEligible)
    }

    // MARK: - ExamPrerequisitesStatus missingPrerequisites

    func testPrerequisitesStatus_missingPrerequisites_emptyWhenEligible() {
        let status = ExamPrerequisitesStatus(passedGroundSchoolTest: true, completedUnit4: true)
        XCTAssertTrue(status.missingPrerequisites.isEmpty)
    }

    func testPrerequisitesStatus_missingPrerequisites_containsCorrectItems() {
        let status = ExamPrerequisitesStatus(passedGroundSchoolTest: false, completedUnit4: false)
        XCTAssertEqual(status.missingPrerequisites.count, 2)
        XCTAssertTrue(status.missingPrerequisites.contains("Pass Ground School Test"))
        XCTAssertTrue(status.missingPrerequisites.contains("Complete Unit 4 of UAS Pilot Course"))
    }

    func testPrerequisitesStatus_missingPrerequisites_onlyTest() {
        let status = ExamPrerequisitesStatus(passedGroundSchoolTest: false, completedUnit4: true)
        XCTAssertEqual(status.missingPrerequisites, ["Pass Ground School Test"])
    }

    func testPrerequisitesStatus_missingPrerequisites_onlyUnit4() {
        let status = ExamPrerequisitesStatus(passedGroundSchoolTest: true, completedUnit4: false)
        XCTAssertEqual(status.missingPrerequisites, ["Complete Unit 4 of UAS Pilot Course"])
    }

    // MARK: - ExamPriceResponse formattedPrice

    func testExamPriceResponse_formattedPrice() {
        let response = makeExamPriceResponse(unitAmount: 9900, currency: "usd")
        XCTAssertTrue(response.formattedPrice.contains("99.00"))
    }

    func testExamPriceResponse_formattedPrice_smallAmount() {
        let response = makeExamPriceResponse(unitAmount: 199, currency: "usd")
        XCTAssertTrue(response.formattedPrice.contains("1.99"))
    }

    // MARK: - ExamPriceResponse decimalAmount

    func testExamPriceResponse_decimalAmount() {
        let response = makeExamPriceResponse(unitAmount: 14999, currency: "usd")
        XCTAssertEqual(response.decimalAmount, Decimal(14999) / 100)
    }

    // MARK: - ExamPaymentIntentResponse formattedAmount

    func testExamPaymentIntentResponse_formattedAmount() {
        let response = makeExamPaymentIntentResponse(amount: 9900, currency: "usd")
        XCTAssertTrue(response.formattedAmount.contains("99.00"))
    }

    // MARK: - ExamPaymentIntentResponse decimalAmount

    func testExamPaymentIntentResponse_decimalAmount() {
        let response = makeExamPaymentIntentResponse(amount: 14999, currency: "usd")
        XCTAssertEqual(response.decimalAmount, Decimal(14999) / 100)
    }

    // MARK: - ExamTypeConfig defaultConfig

    func testExamTypeConfig_defaultConfig_flightReview() {
        let config = ExamTypeConfig.defaultConfig(for: .flightReview)
        XCTAssertEqual(config.examType, "flight_review")
        XCTAssertEqual(config.displayName, "Flight Review")
        XCTAssertEqual(config.durationMinutes, 45)
        XCTAssertFalse(config.allowsOnline)
        XCTAssertEqual(config.icon, "person.text.rectangle.fill")
    }

    func testExamTypeConfig_defaultConfig_rocA() {
        let config = ExamTypeConfig.defaultConfig(for: .rocA)
        XCTAssertEqual(config.examType, "roc_a")
        XCTAssertEqual(config.displayName, "ROC-A")
        XCTAssertEqual(config.durationMinutes, 30)
        XCTAssertTrue(config.allowsOnline)
        XCTAssertEqual(config.icon, "antenna.radiowaves.left.and.right")
    }

    func testExamTypeConfig_defaultConfig_groundSchoolTest() {
        let config = ExamTypeConfig.defaultConfig(for: .groundSchoolTest)
        XCTAssertEqual(config.examType, "ground_school_test")
        XCTAssertEqual(config.displayName, "Ground School Test")
        XCTAssertEqual(config.durationMinutes, 60)
        XCTAssertTrue(config.allowsOnline)
        XCTAssertEqual(config.icon, "pencil.line")
    }

    // MARK: - ExamTypeConfig JSON Decoding

    func testExamTypeConfig_jsonDecoding() {
        let json = makeExamTypeConfigJSON()
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        let config = try! decoder.decode(ExamTypeConfig.self, from: data)

        XCTAssertEqual(config.examType, "flight_review")
        XCTAssertEqual(config.displayName, "Flight Review")
        XCTAssertEqual(config.shortDescription, "Short desc")
        XCTAssertEqual(config.fullDescription, "Full desc")
        XCTAssertEqual(config.icon, "person.text.rectangle.fill")
        XCTAssertEqual(config.durationMinutes, 45)
        XCTAssertFalse(config.allowsOnline)
        XCTAssertEqual(config.stripeProductId, "prod_test123")
        XCTAssertEqual(config.prerequisites, ["Prereq 1", "Prereq 2"])
    }

    // MARK: - ExamTypeConfig Manual Init

    func testExamTypeConfig_manualInit() {
        let config = ExamTypeConfig(
            examType: "roc_a",
            displayName: "ROC-A",
            shortDescription: "Radio exam",
            fullDescription: "Full radio exam description",
            icon: "antenna.radiowaves.left.and.right",
            durationMinutes: 30,
            allowsOnline: true,
            stripeProductId: "prod_abc",
            prerequisites: ["Prereq A"]
        )
        XCTAssertEqual(config.examType, "roc_a")
        XCTAssertEqual(config.displayName, "ROC-A")
        XCTAssertEqual(config.durationMinutes, 30)
        XCTAssertTrue(config.allowsOnline)
        XCTAssertEqual(config.id, "roc_a")
        XCTAssertEqual(config.prerequisites, ["Prereq A"])
    }

    // MARK: - Helpers

    private func makeExamAppointment(
        scheduledDate: Date = Date(),
        durationMinutes: Int = 45,
        meetingLink: String? = nil,
        zoomMeetingPassword: String? = nil,
        paymentAmount: Decimal = Decimal(99.00)
    ) -> ExamAppointment {
        ExamAppointment(
            pilotId: UUID(),
            examType: .flightReview,
            scheduledDate: scheduledDate,
            durationMinutes: durationMinutes,
            locationType: .online,
            meetingLink: meetingLink,
            zoomMeetingPassword: zoomMeetingPassword,
            status: .confirmed,
            paymentAmount: paymentAmount
        )
    }

    private func makeExamAppointmentJSON(paymentAmount: Double = 149.99) -> [String: Any] {
        let dateString = "2026-03-15T14:30:00.000Z"
        return [
            "id": UUID().uuidString,
            "pilot_id": UUID().uuidString,
            "exam_type": "flight_review",
            "scheduled_date": dateString,
            "duration_minutes": 45,
            "location_type": "online",
            "location_address": "123 Airport Rd",
            "meeting_link": "https://zoom.us/j/123456",
            "zoom_meeting_id": "123456",
            "zoom_meeting_password": "abc123",
            "status": "confirmed",
            "stripe_payment_intent_id": "pi_test123",
            "stripe_charge_id": "ch_test123",
            "payment_amount": paymentAmount,
            "notes": "Test notes",
            "examiner_id": UUID().uuidString,
            "created_at": dateString,
            "updated_at": dateString
        ]
    }

    private func makeExamAppointmentFromJSON() -> ExamAppointment {
        let json = makeExamAppointmentJSON()
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        return try! decoder.decode(ExamAppointment.self, from: data)
    }

    private func makeExamPriceResponse(unitAmount: Int, currency: String) -> ExamPriceResponse {
        let json: [String: Any] = [
            "product_id": "prod_test",
            "price_id": "price_test",
            "unit_amount": unitAmount,
            "currency": currency,
            "product_name": "Test Exam"
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        return try! decoder.decode(ExamPriceResponse.self, from: data)
    }

    private func makeExamPaymentIntentResponse(amount: Int, currency: String) -> ExamPaymentIntentResponse {
        let json: [String: Any] = [
            "client_secret": "secret_test",
            "payment_intent_id": "pi_test",
            "amount": amount,
            "currency": currency,
            "product_name": "Test Exam"
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        return try! decoder.decode(ExamPaymentIntentResponse.self, from: data)
    }

    private func makeExamTypeConfigJSON() -> [String: Any] {
        let dateString = "2026-03-01T00:00:00.000Z"
        return [
            "exam_type": "flight_review",
            "display_name": "Flight Review",
            "short_description": "Short desc",
            "full_description": "Full desc",
            "icon": "person.text.rectangle.fill",
            "duration_minutes": 45,
            "allows_online": false,
            "stripe_product_id": "prod_test123",
            "prerequisites": ["Prereq 1", "Prereq 2"],
            "created_at": dateString,
            "updated_at": dateString
        ]
    }
}
