//
//  IdentityVerificationService.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import Supabase
import UIKit
import Combine

@MainActor
class IdentityVerificationService: ObservableObject {
    @Published var governmentID: GovernmentID?
    @Published var isLoading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    private let bucketName = "government-ids"
    
    // MARK: - Upload Government ID
    
    func uploadGovernmentID(userId: UUID, data: Data, fileName: String, fileType: IDFileType) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        do {
            let filePath = "\(userId.uuidString)/\(fileName)"
            
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
            
            // Check if ID already exists
            let existingIDs: [GovernmentID] = try await supabase
                .from("government_ids")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            
            let idRecord: [String: AnyJSON] = [
                "id": .string(UUID().uuidString),
                "user_id": .string(userId.uuidString),
                "file_url": .string(publicURL.absoluteString),
                "file_type": .string(fileType.rawValue),
                "verification_status": .string(VerificationStatus.pending.rawValue),
                "uploaded_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            
            if existingIDs.isEmpty {
                // Insert new record
                try await supabase
                    .from("government_ids")
                    .insert(idRecord)
                    .execute()
            } else {
                // Update existing record
                try await supabase
                    .from("government_ids")
                    .update(idRecord)
                    .eq("user_id", value: userId.uuidString)
                    .execute()
            }
            
            isLoading = false
            return publicURL.absoluteString
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Get Government ID
    
    func fetchGovernmentID(userId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let ids: [GovernmentID] = try await supabase
                .from("government_ids")
                .select()
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            
            await MainActor.run {
                self.governmentID = ids.first
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
    
    // MARK: - Delete Government ID
    
    func deleteGovernmentID() async throws {
        guard let id = governmentID else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Extract file path from URL
            let urlComponents = URLComponents(string: id.fileUrl)
            let path = urlComponents?.path ?? ""
            let filePath = path.replacingOccurrences(of: "/storage/v1/object/public/\(bucketName)/", with: "")
            
            // Delete from storage
            try await supabase.storage
                .from(bucketName)
                .remove(paths: [filePath])
            
            // Delete from database
            try await supabase
                .from("government_ids")
                .delete()
                .eq("id", value: id.id.uuidString)
                .execute()
            
            await MainActor.run {
                self.governmentID = nil
                self.isLoading = false
            }
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

