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
    
    /// Handles verification result and updates database
    func handleVerificationResult(_ result: IdentityVerificationSheet.VerificationFlowResult, userId: UUID, sessionId: String?) async throws {
        if case .flowCompleted = result {
            // Flow completed - but we need to check actual verification status
            // Stripe processes verification asynchronously, so we check the status
            guard let sessionId = sessionId else {
                // If no session ID, mark as pending
                try await updateVerificationStatus(
                    userId: userId,
                    status: .pending,
                    stripeSessionId: nil
                )
                try await fetchGovernmentID(userId: userId)
                return
            }
            
            // Check the actual verification status from Stripe
            let actualStatus = try await checkVerificationStatus(sessionId: sessionId)
            
            // Update database with actual verification status
            try await updateVerificationStatus(
                userId: userId,
                status: actualStatus,
                stripeSessionId: sessionId
            )
            
            // Reload government ID
            try await fetchGovernmentID(userId: userId)
            
        } else if case .flowCanceled = result {
            // User canceled - no action needed
            return
        } else if case .flowFailed(let error) = result {
            // Verification flow failed
            errorMessage = error.localizedDescription
            
            // Mark as rejected if we have a session ID
            if let sessionId = sessionId {
                try await updateVerificationStatus(
                    userId: userId,
                    status: .rejected,
                    stripeSessionId: sessionId
                )
                try await fetchGovernmentID(userId: userId)
            }
            
            throw error
        } else {
            throw NSError(
                domain: "IdentityVerificationError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unknown verification result"]
            )
        }
    }
    
    /// Checks the actual verification status from Stripe
    private func checkVerificationStatus(sessionId: String) async throws -> VerificationStatus {
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
        
        // Map Stripe status to our VerificationStatus enum
        switch response.status {
        case "verified":
            return .verified
        case "rejected":
            return .rejected
        default:
            return .pending
        }
    }
    
    /// Updates verification status in database
    private func updateVerificationStatus(userId: UUID, status: VerificationStatus, stripeSessionId: String?) async throws {
        var updateData: [String: AnyJSON] = [
            "verification_status": .string(status.rawValue)
        ]
        
        if let sessionId = stripeSessionId {
            updateData["stripe_session_id"] = .string(sessionId)
        }
        
        // Check if record exists
        let existingIDs: [GovernmentID] = try await supabase
            .from("government_ids")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        if existingIDs.isEmpty {
            // Create new record
            var newRecord: [String: AnyJSON] = [
                "id": .string(UUID().uuidString),
                "user_id": .string(userId.uuidString),
                "verification_status": .string(status.rawValue),
                "uploaded_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            
            if let sessionId = stripeSessionId {
                newRecord["stripe_session_id"] = .string(sessionId)
            }
            
            try await supabase
                .from("government_ids")
                .insert(newRecord)
                .execute()
        } else {
            // Update existing record
            try await supabase
                .from("government_ids")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .execute()
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
    
    /// Checks if the user's identity is verified
    func isIdentityVerified(userId: UUID) async -> Bool {
        do {
            let ids: [GovernmentID] = try await supabase
                .from("government_ids")
                .select()
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            
            if let id = ids.first {
                return id.verificationStatus == .verified
            }
            return false
        } catch {
            return false
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

