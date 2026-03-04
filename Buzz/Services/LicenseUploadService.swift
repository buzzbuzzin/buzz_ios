//
//  LicenseUploadService.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import Foundation
import Supabase
import UIKit
import Combine

@MainActor
class LicenseUploadService: ObservableObject {
    @Published var licenses: [PilotLicense] = []
    @Published var approvalRequests: [LicenseApprovalRequest] = []
    @Published var isLoading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    private let bucketName = "pilot-licenses"
    private let ocrService = OCRService()
    
    // MARK: - Upload License
    
    func uploadLicense(pilotId: UUID, data: Data, fileName: String, fileType: LicenseFileType, licenseType: String? = nil) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        do {
            // Verify authentication session
            let session = try await supabase.auth.session
            print("DEBUG LicenseUpload: Current user ID: \(session.user.id.uuidString)")
            print("DEBUG LicenseUpload: Pilot ID: \(pilotId.uuidString)")
            print("DEBUG LicenseUpload: IDs match: \(session.user.id == pilotId)")
            
            // Verify user has a profile (required for foreign key)
            do {
                let profile: UserProfile? = try await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: pilotId.uuidString)
                    .single()
                    .execute()
                    .value
                
                if profile == nil {
                    throw NSError(
                        domain: "LicenseUploadService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "User profile not found. Please ensure your profile exists in the database."]
                    )
                }
                print("DEBUG LicenseUpload: Profile found for user")
            } catch {
                print("DEBUG LicenseUpload: Error checking profile: \(error.localizedDescription)")
                throw NSError(
                    domain: "LicenseUploadService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to verify user profile: \(error.localizedDescription)"]
                )
            }
            
            let filePath = "\(pilotId.uuidString.lowercased())/\(fileName)"
            print("DEBUG LicenseUpload: Uploading to path: \(filePath)")
            
            // Upload to Supabase Storage
            do {
                let _ = try await supabase.storage
                    .from(bucketName)
                    .upload(
                        filePath,
                        data: data,
                        options: FileOptions(contentType: fileType == .pdf ? "application/pdf" : "image/jpeg")
                    )
                print("DEBUG LicenseUpload: Storage upload successful")
            } catch {
                print("DEBUG LicenseUpload: Storage upload failed: \(error.localizedDescription)")
                throw NSError(
                    domain: "LicenseUploadService",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Storage upload failed: \(error.localizedDescription). Check storage RLS policies."]
                )
            }
            
            // Get public URL
            let publicURL = try supabase.storage
                .from(bucketName)
                .getPublicURL(path: filePath)
            print("DEBUG LicenseUpload: Public URL: \(publicURL.absoluteString)")
            
            // Perform OCR extraction
            var ocrInfo: PilotLicenseInfo?
            do {
                print("DEBUG LicenseUpload: ========================================")
                print("DEBUG LicenseUpload: Starting OCR extraction...")
                print("DEBUG LicenseUpload: File type: \(fileType.rawValue)")
                print("DEBUG LicenseUpload: File data size: \(data.count) bytes")
                
                // Convert LicenseFileType to RegistrationFileType for OCR service
                let registrationFileType: RegistrationFileType = fileType == .pdf ? .pdf : .image
                let extractedText = try await ocrService.extractText(from: data, fileType: registrationFileType)
                
                print("DEBUG LicenseUpload: OCR extraction successful!")
                print("DEBUG LicenseUpload: Extracted text length: \(extractedText.count) characters")
                print("DEBUG LicenseUpload: Full extracted text:")
                print("----------------------------------------")
                print(extractedText)
                print("----------------------------------------")
                
                ocrInfo = ocrService.parsePilotLicenseInfo(from: extractedText, licenseType: licenseType)
                print("DEBUG LicenseUpload: OCR parsing completed")
                
                if let info = ocrInfo {
                    print("DEBUG LicenseUpload: Parsed results:")
                    print("   - Name: \(info.name ?? "nil")")
                    print("   - Course Completed: \(info.courseCompleted ?? "nil")")
                    print("   - Completion Date: \(info.completionDate ?? "nil")")
                    print("   - Certificate Number: \(info.certificateNumber ?? "nil")")
                } else {
                    print("DEBUG LicenseUpload: WARNING: ocrInfo is nil after parsing")
                }
                print("DEBUG LicenseUpload: ========================================")
            } catch {
                print("DEBUG LicenseUpload: ========================================")
                print("DEBUG LicenseUpload: OCR extraction failed!")
                print("DEBUG LicenseUpload: Error: \(error.localizedDescription)")
                print("DEBUG LicenseUpload: Error details: \(error)")
                print("DEBUG LicenseUpload: ========================================")
                // Continue with upload even if OCR fails
            }
            
            // Save license record to database
            let licenseId = UUID()
            var license: [String: AnyJSON] = [
                "id": .string(licenseId.uuidString),
                "pilot_id": .string(pilotId.uuidString),
                "file_url": .string(publicURL.absoluteString),
                "file_type": .string(fileType.rawValue),
                "uploaded_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]

            // Add license type if provided
            if let licenseType = licenseType, !licenseType.isEmpty {
                license["license_type"] = .string(licenseType)
            }
            
            // Add OCR extracted fields if available
            if let info = ocrInfo {
                print("DEBUG LicenseUpload: Adding OCR fields to database record...")
                if let name = info.name {
                    license["name"] = .string(name)
                    print("DEBUG LicenseUpload: Added name: \(name)")
                }
                if let courseCompleted = info.courseCompleted {
                    license["course_completed"] = .string(courseCompleted)
                    print("DEBUG LicenseUpload: Added course_completed: \(courseCompleted)")
                }
                if let completionDate = info.completionDate {
                    license["completion_date"] = .string(completionDate)
                    print("DEBUG LicenseUpload: Added completion_date: \(completionDate)")
                }
                if let certificateNumber = info.certificateNumber {
                    license["certificate_number"] = .string(certificateNumber)
                    print("DEBUG LicenseUpload: Added certificate_number: \(certificateNumber)")
                }
            } else {
                print("DEBUG LicenseUpload: No OCR info available, skipping OCR fields")
            }
            
            print("DEBUG LicenseUpload: Attempting database insert...")
            print("DEBUG LicenseUpload: License record keys: \(license.keys.sorted())")
            do {
                try await supabase
                    .from("pilot_licenses")
                    .insert(license)
                    .execute()
                print("DEBUG LicenseUpload: Database insert successful")
            } catch {
                print("DEBUG LicenseUpload: Database insert failed: \(error.localizedDescription)")
                print("DEBUG LicenseUpload: Error details: \(error)")

                // Try to provide more helpful error message
                let errorMsg = error.localizedDescription
                if errorMsg.contains("row-level security") {
                    throw NSError(
                        domain: "LicenseUploadService",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "RLS Policy Error: \(errorMsg). Ensure RLS policies allow inserts for authenticated users with matching pilot_id."]
                    )
                } else if errorMsg.contains("foreign key") {
                    throw NSError(
                        domain: "LicenseUploadService",
                        code: -4,
                        userInfo: [NSLocalizedDescriptionKey: "Foreign Key Error: \(errorMsg). Ensure your profile exists in the profiles table."]
                    )
                } else {
                    throw error
                }
            }

            // Insert approval request for reviewable license types (separate do-catch
            // so a failure here doesn't orphan the already-inserted license record)
            if let licenseType = licenseType,
               (licenseType == LicenseType.rpaFlightReviewer.rawValue ||
                licenseType == LicenseType.rocaExaminerCertificate.rawValue) {
                do {
                    let approvalRequest: [String: AnyJSON] = [
                        "pilot_id": .string(pilotId.uuidString),
                        "license_id": .string(licenseId.uuidString),
                        "license_type": .string(licenseType),
                        "file_url": .string(publicURL.absoluteString),
                        "status": .string("pending"),
                    ]
                    try await supabase
                        .from("license_approval_requests")
                        .insert(approvalRequest)
                        .execute()
                    print("DEBUG LicenseUpload: Approval request inserted")
                } catch {
                    print("DEBUG LicenseUpload: Approval request insert failed: \(error.localizedDescription)")
                    print("DEBUG LicenseUpload: Error details: \(error)")
                    // License record exists — don't throw, so the upload is still considered successful.
                    // The approval request can be re-created manually or on next upload.
                }
            }
            
            isLoading = false
            return publicURL.absoluteString
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            print("DEBUG LicenseUpload: Final error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Get Licenses for Pilot
    
    func fetchLicenses(pilotId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        print("DEBUG LicenseUpload: Fetching licenses for pilot: \(pilotId.uuidString)")
        
        do {
            let licenses: [PilotLicense] = try await supabase
                .from("pilot_licenses")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .order("uploaded_at", ascending: false)
                .execute()
                .value
            
            print("DEBUG LicenseUpload: Successfully fetched \(licenses.count) license(s)")
            for (index, license) in licenses.enumerated() {
                print("DEBUG LicenseUpload: License \(index + 1):")
                print("   - ID: \(license.id)")
                print("   - Name: \(license.name ?? "nil")")
                print("   - Course Completed: \(license.courseCompleted ?? "nil")")
                print("   - Completion Date: \(license.completionDate ?? "nil")")
                print("   - Certificate Number: \(license.certificateNumber ?? "nil")")
                print("   - File URL: \(license.fileUrl)")
            }
            
            // Fetch associated approval requests
            let requests: [LicenseApprovalRequest] = try await supabase
                .from("license_approval_requests")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .order("submitted_at", ascending: false)
                .execute()
                .value

            await MainActor.run {
                self.licenses = licenses
                self.approvalRequests = requests
                self.isLoading = false
            }
        } catch {
            print("DEBUG LicenseUpload: Failed to fetch licenses: \(error.localizedDescription)")
            print("DEBUG LicenseUpload: Error details: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Approval Requests

    func approvalRequest(for licenseId: UUID) -> LicenseApprovalRequest? {
        approvalRequests.first(where: { $0.licenseId == licenseId })
    }

    // MARK: - Delete License
    
    func deleteLicense(license: PilotLicense) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Extract file path from URL
            let urlComponents = URLComponents(string: license.fileUrl)
            let path = urlComponents?.path ?? ""
            let filePath = path.replacingOccurrences(of: "/storage/v1/object/public/\(bucketName)/", with: "")
            
            // Delete from storage
            try await supabase.storage
                .from(bucketName)
                .remove(paths: [filePath])
            
            // Delete from database
            try await supabase
                .from("pilot_licenses")
                .delete()
                .eq("id", value: license.id.uuidString)
                .execute()
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Update License OCR Fields
    
    func updateLicenseOCRFields(
        licenseId: UUID,
        name: String?,
        courseCompleted: String?,
        completionDate: String?,
        certificateNumber: String?
    ) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            var updates: [String: AnyJSON] = [:]
            
            if let name = name, !name.isEmpty {
                updates["name"] = .string(name)
            } else {
                updates["name"] = .null
            }
            
            if let courseCompleted = courseCompleted, !courseCompleted.isEmpty {
                updates["course_completed"] = .string(courseCompleted)
            } else {
                updates["course_completed"] = .null
            }
            
            if let completionDate = completionDate, !completionDate.isEmpty {
                updates["completion_date"] = .string(completionDate)
            } else {
                updates["completion_date"] = .null
            }
            
            if let certificateNumber = certificateNumber, !certificateNumber.isEmpty {
                updates["certificate_number"] = .string(certificateNumber)
            } else {
                updates["certificate_number"] = .null
            }
            
            try await supabase
                .from("pilot_licenses")
                .update(updates)
                .eq("id", value: licenseId.uuidString)
                .execute()
            
            // Refresh the licenses list
            if let license = licenses.first(where: { $0.id == licenseId }) {
                try await fetchLicenses(pilotId: license.pilotId)
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Compress Image
    
    func compressImage(_ image: UIImage, maxSizeInBytes: Int = 2_000_000) -> Data? {
        var compression: CGFloat = 1.0
        var imageData = image.jpegData(compressionQuality: compression)
        
        while let data = imageData, data.count > maxSizeInBytes && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }
        
        return imageData
    }
}

