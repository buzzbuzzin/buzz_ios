//
//  LicenseApprovalWorkflowIntegrationTests.swift
//  BuzzTests
//
//  End-to-end integration coverage for the reviewer/examiner approval workflow
//  using the existing XCTest + live Supabase test harness.
//

import XCTest
import Supabase
import UIKit
@testable import Buzz

@MainActor
final class LicenseApprovalWorkflowIntegrationTests: IntegrationTestCase {

    private struct ProfileUserTypeRecord: Codable {
        let userType: String

        enum CodingKeys: String, CodingKey {
            case userType = "user_type"
        }
    }

    private struct PilotSpecialRolesRecord: Codable {
        let pilotId: UUID
        let flightReviewer: Bool?
        let rocaExaminer: Bool?

        enum CodingKeys: String, CodingKey {
            case pilotId = "pilot_id"
            case flightReviewer = "flight_reviewer"
            case rocaExaminer = "roc_a_examiner"
        }
    }

    private struct UpdateLicenseApprovalBody: Codable {
        let requestId: String
        let status: String
        let reviewerNotes: String?

        enum CodingKeys: String, CodingKey {
            case requestId
            case status
            case reviewerNotes
        }
    }

    private struct UpdateLicenseApprovalResponse: Codable {
        let success: Bool?
        let message: String?
        let error: String?
    }

    private func makeTestJPEG() -> Data {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        UIColor.orange.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image.jpegData(compressionQuality: 0.9)!
    }

    private func fetchCurrentUserType() async throws -> String {
        let record: ProfileUserTypeRecord = try await supabase
            .from("profiles")
            .select("user_type")
            .eq("id", value: TestUser.id.uuidString)
            .single()
            .execute()
            .value
        return record.userType
    }

    private func setCurrentUserType(_ userType: String) async throws {
        let payload: [String: AnyJSON] = ["user_type": .string(userType)]
        try await supabase
            .from("profiles")
            .update(payload)
            .eq("id", value: TestUser.id.uuidString)
            .execute()
    }

    private func fetchPilotSpecialRoles() async throws -> PilotSpecialRolesRecord? {
        let records: [PilotSpecialRolesRecord] = try await supabase
            .from("pilot_special_roles")
            .select("pilot_id, flight_reviewer, roc_a_examiner")
            .eq("pilot_id", value: TestUser.id.uuidString)
            .limit(1)
            .execute()
            .value
        return records.first
    }

    private func restorePilotSpecialRoles(_ snapshot: PilotSpecialRolesRecord?) async throws {
        if let snapshot {
            try await supabase
                .from("pilot_special_roles")
                .upsert(
                    [
                        "pilot_id": .string(snapshot.pilotId.uuidString),
                        "flight_reviewer": snapshot.flightReviewer.map(AnyJSON.bool) ?? .null,
                        "roc_a_examiner": snapshot.rocaExaminer.map(AnyJSON.bool) ?? .null,
                    ],
                    onConflict: "pilot_id"
                )
                .execute()
        } else {
            try await supabase
                .from("pilot_special_roles")
                .delete()
                .eq("pilot_id", value: TestUser.id.uuidString)
                .execute()
        }
    }

    private func withTemporaryAdminAccess<T>(
        _ operation: () async throws -> T
    ) async throws -> T {
        let originalUserType = try await fetchCurrentUserType()
        try await setCurrentUserType("admin")
        do {
            let result = try await operation()
            try await setCurrentUserType(originalUserType)
            return result
        } catch {
            try? await setCurrentUserType(originalUserType)
            throw error
        }
    }

    private func uploadReviewableLicense(
        licenseType: String
    ) async throws -> (service: LicenseUploadService, license: PilotLicense, request: LicenseApprovalRequest) {
        let service = LicenseUploadService()
        let publicURL = try await service.uploadLicense(
            pilotId: TestUser.id,
            data: makeTestJPEG(),
            fileName: "workflow_\(UUID().uuidString.prefix(8)).jpg",
            fileType: .image,
            licenseType: licenseType
        )

        try await service.fetchLicenses(pilotId: TestUser.id)
        let license = try XCTUnwrap(
            service.licenses.first(where: { $0.fileUrl == publicURL }),
            "Uploaded \(licenseType) license should exist"
        )
        let request = try XCTUnwrap(
            service.approvalRequest(for: license.id),
            "\(licenseType) upload should create an approval request"
        )
        return (service, license, request)
    }

    private func fetchApprovalRequest(id: UUID) async throws -> LicenseApprovalRequest {
        try await supabase
            .from("license_approval_requests")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    private func invokeUpdateLicenseApproval(
        requestId: UUID,
        status: String,
        reviewerNotes: String? = nil
    ) async throws -> UpdateLicenseApprovalResponse {
        try await supabase.functions.invoke(
            "update-license-approval",
            options: FunctionInvokeOptions(
                body: UpdateLicenseApprovalBody(
                    requestId: requestId.uuidString,
                    status: status,
                    reviewerNotes: reviewerNotes
                )
            )
        )
    }

    func testWorkflow_preApprovedThenApproved_updatesRequestAndRole() async throws {
        let originalRoles = try await fetchPilotSpecialRoles()
        let upload = try await uploadReviewableLicense(licenseType: LicenseType.rpaFlightReviewer.rawValue)
        do {
            try await withTemporaryAdminAccess {
                let preApprovedResponse = try await invokeUpdateLicenseApproval(
                    requestId: upload.request.id,
                    status: "pre_approved"
                )
                XCTAssertEqual(preApprovedResponse.success, true)
                XCTAssertEqual(preApprovedResponse.message, "License pre_approved")

                let preApprovedRequest = try await fetchApprovalRequest(id: upload.request.id)
                XCTAssertEqual(preApprovedRequest.statusEnum, .preApproved)
                XCTAssertNil(preApprovedRequest.reviewerNotes)

                let approvedResponse = try await invokeUpdateLicenseApproval(
                    requestId: upload.request.id,
                    status: "approved"
                )
                XCTAssertEqual(approvedResponse.success, true)
                XCTAssertEqual(approvedResponse.message, "License approved")

                let approvedRequest = try await fetchApprovalRequest(id: upload.request.id)
                XCTAssertEqual(approvedRequest.statusEnum, .approved)
                XCTAssertNil(approvedRequest.reviewerNotes)

                let roles = try await fetchPilotSpecialRoles()
                XCTAssertEqual(roles?.flightReviewer, true)
            }
        } catch {
            try? await restorePilotSpecialRoles(originalRoles)
            try? await upload.service.deleteLicense(license: upload.license)
            throw error
        }

        try await restorePilotSpecialRoles(originalRoles)
        try await upload.service.deleteLicense(license: upload.license)
    }

    func testWorkflow_rejectedFromPending_persistsReviewerNotes() async throws {
        let originalRoles = try await fetchPilotSpecialRoles()
        let upload = try await uploadReviewableLicense(licenseType: LicenseType.rocaExaminerCertificate.rawValue)
        do {
            try await withTemporaryAdminAccess {
                let response = try await invokeUpdateLicenseApproval(
                    requestId: upload.request.id,
                    status: "rejected",
                    reviewerNotes: "Examiner number was missing"
                )
                XCTAssertEqual(response.success, true)
                XCTAssertEqual(response.message, "License rejected")

                let rejectedRequest = try await fetchApprovalRequest(id: upload.request.id)
                XCTAssertEqual(rejectedRequest.statusEnum, .rejected)
                XCTAssertEqual(rejectedRequest.reviewerNotes, "Examiner number was missing")

                let roles = try await fetchPilotSpecialRoles()
                XCTAssertEqual(roles?.rocaExaminer, originalRoles?.rocaExaminer)
            }
        } catch {
            try? await restorePilotSpecialRoles(originalRoles)
            try? await upload.service.deleteLicense(license: upload.license)
            throw error
        }

        try await restorePilotSpecialRoles(originalRoles)
        try await upload.service.deleteLicense(license: upload.license)
    }

    func testWorkflow_rejectedFromPreApproved_revokesRole() async throws {
        let originalRoles = try await fetchPilotSpecialRoles()
        let upload = try await uploadReviewableLicense(licenseType: LicenseType.rocaExaminerCertificate.rawValue)
        do {
            try await withTemporaryAdminAccess {
                _ = try await invokeUpdateLicenseApproval(
                    requestId: upload.request.id,
                    status: "pre_approved"
                )
                _ = try await invokeUpdateLicenseApproval(
                    requestId: upload.request.id,
                    status: "rejected"
                )

                let rejectedRequest = try await fetchApprovalRequest(id: upload.request.id)
                XCTAssertEqual(rejectedRequest.statusEnum, .rejected)
                XCTAssertNil(rejectedRequest.reviewerNotes)

                let roles = try await fetchPilotSpecialRoles()
                XCTAssertEqual(roles?.rocaExaminer, false)
            }
        } catch {
            try? await restorePilotSpecialRoles(originalRoles)
            try? await upload.service.deleteLicense(license: upload.license)
            throw error
        }

        try await restorePilotSpecialRoles(originalRoles)
        try await upload.service.deleteLicense(license: upload.license)
    }

    func testWorkflow_invalidTransition_pendingToApprovedFails() async throws {
        let upload = try await uploadReviewableLicense(licenseType: LicenseType.rpaFlightReviewer.rawValue)
        do {
            try await withTemporaryAdminAccess {
                await XCTAssertThrowsErrorAsync {
                    _ = try await self.invokeUpdateLicenseApproval(
                        requestId: upload.request.id,
                        status: "approved"
                    )
                }

                let unchangedRequest = try await fetchApprovalRequest(id: upload.request.id)
                XCTAssertEqual(unchangedRequest.statusEnum, .pending)
            }
        } catch {
            try? await upload.service.deleteLicense(license: upload.license)
            throw error
        }

        try await upload.service.deleteLicense(license: upload.license)
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: @escaping () async throws -> Void,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail(message(), file: file, line: line)
    } catch {
        // Expected
    }
}
