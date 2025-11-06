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
            let filePath = "\(pilotId.uuidString)/\(fileName)"
            
            // Upload to Supabase Storage
            let _ = try await supabase.storage
                .from(bucketName)
                .upload(
                    filePath,
                    data: data,
                    options: FileOptions(contentType: fileType == .pdf ? "application/pdf" : "image/jpeg")
                )
            
            // Get public URL
            let publicURL = try supabase.storage
                .from(bucketName)
                .getPublicURL(path: filePath)
            
            // Save registration record to database
            let registration: [String: AnyJSON] = [
                "id": .string(UUID().uuidString),
                "pilot_id": .string(pilotId.uuidString),
                "file_url": .string(publicURL.absoluteString),
                "file_type": .string(fileType.rawValue),
                "uploaded_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            
            try await supabase
                .from("drone_registrations")
                .insert(registration)
                .execute()
            
            isLoading = false
            return publicURL.absoluteString
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
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

