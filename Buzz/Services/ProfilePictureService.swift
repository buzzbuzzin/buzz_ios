//
//  ProfilePictureService.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import Supabase
import Combine
import UIKit

@MainActor
class ProfilePictureService: ObservableObject {
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    private let bucketName = "profile-pictures"
    
    // MARK: - Upload Profile Picture
    
    func uploadProfilePicture(userId: UUID, image: UIImage) async throws -> String {
        isUploading = true
        errorMessage = nil
        
        do {
            // Compress image
            guard let imageData = compressImage(image) else {
                throw NSError(domain: "ProfilePictureService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
            }
            
            let fileName = "\(userId.uuidString)/profile.jpg"
            
            // Upload to Supabase Storage
            let _ = try await supabase.storage
                .from(bucketName)
                .upload(
                    fileName,
                    data: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true // Replace existing file
                    )
                )
            
            // Get public URL
            let publicURL = try supabase.storage
                .from(bucketName)
                .getPublicURL(path: fileName)
            
            // Update profile with new picture URL
            try await updateProfilePicture(userId: userId, pictureUrl: publicURL.absoluteString)
            
            isUploading = false
            return publicURL.absoluteString
        } catch {
            isUploading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Update Profile Picture URL in Database
    
    private func updateProfilePicture(userId: UUID, pictureUrl: String) async throws {
        let updates: [String: AnyJSON] = [
            "profile_picture_url": .string(pictureUrl)
        ]
        
        try await supabase
            .from("profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()
    }
    
    // MARK: - Delete Profile Picture
    
    func deleteProfilePicture(userId: UUID) async throws {
        isUploading = true
        errorMessage = nil
        
        do {
            let fileName = "\(userId.uuidString)/profile.jpg"
            
            // Delete from storage
            try await supabase.storage
                .from(bucketName)
                .remove(paths: [fileName])
            
            // Update profile to remove picture URL
            let updates: [String: AnyJSON] = [
                "profile_picture_url": .null
            ]
            
            try await supabase
                .from("profiles")
                .update(updates)
                .eq("id", value: userId.uuidString)
                .execute()
            
            isUploading = false
        } catch {
            isUploading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Helper for Image Compression
    
    private func compressImage(_ image: UIImage) -> Data? {
        // Resize image to max 800x800 to save storage space
        let maxSize: CGFloat = 800
        let size = image.size
        
        var newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxSize, height: (size.height / size.width) * maxSize)
        } else {
            newSize = CGSize(width: (size.width / size.height) * maxSize, height: maxSize)
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Compress to JPEG with 0.8 quality
        return resizedImage?.jpegData(compressionQuality: 0.8)
    }
}

