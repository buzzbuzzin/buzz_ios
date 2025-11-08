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
import StripeIdentity

@MainActor
class ProfilePictureService: ObservableObject {
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var isVerifying = false
    
    private let supabase = SupabaseClient.shared.client
    private let bucketName = "profile-pictures"
    
    // MARK: - Upload Profile Picture
    
    func uploadProfilePicture(userId: UUID, image: UIImage) async throws -> String {
        isUploading = true
        errorMessage = nil
        
        do {
            // Verify authentication session is active and refresh if needed
            var session = try await supabase.auth.session
            guard session.user.id == userId else {
                throw NSError(domain: "ProfilePictureService", code: 0, userInfo: [NSLocalizedDescriptionKey: "User ID mismatch or not authenticated"])
            }
            
            // Refresh session to ensure token is valid
            do {
                session = try await supabase.auth.refreshSession()
                print("DEBUG: Session refreshed, access token present: \(session.accessToken.isEmpty ? "NO" : "YES")")
            } catch {
                print("DEBUG: Session refresh warning: \(error.localizedDescription)")
                // Continue anyway if refresh fails - session might still be valid
            }
            
            // Compress image
            guard let imageData = compressImage(image) else {
                throw NSError(domain: "ProfilePictureService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
            }
            
            let fileName = "\(userId.uuidString)/profile.jpg"
            print("DEBUG: Uploading to path: \(fileName)")
            print("DEBUG: Current auth.uid(): \(session.user.id.uuidString)")
            print("DEBUG: Access token length: \(session.accessToken.count)")
            
            // Upload to Supabase Storage
            // Try upload first, if it fails with "already exists", try update
            do {
                let _ = try await supabase.storage
                    .from(bucketName)
                    .upload(
                        fileName,
                        data: imageData,
                        options: FileOptions(
                            cacheControl: "3600",
                            contentType: "image/jpeg",
                            upsert: false
                        )
                    )
            } catch {
                // If file already exists, try to update it
                if error.localizedDescription.contains("already exists") || error.localizedDescription.contains("duplicate") {
                    print("DEBUG: File exists, attempting update...")
                    // Delete existing file first, then upload new one
                    try? await supabase.storage
                        .from(bucketName)
                        .remove(paths: [fileName])
                    
                    let _ = try await supabase.storage
                        .from(bucketName)
                        .upload(
                            fileName,
                            data: imageData,
                            options: FileOptions(
                                cacheControl: "3600",
                                contentType: "image/jpeg",
                                upsert: false
                            )
                        )
                } else {
                    throw error
                }
            }
            
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
    
    // MARK: - Selfie Verification with Stripe Identity
    
    /// Creates a Stripe VerificationSession for selfie verification
    /// This requires the user to verify their ID again with a selfie check
    func createSelfieVerificationSession(userId: UUID, email: String?) async throws -> String {
        isVerifying = true
        errorMessage = nil
        
        do {
            let requestBody: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "email": .string(email ?? ""),
                "for_profile_picture": .bool(true)
            ]
            
            struct VerificationSessionResponse: Codable {
                let client_secret: String
                let id: String?
            }
            
            let response: VerificationSessionResponse = try await supabase.functions
                .invoke(
                    "create-verification-session",
                    options: FunctionInvokeOptions(
                        body: requestBody
                    )
                )
            
            isVerifying = false
            return response.client_secret
        } catch {
            isVerifying = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Presents Stripe Identity verification flow for selfie verification
    func presentSelfieVerificationFlow(clientSecret: String, from viewController: UIViewController) async throws -> IdentityVerificationSheet.VerificationFlowResult {
        let verificationSheet = IdentityVerificationSheet(verificationSessionClientSecret: clientSecret)
        
        return try await withCheckedThrowingContinuation { continuation in
            verificationSheet.present(from: viewController) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Verifies selfie verification result and retrieves selfie from Stripe to use as profile picture
    func handleSelfieVerificationAndUpload(
        _ result: IdentityVerificationSheet.VerificationFlowResult,
        userId: UUID,
        sessionId: String?
    ) async throws {
        if case .flowCompleted = result {
            // Check verification status
            guard let sessionId = sessionId else {
                throw NSError(
                    domain: "ProfilePictureService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Verification session ID not found"]
                )
            }
            
            // Verify the selfie check passed and get selfie image
            let selfieImage = try await getSelfieFromVerification(sessionId: sessionId)
            
            if let image = selfieImage {
                // Upload profile picture after successful verification
                _ = try await uploadProfilePicture(userId: userId, image: image)
            } else {
                throw NSError(
                    domain: "ProfilePictureService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Selfie verification failed. Please ensure your selfie matches your government ID."]
                )
            }
        } else if case .flowCanceled = result {
            // User canceled - no action needed
            return
        } else if case .flowFailed(let error) = result {
            throw error
        } else {
            throw NSError(
                domain: "ProfilePictureService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unknown verification result"]
            )
        }
    }
    
    /// Retrieves the selfie image from Stripe verification report
    private func getSelfieFromVerification(sessionId: String) async throws -> UIImage? {
        struct SelfieResponse: Codable {
            let verified: Bool
            let selfie_image_url: String?
            let error: String?
        }
        
        let requestBody: [String: AnyJSON] = [
            "session_id": .string(sessionId)
        ]
        
        let response: SelfieResponse = try await supabase.functions
            .invoke(
                "get-selfie-from-verification",
                options: FunctionInvokeOptions(
                    body: requestBody
                )
            )
        
        guard response.verified, let imageUrlString = response.selfie_image_url,
              let imageUrl = URL(string: imageUrlString) else {
            if let error = response.error {
                throw NSError(
                    domain: "ProfilePictureService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: error]
                )
            }
            return nil
        }
        
        // Download image from URL
        let (data, _) = try await URLSession.shared.data(from: imageUrl)
        return UIImage(data: data)
    }
    
    /// Checks if selfie verification was successful
    private func checkSelfieVerificationStatus(sessionId: String) async throws -> Bool {
        struct VerificationStatusResponse: Codable {
            let status: String
            let stripe_status: String?
            let verified_at: Int?
            let last_error: ErrorInfo?
            
            struct ErrorInfo: Codable {
                let type: String?
                let code: String?
                let reason: String?
            }
        }
        
        let requestBody: [String: AnyJSON] = [
            "session_id": .string(sessionId)
        ]
        
        let response: VerificationStatusResponse = try await supabase.functions
            .invoke(
                "check-verification-status",
                options: FunctionInvokeOptions(
                    body: requestBody
                )
            )
        
        // Verification is successful if status is "verified"
        return response.status == "verified"
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

