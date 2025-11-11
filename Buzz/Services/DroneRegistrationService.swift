//
//  DroneRegistrationService.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import Supabase
import UIKit
import Combine

@MainActor
class DroneRegistrationService: ObservableObject {
    @Published var registrations: [DroneRegistration] = []
    @Published var isLoading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    private let bucketName = "drone-registrations"
    
    // MARK: - Upload Drone Registration
    
    func uploadRegistration(pilotId: UUID, data: Data, fileName: String, fileType: RegistrationFileType) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        do {
            // Verify authentication session
            let session = try await supabase.auth.session
            print("DEBUG DroneRegistration: Current user ID: \(session.user.id.uuidString)")
            print("DEBUG DroneRegistration: Pilot ID: \(pilotId.uuidString)")
            print("DEBUG DroneRegistration: IDs match: \(session.user.id == pilotId)")
            
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
                        domain: "DroneRegistrationService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "User profile not found. Please ensure your profile exists in the database."]
                    )
                }
                print("DEBUG DroneRegistration: Profile found for user")
            } catch {
                print("DEBUG DroneRegistration: Error checking profile: \(error.localizedDescription)")
                throw NSError(
                    domain: "DroneRegistrationService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to verify user profile: \(error.localizedDescription)"]
                )
            }
            
            let filePath = "\(pilotId.uuidString)/\(fileName)"
            print("DEBUG DroneRegistration: Uploading to path: \(filePath)")
            
            // Upload to Supabase Storage
            do {
                let _ = try await supabase.storage
                    .from(bucketName)
                    .upload(
                        filePath,
                        data: data,
                        options: FileOptions(contentType: fileType == .pdf ? "application/pdf" : "image/jpeg")
                    )
                print("DEBUG DroneRegistration: Storage upload successful")
            } catch {
                print("DEBUG DroneRegistration: Storage upload failed: \(error.localizedDescription)")
                throw NSError(
                    domain: "DroneRegistrationService",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Storage upload failed: \(error.localizedDescription). Check storage RLS policies."]
                )
            }
            
            // Get public URL
            let publicURL = try supabase.storage
                .from(bucketName)
                .getPublicURL(path: filePath)
            print("DEBUG DroneRegistration: Public URL: \(publicURL.absoluteString)")
            
            // Save registration record to database
            let registration: [String: AnyJSON] = [
                "id": .string(UUID().uuidString),
                "pilot_id": .string(pilotId.uuidString),
                "file_url": .string(publicURL.absoluteString),
                "file_type": .string(fileType.rawValue),
                "uploaded_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            
            print("DEBUG DroneRegistration: Attempting database insert...")
            do {
                try await supabase
                    .from("drone_registrations")
                    .insert(registration)
                    .execute()
                print("DEBUG DroneRegistration: Database insert successful")
            } catch {
                print("DEBUG DroneRegistration: Database insert failed: \(error.localizedDescription)")
                print("DEBUG DroneRegistration: Error details: \(error)")
                
                // Try to provide more helpful error message
                let errorMsg = error.localizedDescription
                if errorMsg.contains("row-level security") {
                    throw NSError(
                        domain: "DroneRegistrationService",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "RLS Policy Error: \(errorMsg). Ensure RLS policies allow inserts for authenticated users with matching pilot_id."]
                    )
                } else if errorMsg.contains("foreign key") {
                    throw NSError(
                        domain: "DroneRegistrationService",
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
            print("DEBUG DroneRegistration: Final error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Get Registrations for Pilot
    
    func fetchRegistrations(pilotId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let registrations: [DroneRegistration] = try await supabase
                .from("drone_registrations")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .order("uploaded_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.registrations = registrations
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
    
    // MARK: - Delete Registration
    
    func deleteRegistration(registration: DroneRegistration) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Extract file path from URL
            let urlComponents = URLComponents(string: registration.fileUrl)
            let path = urlComponents?.path ?? ""
            let filePath = path.replacingOccurrences(of: "/storage/v1/object/public/\(bucketName)/", with: "")
            
            // Delete from storage
            try await supabase.storage
                .from(bucketName)
                .remove(paths: [filePath])
            
            // Delete from database
            try await supabase
                .from("drone_registrations")
                .delete()
                .eq("id", value: registration.id.uuidString)
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

