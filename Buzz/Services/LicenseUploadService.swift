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
    @Published var isLoading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    private let bucketName = "pilot-licenses"
    
    // MARK: - Upload License
    
    func uploadLicense(pilotId: UUID, data: Data, fileName: String, fileType: LicenseFileType) async throws -> String {
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
            
            let filePath = "\(pilotId.uuidString)/\(fileName)"
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
            
            // Save license record to database
            let license: [String: AnyJSON] = [
                "id": .string(UUID().uuidString),
                "pilot_id": .string(pilotId.uuidString),
                "file_url": .string(publicURL.absoluteString),
                "file_type": .string(fileType.rawValue),
                "uploaded_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            
            print("DEBUG LicenseUpload: Attempting database insert...")
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
        
        do {
            let licenses: [PilotLicense] = try await supabase
                .from("pilot_licenses")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .order("uploaded_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.licenses = licenses
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
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

