//
//  StorageUploadIntegrationTests.swift
//  BuzzTests
//
//  Integration tests that upload real files to Supabase storage buckets
//  and clean them up afterward. Verifies RLS policies allow authenticated
//  users to upload, read, update, and delete files in their own folder.
//

import XCTest
import Supabase
@testable import Buzz

@MainActor
final class StorageUploadIntegrationTests: IntegrationTestCase {

    // MARK: - Helpers

    /// Lowercase user ID for storage paths (matches auth.uid()::text format).
    private var userFolder: String {
        TestUser.id.uuidString.lowercased()
    }

    /// Creates a small valid JPEG for upload tests.
    /// 100x100 so Vision OCR won't reject it (requires > 2px per dimension).
    private func makeTestJPEG() -> Data {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image.jpegData(compressionQuality: 0.9)!
    }

    /// Creates a minimal valid PDF for upload tests.
    private func makeTestPDF() -> Data {
        let pdfContent = "%PDF-1.0\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 100 100]/Parent 2 0 R>>endobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n190\n%%EOF"
        return pdfContent.data(using: .utf8)!
    }

    /// Uploads data to a bucket path and returns the file path used.
    /// Automatically schedules the file for cleanup after the test.
    @discardableResult
    private func uploadAndTrack(
        bucket: String,
        filePath: String,
        data: Data,
        contentType: String,
        upsert: Bool = false
    ) async throws -> String {
        _ = try await supabase.storage
            .from(bucket)
            .upload(
                filePath,
                data: data,
                options: FileOptions(
                    cacheControl: "0",
                    contentType: contentType,
                    upsert: upsert
                )
            )
        // Schedule cleanup
        addTeardownBlock { [supabase] in
            try? await supabase.storage
                .from(bucket)
                .remove(paths: [filePath])
        }
        return filePath
    }

    // =========================================================
    // MARK: - Profile Pictures Bucket
    // =========================================================

    func testProfilePictures_uploadJPEG() async throws {
        let data = makeTestJPEG()
        let filePath = "\(userFolder)/test_profile.jpg"

        try await uploadAndTrack(
            bucket: "profile-pictures",
            filePath: filePath,
            data: data,
            contentType: "image/jpeg",
            upsert: true
        )

        // Verify we can read it back
        let downloaded = try await supabase.storage
            .from("profile-pictures")
            .download(path: filePath)
        XCTAssertGreaterThan(downloaded.count, 0, "Downloaded file should not be empty")
    }

    func testProfilePictures_upsertOverwrites() async throws {
        let data1 = makeTestJPEG()
        let filePath = "\(userFolder)/test_upsert.jpg"

        try await uploadAndTrack(
            bucket: "profile-pictures",
            filePath: filePath,
            data: data1,
            contentType: "image/jpeg",
            upsert: true
        )

        // Upload again with upsert — should succeed, not error
        let size = CGSize(width: 200, height: 200)
        UIGraphicsBeginImageContext(size)
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image2 = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        let data2 = image2.jpegData(compressionQuality: 0.9)!

        _ = try await supabase.storage
            .from("profile-pictures")
            .upload(
                filePath,
                data: data2,
                options: FileOptions(
                    cacheControl: "0",
                    contentType: "image/jpeg",
                    upsert: true
                )
            )

        let downloaded = try await supabase.storage
            .from("profile-pictures")
            .download(path: filePath)
        // Second image (200x200) should be larger than first (100x100)
        XCTAssertGreaterThan(downloaded.count, data1.count,
                             "Upserted file should reflect the second (larger) upload")
    }

    func testProfilePictures_deleteOwnFile() async throws {
        let data = makeTestJPEG()
        let filePath = "\(userFolder)/test_delete.jpg"

        try await uploadAndTrack(
            bucket: "profile-pictures",
            filePath: filePath,
            data: data,
            contentType: "image/jpeg"
        )

        // Delete should succeed
        _ = try await supabase.storage
            .from("profile-pictures")
            .remove(paths: [filePath])

        // Attempting to download should fail
        do {
            _ = try await supabase.storage
                .from("profile-pictures")
                .download(path: filePath)
            XCTFail("Download should fail after deletion")
        } catch {
            // Expected
        }
    }

    func testProfilePictures_publicURLAccessible() async throws {
        let data = makeTestJPEG()
        let filePath = "\(userFolder)/test_public_url.jpg"

        try await uploadAndTrack(
            bucket: "profile-pictures",
            filePath: filePath,
            data: data,
            contentType: "image/jpeg"
        )

        // getPublicURL should not throw
        let publicURL = try supabase.storage
            .from("profile-pictures")
            .getPublicURL(path: filePath)
        XCTAssertFalse(publicURL.absoluteString.isEmpty)
        XCTAssertTrue(publicURL.absoluteString.contains("profile-pictures"))
    }

    // =========================================================
    // MARK: - Pilot Licenses Bucket
    // =========================================================

    func testPilotLicenses_uploadJPEG() async throws {
        let data = makeTestJPEG()
        let filePath = "\(userFolder)/test_license.jpg"

        try await uploadAndTrack(
            bucket: "pilot-licenses",
            filePath: filePath,
            data: data,
            contentType: "image/jpeg"
        )

        let downloaded = try await supabase.storage
            .from("pilot-licenses")
            .download(path: filePath)
        XCTAssertGreaterThan(downloaded.count, 0)
    }

    func testPilotLicenses_uploadPDF() async throws {
        let data = makeTestPDF()
        let filePath = "\(userFolder)/test_license.pdf"

        try await uploadAndTrack(
            bucket: "pilot-licenses",
            filePath: filePath,
            data: data,
            contentType: "application/pdf"
        )

        let downloaded = try await supabase.storage
            .from("pilot-licenses")
            .download(path: filePath)
        XCTAssertGreaterThan(downloaded.count, 0)
    }

    func testPilotLicenses_deleteOwnFile() async throws {
        let data = makeTestJPEG()
        let filePath = "\(userFolder)/test_license_del.jpg"

        try await uploadAndTrack(
            bucket: "pilot-licenses",
            filePath: filePath,
            data: data,
            contentType: "image/jpeg"
        )

        _ = try await supabase.storage
            .from("pilot-licenses")
            .remove(paths: [filePath])

        do {
            _ = try await supabase.storage
                .from("pilot-licenses")
                .download(path: filePath)
            XCTFail("Download should fail after deletion")
        } catch {
            // Expected
        }
    }

    // =========================================================
    // MARK: - Drone Registrations Bucket
    // =========================================================

    func testDroneRegistrations_uploadJPEG() async throws {
        let data = makeTestJPEG()
        let filePath = "\(userFolder)/test_registration.jpg"

        try await uploadAndTrack(
            bucket: "drone-registrations",
            filePath: filePath,
            data: data,
            contentType: "image/jpeg"
        )

        let downloaded = try await supabase.storage
            .from("drone-registrations")
            .download(path: filePath)
        XCTAssertGreaterThan(downloaded.count, 0)
    }

    func testDroneRegistrations_uploadPDF() async throws {
        let data = makeTestPDF()
        let filePath = "\(userFolder)/test_registration.pdf"

        try await uploadAndTrack(
            bucket: "drone-registrations",
            filePath: filePath,
            data: data,
            contentType: "application/pdf"
        )

        let downloaded = try await supabase.storage
            .from("drone-registrations")
            .download(path: filePath)
        XCTAssertGreaterThan(downloaded.count, 0)
    }

    func testDroneRegistrations_deleteOwnFile() async throws {
        let data = makeTestJPEG()
        let filePath = "\(userFolder)/test_reg_del.jpg"

        try await uploadAndTrack(
            bucket: "drone-registrations",
            filePath: filePath,
            data: data,
            contentType: "image/jpeg"
        )

        _ = try await supabase.storage
            .from("drone-registrations")
            .remove(paths: [filePath])

        do {
            _ = try await supabase.storage
                .from("drone-registrations")
                .download(path: filePath)
            XCTFail("Download should fail after deletion")
        } catch {
            // Expected
        }
    }

    // =========================================================
    // MARK: - Express Promotion Docs Bucket (Private)
    // =========================================================

    func testExpressPromotionDocs_uploadJPEG() async throws {
        let data = makeTestJPEG()
        let filePath = "\(userFolder)/\(UUID().uuidString)_test_doc.jpg"

        try await uploadAndTrack(
            bucket: "express-promotion-docs",
            filePath: filePath,
            data: data,
            contentType: "image/jpeg"
        )

        // Private bucket — authenticated download should work for own files
        let downloaded = try await supabase.storage
            .from("express-promotion-docs")
            .download(path: filePath)
        XCTAssertGreaterThan(downloaded.count, 0)
    }

    func testExpressPromotionDocs_uploadPDF() async throws {
        let data = makeTestPDF()
        let filePath = "\(userFolder)/\(UUID().uuidString)_test_doc.pdf"

        try await uploadAndTrack(
            bucket: "express-promotion-docs",
            filePath: filePath,
            data: data,
            contentType: "application/pdf"
        )

        let downloaded = try await supabase.storage
            .from("express-promotion-docs")
            .download(path: filePath)
        XCTAssertGreaterThan(downloaded.count, 0)
    }

    func testExpressPromotionDocs_deleteOwnFile() async throws {
        let data = makeTestJPEG()
        let filePath = "\(userFolder)/\(UUID().uuidString)_test_del.jpg"

        try await uploadAndTrack(
            bucket: "express-promotion-docs",
            filePath: filePath,
            data: data,
            contentType: "image/jpeg"
        )

        _ = try await supabase.storage
            .from("express-promotion-docs")
            .remove(paths: [filePath])

        do {
            _ = try await supabase.storage
                .from("express-promotion-docs")
                .download(path: filePath)
            XCTFail("Download should fail after deletion")
        } catch {
            // Expected
        }
    }

    // =========================================================
    // MARK: - RLS Cross-User Isolation
    // =========================================================

    func testCannotUploadToOtherUsersFolder_profilePictures() async throws {
        let otherUserId = UUID()
        let data = makeTestJPEG()
        let filePath = "\(otherUserId.uuidString.lowercased())/malicious.jpg"

        do {
            _ = try await supabase.storage
                .from("profile-pictures")
                .upload(
                    filePath,
                    data: data,
                    options: FileOptions(contentType: "image/jpeg")
                )
            // If upload somehow succeeded, clean it up and fail
            try? await supabase.storage
                .from("profile-pictures")
                .remove(paths: [filePath])
            XCTFail("RLS should block upload to another user's folder")
        } catch {
            // Expected — RLS blocked the upload
        }
    }

    func testCannotUploadToOtherUsersFolder_pilotLicenses() async throws {
        let otherUserId = UUID()
        let data = makeTestPDF()
        let filePath = "\(otherUserId.uuidString.lowercased())/stolen_license.pdf"

        do {
            _ = try await supabase.storage
                .from("pilot-licenses")
                .upload(
                    filePath,
                    data: data,
                    options: FileOptions(contentType: "application/pdf")
                )
            try? await supabase.storage
                .from("pilot-licenses")
                .remove(paths: [filePath])
            XCTFail("RLS should block upload to another user's folder")
        } catch {
            // Expected
        }
    }

    func testCannotUploadToOtherUsersFolder_droneRegistrations() async throws {
        let otherUserId = UUID()
        let data = makeTestPDF()
        let filePath = "\(otherUserId.uuidString.lowercased())/stolen_reg.pdf"

        do {
            _ = try await supabase.storage
                .from("drone-registrations")
                .upload(
                    filePath,
                    data: data,
                    options: FileOptions(contentType: "application/pdf")
                )
            try? await supabase.storage
                .from("drone-registrations")
                .remove(paths: [filePath])
            XCTFail("RLS should block upload to another user's folder")
        } catch {
            // Expected
        }
    }

    func testCannotUploadToOtherUsersFolder_expressPromotionDocs() async throws {
        let otherUserId = UUID()
        let data = makeTestJPEG()
        let filePath = "\(otherUserId.uuidString.lowercased())/malicious_doc.jpg"

        do {
            _ = try await supabase.storage
                .from("express-promotion-docs")
                .upload(
                    filePath,
                    data: data,
                    options: FileOptions(contentType: "image/jpeg")
                )
            try? await supabase.storage
                .from("express-promotion-docs")
                .remove(paths: [filePath])
            XCTFail("RLS should block upload to another user's folder")
        } catch {
            // Expected
        }
    }

    // =========================================================
    // MARK: - Full Service Round-Trip Tests
    // =========================================================

    func testProfilePictureService_uploadRoundTrip() async throws {
        let service = ProfilePictureService()
        let size = CGSize(width: 10, height: 10)
        UIGraphicsBeginImageContext(size)
        UIColor.green.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let testImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        let publicURL = try await service.uploadProfilePicture(
            userId: TestUser.id,
            image: testImage
        )

        XCTAssertFalse(publicURL.isEmpty, "Should return a public URL")
        XCTAssertTrue(publicURL.contains("profile-pictures"), "URL should reference the bucket")
        XCTAssertTrue(publicURL.lowercased().contains(TestUser.id.uuidString.lowercased()), "URL should contain user ID")

        // Clean up: delete the uploaded file
        let filePath = "\(userFolder)/profile.jpg"
        try? await supabase.storage
            .from("profile-pictures")
            .remove(paths: [filePath])

        // Reset profile picture URL in database
        try? await supabase
            .from("profiles")
            .update(["profile_picture_url": AnyJSON.null])
            .eq("id", value: TestUser.id.uuidString)
            .execute()
    }

    func testLicenseUploadService_uploadAndFetchRoundTrip() async throws {
        let service = LicenseUploadService()
        let data = makeTestJPEG()
        let fileName = "test_\(UUID().uuidString.prefix(8)).jpg"

        let publicURL = try await service.uploadLicense(
            pilotId: TestUser.id,
            data: data,
            fileName: fileName,
            fileType: .image,
            licenseType: "Part 107 (US)"
        )

        XCTAssertFalse(publicURL.isEmpty, "Should return a public URL")
        XCTAssertTrue(publicURL.contains("pilot-licenses"))

        // Verify it appears in the fetched list
        try await service.fetchLicenses(pilotId: TestUser.id)
        let match = service.licenses.first { $0.fileUrl == publicURL }
        XCTAssertNotNil(match, "Uploaded license should appear in fetched list")
        XCTAssertEqual(match?.licenseType, "Part 107 (US)")
        XCTAssertEqual(match?.fileType, .image)

        // Clean up: delete from database and storage
        if let license = match {
            try await service.deleteLicense(license: license)
        }
    }

    func testLicenseUploadService_reviewableLicensesCreatePendingApprovalRequests() async throws {
        let service = LicenseUploadService()
        let reviewableTypes = [
            LicenseType.rpaFlightReviewer.rawValue,
            LicenseType.rocaExaminerCertificate.rawValue,
        ]

        for licenseType in reviewableTypes {
            let publicURL = try await service.uploadLicense(
                pilotId: TestUser.id,
                data: makeTestJPEG(),
                fileName: "test_\(UUID().uuidString.prefix(8)).jpg",
                fileType: .image,
                licenseType: licenseType
            )

            try await service.fetchLicenses(pilotId: TestUser.id)

            let license = try XCTUnwrap(
                service.licenses.first(where: { $0.fileUrl == publicURL }),
                "Uploaded \(licenseType) license should appear in fetched list"
            )
            let approvalRequest = try XCTUnwrap(
                service.approvalRequest(for: license.id),
                "\(licenseType) should create a matching approval request"
            )

            XCTAssertEqual(approvalRequest.licenseType, licenseType)
            XCTAssertEqual(approvalRequest.statusEnum, .pending)
            XCTAssertEqual(approvalRequest.fileUrl, publicURL)

            try await service.deleteLicense(license: license)
        }
    }

    func testDroneRegistrationService_uploadAndFetchRoundTrip() async throws {
        let service = DroneRegistrationService()
        let data = makeTestJPEG()
        let fileName = "test_\(UUID().uuidString.prefix(8)).jpg"

        let publicURL = try await service.uploadRegistration(
            pilotId: TestUser.id,
            data: data,
            fileName: fileName,
            fileType: .image
        )

        XCTAssertFalse(publicURL.isEmpty, "Should return a public URL")
        XCTAssertTrue(publicURL.contains("drone-registrations"))

        // Verify it appears in the fetched list
        try await service.fetchRegistrations(pilotId: TestUser.id)
        let match = service.registrations.first { $0.fileUrl == publicURL }
        XCTAssertNotNil(match, "Uploaded registration should appear in fetched list")
        XCTAssertEqual(match?.fileType, .image)

        // Clean up: delete from database and storage
        if let registration = match {
            try await service.deleteRegistration(registration: registration)
        }
    }
}
