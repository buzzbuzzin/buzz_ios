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
    private let ocrService = OCRService()
    
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
                        options: FileOptions(
                            contentType: fileType == .pdf ? "application/pdf" : "image/jpeg",
                            upsert: false
                        )
                    )
                print("DEBUG DroneRegistration: Storage upload successful")
            } catch let uploadError {
                // If file already exists, try to delete and re-upload
                if uploadError.localizedDescription.contains("already exists") || uploadError.localizedDescription.contains("duplicate") {
                    print("DEBUG DroneRegistration: File exists, attempting to remove and re-upload...")
                    do {
                        // Try to remove existing file
                        try? await supabase.storage
                            .from(bucketName)
                            .remove(paths: [filePath])
                        
                        // Upload again
                        let _ = try await supabase.storage
                            .from(bucketName)
                            .upload(
                                filePath,
                                data: data,
                                options: FileOptions(
                                    contentType: fileType == .pdf ? "application/pdf" : "image/jpeg",
                                    upsert: false
                                )
                            )
                        print("DEBUG DroneRegistration: Storage upload successful after retry")
                    } catch {
                        print("DEBUG DroneRegistration: Storage upload failed after retry: \(error.localizedDescription)")
                        throw NSError(
                            domain: "DroneRegistrationService",
                            code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "Storage upload failed: \(error.localizedDescription). Please try again with a different filename."]
                        )
                    }
                } else {
                    print("DEBUG DroneRegistration: Storage upload failed: \(uploadError.localizedDescription)")
                    throw NSError(
                        domain: "DroneRegistrationService",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Storage upload failed: \(uploadError.localizedDescription). Check storage RLS policies."]
                    )
                }
            }
            
            // Get public URL
            let publicURL = try supabase.storage
                .from(bucketName)
                .getPublicURL(path: filePath)
            print("DEBUG DroneRegistration: Public URL: \(publicURL.absoluteString)")
            
            // Perform OCR extraction
            var ocrInfo: DroneRegistrationInfo?
            do {
                print("DEBUG DroneRegistration: Starting OCR extraction...")
                let extractedText = try await ocrService.extractText(from: data, fileType: fileType)
                print("DEBUG DroneRegistration: OCR extracted text length: \(extractedText.count)")
                ocrInfo = ocrService.parseDroneRegistrationInfo(from: extractedText)
                print("DEBUG DroneRegistration: OCR parsing completed")
                if let info = ocrInfo {
                    print("DEBUG DroneRegistration: Registered Owner: \(info.registeredOwner ?? "nil")")
                    print("DEBUG DroneRegistration: Manufacturer: \(info.manufacturer ?? "nil")")
                    print("DEBUG DroneRegistration: Model: \(info.model ?? "nil")")
                    print("DEBUG DroneRegistration: Serial Number: \(info.serialNumber ?? "nil")")
                    print("DEBUG DroneRegistration: Registration Number: \(info.registrationNumber ?? "nil")")
                    print("DEBUG DroneRegistration: Issued: \(info.issued ?? "nil")")
                    print("DEBUG DroneRegistration: Expires: \(info.expires ?? "nil")")
                }
            } catch {
                print("DEBUG DroneRegistration: OCR extraction failed: \(error.localizedDescription)")
                // Continue with upload even if OCR fails
            }
            
            // Save registration record to database
            var registration: [String: AnyJSON] = [
                "id": .string(UUID().uuidString),
                "pilot_id": .string(pilotId.uuidString),
                "file_url": .string(publicURL.absoluteString),
                "file_type": .string(fileType.rawValue),
                "uploaded_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            
            // Add OCR extracted fields if available
            if let info = ocrInfo {
                if let owner = info.registeredOwner {
                    registration["registered_owner"] = .string(owner)
                }
                if let manufacturer = info.manufacturer {
                    registration["manufacturer"] = .string(manufacturer)
                }
                if let model = info.model {
                    registration["model"] = .string(model)
                }
                if let serialNumber = info.serialNumber {
                    registration["serial_number"] = .string(serialNumber)
                }
                if let registrationNumber = info.registrationNumber {
                    registration["registration_number"] = .string(registrationNumber)
                }
                if let issued = info.issued {
                    registration["issued"] = .string(issued)
                }
                if let expires = info.expires {
                    registration["expires"] = .string(expires)
                }
            }
            
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
    
    // MARK: - Update Registration OCR Fields
    
    func updateRegistrationOCRFields(
        registrationId: UUID,
        registeredOwner: String?,
        manufacturer: String?,
        model: String?,
        serialNumber: String?,
        registrationNumber: String?,
        issued: String?,
        expires: String?
    ) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            var updates: [String: AnyJSON] = [:]
            
            if let registeredOwner = registeredOwner, !registeredOwner.isEmpty {
                updates["registered_owner"] = .string(registeredOwner)
            } else {
                updates["registered_owner"] = .null
            }
            
            if let manufacturer = manufacturer, !manufacturer.isEmpty {
                updates["manufacturer"] = .string(manufacturer)
            } else {
                updates["manufacturer"] = .null
            }
            
            if let model = model, !model.isEmpty {
                updates["model"] = .string(model)
            } else {
                updates["model"] = .null
            }
            
            if let serialNumber = serialNumber, !serialNumber.isEmpty {
                updates["serial_number"] = .string(serialNumber)
            } else {
                updates["serial_number"] = .null
            }
            
            if let registrationNumber = registrationNumber, !registrationNumber.isEmpty {
                updates["registration_number"] = .string(registrationNumber)
            } else {
                updates["registration_number"] = .null
            }
            
            if let issued = issued, !issued.isEmpty {
                updates["issued"] = .string(issued)
            } else {
                updates["issued"] = .null
            }
            
            if let expires = expires, !expires.isEmpty {
                updates["expires"] = .string(expires)
            } else {
                updates["expires"] = .null
            }
            
            try await supabase
                .from("drone_registrations")
                .update(updates)
                .eq("id", value: registrationId.uuidString)
                .execute()
            
            // Refresh the registrations list
            if let registration = registrations.first(where: { $0.id == registrationId }) {
                try await fetchRegistrations(pilotId: registration.pilotId)
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

