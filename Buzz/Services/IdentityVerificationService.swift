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
import StripeIdentity

@MainActor
class IdentityVerificationService: ObservableObject {
    @Published var governmentID: GovernmentID?
    @Published var isLoading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    private let bucketName = "government-ids"
    
    // MARK: - Stripe Identity Verification
    
    /// Creates a Stripe VerificationSession via backend and returns the client secret
    func createVerificationSession(userId: UUID, email: String?) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        do {
            // Call Supabase Edge Function to create VerificationSession
            // The Edge Function will use Stripe's server-side API
            let requestBody: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "email": .string(email ?? "")
            ]
            
            // Call Supabase Edge Function and decode response
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
            
            // Extract client secret from response
            let clientSecret = response.client_secret
            
            isLoading = false
            return clientSecret
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            
            // If Edge Function doesn't exist, provide helpful error
            if let error = error as? NSError,
               error.localizedDescription.contains("Function not found") {
                throw NSError(
                    domain: "IdentityVerificationError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Backend verification endpoint not configured. Please set up the Supabase Edge Function 'create-verification-session'."]
                )
            }
            
            throw error
        }
    }
    
    /// Presents Stripe Identity verification flow
    func presentVerificationFlow(clientSecret: String, from viewController: UIViewController) async throws -> IdentityVerificationSheet.VerificationFlowResult {
        let verificationSheet = IdentityVerificationSheet(verificationSessionClientSecret: clientSecret)
        
        return try await withCheckedThrowingContinuation { continuation in
            verificationSheet.present(from: viewController) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Handles the Stripe Identity sheet result.
    ///
    /// The database is authoritative: `create-verification-session` has already
    /// written a 'pending' row via the service role, and `stripe-webhook` will
    /// transition it to 'verified' / 'rejected' when Stripe finishes processing.
    /// The client just refreshes its local view of the row.
    func handleVerificationResult(_ result: IdentityVerificationSheet.VerificationFlowResult, userId: UUID, sessionId: String?) async throws {
        switch result {
        case .flowCompleted:
            try await fetchGovernmentID(userId: userId)
        case .flowCanceled:
            return
        case .flowFailed(let error):
            errorMessage = error.localizedDescription
            try? await fetchGovernmentID(userId: userId)
            throw error
        @unknown default:
            throw NSError(
                domain: "IdentityVerificationError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unknown verification result"]
            )
        }
    }
    
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
    
    // MARK: - Check Verification Status

    /// Non-throwing convenience: returns false on any error.
    func isIdentityVerified(userId: UUID) async -> Bool {
        (try? await checkIdentityVerified(userId: userId)) ?? false
    }

    /// Throwing variant so callers (VerificationGate) can distinguish
    /// "not verified" from "network error" and preserve last-known state on error.
    func checkIdentityVerified(userId: UUID) async throws -> Bool {
        let ids: [GovernmentID] = try await supabase
            .from("government_ids")
            .select()
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        return ids.first?.verificationStatus == .verified
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
            // Extract file path from URL if fileUrl exists
            if let fileUrl = id.fileUrl {
                let urlComponents = URLComponents(string: fileUrl)
                let path = urlComponents?.path ?? ""
                let filePath = path.replacingOccurrences(of: "/storage/v1/object/public/\(bucketName)/", with: "")
                
                // Delete from storage
                try await supabase.storage
                    .from(bucketName)
                    .remove(paths: [filePath])
            }
            
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

