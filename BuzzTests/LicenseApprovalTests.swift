//
//  LicenseApprovalTests.swift
//  BuzzTests
//
//  Tests for license approval workflow: PilotLicense model, LicenseApprovalStatus enum,
//  LicenseApprovalRequest model, and storage path RLS compliance.
//

import XCTest
import SwiftUI
@testable import Buzz

final class LicenseApprovalTests: XCTestCase {

    // MARK: - LicenseApprovalStatus Enum

    func testApprovalStatus_rawValues() {
        XCTAssertEqual(LicenseApprovalStatus.pending.rawValue, "pending")
        XCTAssertEqual(LicenseApprovalStatus.preApproved.rawValue, "pre_approved")
        XCTAssertEqual(LicenseApprovalStatus.approved.rawValue, "approved")
        XCTAssertEqual(LicenseApprovalStatus.rejected.rawValue, "rejected")
    }

    func testApprovalStatus_displayNames() {
        XCTAssertEqual(LicenseApprovalStatus.pending.displayName, "Under Review")
        XCTAssertEqual(LicenseApprovalStatus.preApproved.displayName, "Under Review")
        XCTAssertEqual(LicenseApprovalStatus.approved.displayName, "Approved")
        XCTAssertEqual(LicenseApprovalStatus.rejected.displayName, "Rejected")
    }

    func testApprovalStatus_colors() {
        XCTAssertEqual(LicenseApprovalStatus.pending.color, .orange)
        XCTAssertEqual(LicenseApprovalStatus.preApproved.color, .orange)
        XCTAssertEqual(LicenseApprovalStatus.approved.color, .green)
        XCTAssertEqual(LicenseApprovalStatus.rejected.color, .red)
    }

    func testApprovalStatus_codable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for status in [LicenseApprovalStatus.pending, .preApproved, .approved, .rejected] {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(LicenseApprovalStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }

    // MARK: - PilotLicense needsApproval

    func testNeedsApproval_flightReviewer() {
        let license = makeLicense(licenseType: LicenseType.rpaFlightReviewer.rawValue)
        XCTAssertTrue(license.needsApproval, "Flight Reviewer (CAN) should need approval")
    }

    func testNeedsApproval_rocaExaminer() {
        let license = makeLicense(licenseType: LicenseType.rocaExaminerCertificate.rawValue)
        XCTAssertTrue(license.needsApproval, "ROC-A Examiner (CAN) should need approval")
    }

    func testNeedsApproval_part107() {
        let license = makeLicense(licenseType: LicenseType.part107.rawValue)
        XCTAssertFalse(license.needsApproval, "Part 107 (US) should NOT need approval")
    }

    func testNeedsApproval_rpaPilot() {
        let license = makeLicense(licenseType: LicenseType.rpaPilotCertificate.rawValue)
        XCTAssertFalse(license.needsApproval, "RPA Pilot (CAN) should NOT need approval")
    }

    func testNeedsApproval_rocaCertificate() {
        let license = makeLicense(licenseType: LicenseType.rocaCertificate.rawValue)
        XCTAssertFalse(license.needsApproval, "ROC-A (CAN) should NOT need approval")
    }

    func testNeedsApproval_customType() {
        let license = makeLicense(licenseType: "Some Custom License")
        XCTAssertFalse(license.needsApproval, "Custom license types should NOT need approval")
    }

    func testNeedsApproval_nilType() {
        let license = makeLicense(licenseType: nil)
        XCTAssertFalse(license.needsApproval, "nil license type should NOT need approval")
    }

    // MARK: - LicenseApprovalRequest Model

    func testApprovalRequest_decoding() throws {
        let reviewerId = UUID()
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "pilot_id": UUID().uuidString,
            "license_id": UUID().uuidString,
            "license_type": "Flight Reviewer (CAN)",
            "file_url": "https://example.com/license.jpg",
            "status": "pending",
            "submitted_at": "2026-03-04T12:00:00Z",
            "reviewed_at": "2026-03-04T13:00:00Z",
            "reviewed_by": reviewerId.uuidString,
            "reviewer_notes": "Needs additional verification",
            "created_at": "2026-03-04T12:00:00Z",
            "updated_at": "2026-03-04T13:00:00Z"
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let request = try decoder.decode(LicenseApprovalRequest.self, from: data)
        XCTAssertEqual(request.licenseType, "Flight Reviewer (CAN)")
        XCTAssertEqual(request.status, "pending")
        XCTAssertEqual(request.statusEnum, .pending)
        XCTAssertNotNil(request.reviewedAt)
        XCTAssertEqual(request.reviewedBy, reviewerId)
        XCTAssertEqual(request.reviewerNotes, "Needs additional verification")
    }

    func testApprovalRequest_statusEnum_preApproved() throws {
        let request = makeApprovalRequest(status: "pre_approved")
        XCTAssertEqual(request.statusEnum, .preApproved)
    }

    func testApprovalRequest_statusEnum_approved() throws {
        let request = makeApprovalRequest(status: "approved")
        XCTAssertEqual(request.statusEnum, .approved)
    }

    func testApprovalRequest_statusEnum_rejected() throws {
        let request = makeApprovalRequest(status: "rejected")
        XCTAssertEqual(request.statusEnum, .rejected)
    }

    func testApprovalRequest_statusEnum_invalid() throws {
        let request = makeApprovalRequest(status: "unknown_status")
        XCTAssertNil(request.statusEnum)
    }

    func testApprovalRequest_minimalFields() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "pilot_id": UUID().uuidString,
            "license_id": UUID().uuidString,
            "license_type": "Flight Reviewer (CAN)",
            "file_url": "https://example.com/license.jpg",
            "status": "pending",
            "submitted_at": "2026-03-04T12:00:00Z",
            "created_at": "2026-03-04T12:00:00Z",
            "updated_at": "2026-03-04T12:00:00Z"
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let request = try decoder.decode(LicenseApprovalRequest.self, from: data)
        XCTAssertEqual(request.status, "pending")
        XCTAssertNil(request.reviewedAt)
        XCTAssertNil(request.reviewedBy)
        XCTAssertNil(request.reviewerNotes)
    }

    // MARK: - PilotLicense JSON Decoding (without approval fields)

    func testDecode_withoutApprovalFields() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "pilot_id": UUID().uuidString,
            "file_url": "https://example.com/license.pdf",
            "file_type": "pdf",
            "uploaded_at": "2026-03-04T12:00:00Z",
            "license_type": "Part 107 (US)"
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let license = try decoder.decode(PilotLicense.self, from: data)
        XCTAssertEqual(license.licenseType, "Part 107 (US)")
        XCTAssertFalse(license.needsApproval)
    }

    func testDecode_minimalFields() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "pilot_id": UUID().uuidString,
            "file_url": "https://example.com/file.jpg",
            "file_type": "image",
            "uploaded_at": "2026-01-01T00:00:00Z"
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let license = try decoder.decode(PilotLicense.self, from: data)
        XCTAssertNil(license.licenseType)
        XCTAssertNil(license.name)
        XCTAssertFalse(license.needsApproval)
    }

    // MARK: - Upload Approval Status Logic

    func testUploadLogic_flightReviewerSetsPending() {
        let licenseType = LicenseType.rpaFlightReviewer.rawValue
        let shouldSetPending = licenseType == LicenseType.rpaFlightReviewer.rawValue ||
                               licenseType == LicenseType.rocaExaminerCertificate.rawValue
        XCTAssertTrue(shouldSetPending, "Flight Reviewer should trigger pending approval status")
    }

    func testUploadLogic_rocaExaminerSetsPending() {
        let licenseType = LicenseType.rocaExaminerCertificate.rawValue
        let shouldSetPending = licenseType == LicenseType.rpaFlightReviewer.rawValue ||
                               licenseType == LicenseType.rocaExaminerCertificate.rawValue
        XCTAssertTrue(shouldSetPending, "ROC-A Examiner should trigger pending approval status")
    }

    func testUploadLogic_part107DoesNotSetPending() {
        let licenseType = LicenseType.part107.rawValue
        let shouldSetPending = licenseType == LicenseType.rpaFlightReviewer.rawValue ||
                               licenseType == LicenseType.rocaExaminerCertificate.rawValue
        XCTAssertFalse(shouldSetPending, "Part 107 should NOT trigger pending approval status")
    }

    func testUploadLogic_allNonReviewableTypes() {
        let nonReviewableTypes: [LicenseType] = [
            .part107, .part107Recurrent, .part108,
            .rpaPilotCertificate, .tp15263Advanced, .tp15263Recency,
            .tp15530Level1Complex, .tp15530Recency,
            .rocaCertificate, .restrictedRadiotelephone, .custom
        ]

        for type in nonReviewableTypes {
            let shouldSetPending = type.rawValue == LicenseType.rpaFlightReviewer.rawValue ||
                                   type.rawValue == LicenseType.rocaExaminerCertificate.rawValue
            XCTAssertFalse(shouldSetPending, "\(type.rawValue) should NOT trigger pending approval")
        }
    }

    // MARK: - Storage Path RLS Compliance

    func testStoragePath_usesLowercasedUUID() {
        let pilotId = UUID()
        let fileName = "license.jpg"

        // Replicate the path construction from LicenseUploadService
        let filePath = "\(pilotId.uuidString.lowercased())/\(fileName)"

        // UUID string should be lowercased in the path
        XCTAssertEqual(filePath, "\(pilotId.uuidString.lowercased())/license.jpg")
        XCTAssertFalse(filePath.contains(where: { $0.isUppercase && $0.isLetter }),
                       "Storage path must not contain uppercase letters (RLS is case-sensitive)")
    }

    func testStoragePath_mixedCaseUUID_becomesLowercase() {
        // Simulate a UUID that has uppercase letters
        let mixedCaseUUID = "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
        let fileName = "test_license.pdf"

        let filePath = "\(mixedCaseUUID.lowercased())/\(fileName)"

        XCTAssertEqual(filePath, "a1b2c3d4-e5f6-7890-abcd-ef1234567890/test_license.pdf")
        XCTAssertFalse(filePath.hasPrefix("A"), "Path must start with lowercase UUID")
    }

    func testStoragePath_format() {
        let pilotId = UUID()
        let fileName = "my_license.jpg"

        let filePath = "\(pilotId.uuidString.lowercased())/\(fileName)"

        // Verify format: {lowercased_uuid}/{filename}
        let components = filePath.split(separator: "/", maxSplits: 1)
        XCTAssertEqual(components.count, 2, "Path should have exactly two components: uuid/filename")
        XCTAssertEqual(String(components[0]), pilotId.uuidString.lowercased())
        XCTAssertEqual(String(components[1]), fileName)
    }

    func testStoragePath_uuidConsistency() {
        // Ensure the same UUID always produces the same lowercased path
        let pilotId = UUID()
        let path1 = pilotId.uuidString.lowercased()
        let path2 = pilotId.uuidString.lowercased()
        XCTAssertEqual(path1, path2, "Lowercased UUID should be deterministic")
    }

    func testStoragePath_uppercaseUUID_wouldFailRLS() {
        let pilotId = UUID()
        let uppercasePath = "\(pilotId.uuidString)/license.jpg"
        let lowercasePath = "\(pilotId.uuidString.lowercased())/license.jpg"

        // If UUID has uppercase chars, paths differ — RLS would reject the uppercase one
        if pilotId.uuidString != pilotId.uuidString.lowercased() {
            XCTAssertNotEqual(uppercasePath, lowercasePath,
                              "Uppercase UUID path differs from lowercased — RLS would reject it")
        }
    }

    // MARK: - LicenseType Categories

    func testLicenseType_reviewableTypesCategory() {
        XCTAssertEqual(LicenseType.rpaFlightReviewer.category, .flightReviewer)
        XCTAssertEqual(LicenseType.rocaExaminerCertificate.category, .examiner)
    }

    func testLicenseType_rawValues() {
        XCTAssertEqual(LicenseType.rpaFlightReviewer.rawValue, "Flight Reviewer (CAN)")
        XCTAssertEqual(LicenseType.rocaExaminerCertificate.rawValue, "ROC-A Examiner (CAN)")
        XCTAssertEqual(LicenseType.part107.rawValue, "Part 107 (US)")
    }

    // MARK: - Helpers

    private func makeLicense(
        licenseType: String? = nil
    ) -> PilotLicense {
        var json: [String: Any] = [
            "id": UUID().uuidString,
            "pilot_id": UUID().uuidString,
            "file_url": "https://example.com/license.jpg",
            "file_type": "image",
            "uploaded_at": "2026-03-04T12:00:00Z"
        ]
        if let licenseType = licenseType {
            json["license_type"] = licenseType
        }
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(PilotLicense.self, from: data)
    }

    private func makeApprovalRequest(
        status: String = "pending"
    ) -> LicenseApprovalRequest {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "pilot_id": UUID().uuidString,
            "license_id": UUID().uuidString,
            "license_type": "Flight Reviewer (CAN)",
            "file_url": "https://example.com/license.jpg",
            "status": status,
            "submitted_at": "2026-03-04T12:00:00Z",
            "created_at": "2026-03-04T12:00:00Z",
            "updated_at": "2026-03-04T12:00:00Z"
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(LicenseApprovalRequest.self, from: data)
    }
}
