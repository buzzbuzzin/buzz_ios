//
//  ExpressPromotionService.swift
//  Buzz
//
//  Created for Express Promotion feature
//

import Foundation
import Supabase
import UIKit
import Combine

@MainActor
class ExpressPromotionService: ObservableObject {
    @Published var applications: [ExpressPromotionApplication] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    private let bucketName = "express-promotion-docs"
    
    // MARK: - Load Applications
    
    func loadApplications(pilotId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedApplications: [ExpressPromotionApplication] = try await supabase
                .from("express_promotion_applications")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .order("submitted_at", ascending: false)
                .execute()
                .value
            
            applications = loadedApplications
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to load applications: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Submit Application
    
    func submitApplication(
        pilotId: UUID,
        promotionType: ExpressPromotionApplication.PromotionType,
        documentType: ExpressPromotionApplication.DocumentType,
        documents: [Data],
        fileNames: [String]
    ) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Upload documents to storage
            var documentUrls: [String] = []
            
            for (index, document) in documents.enumerated() {
                let fileName = fileNames[index]
                let filePath = "\(pilotId.uuidString)/\(UUID().uuidString)_\(fileName)"
                
                // Determine content type
                let contentType: String
                if fileName.lowercased().hasSuffix(".pdf") {
                    contentType = "application/pdf"
                } else {
                    contentType = "image/jpeg"
                }
                
                // Upload to storage
                _ = try await supabase.storage
                    .from(bucketName)
                    .upload(
                        filePath,
                        data: document,
                        options: FileOptions(contentType: contentType)
                    )
                
                // Get public URL
                let publicURL = try supabase.storage
                    .from(bucketName)
                    .getPublicURL(path: filePath)
                
                documentUrls.append(publicURL.absoluteString)
            }
            
            // Determine target tier
            let targetTier: Int
            switch promotionType {
            case .lieutenant:
                targetTier = 2 // Lieutenant
            case .commander:
                targetTier = 3 // Commander
            }
            
            // Create application record
            let application: [String: AnyJSON] = [
                "pilot_id": .string(pilotId.uuidString),
                "promotion_type": .string(promotionType.rawValue),
                "document_type": .string(documentType.rawValue),
                "document_urls": .array(documentUrls.map { .string($0) }),
                "status": .string("pending"),
                "target_tier": .integer(targetTier)
            ]
            
            _ = try await supabase
                .from("express_promotion_applications")
                .insert(application)
                .execute()
            
            // Reload applications
            try await loadApplications(pilotId: pilotId)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to submit application: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Check if pilot can apply
    
    func canApplyForPromotion(pilotId: UUID) async -> Bool {
        do {
            // Check if pilot already has a pending or verified application
            let existingApplications: [ExpressPromotionApplication] = try await supabase
                .from("express_promotion_applications")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .in("status", value: ["pending", "in_review", "verified"])
                .execute()
                .value
            
            return existingApplications.isEmpty
        } catch {
            print("Error checking application eligibility: \(error)")
            return false
        }
    }
    
    // MARK: - Check if pilot has Lieutenant promotion via Express Promotion
    
    func hasLieutenantPromotion(pilotId: UUID) async -> Bool {
        do {
            let applications: [ExpressPromotionApplication] = try await supabase
                .from("express_promotion_applications")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("promotion_type", value: "lieutenant")
                .eq("status", value: "verified")
                .execute()
                .value
            
            return !applications.isEmpty
        } catch {
            print("Error checking Lieutenant promotion: \(error)")
            return false
        }
    }
    
    // MARK: - Check Ground School Test Status
    
    func checkGroundSchoolTestStatus(pilotId: UUID) async throws -> Bool {
        // UAS Pilot Course ID
        let uasCourseId = UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-ef1234567890")!
        
        do {
            let response = try await supabase
                .from("test_results")
                .select("passed")
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("course_id", value: uasCourseId.uuidString)
                .execute()
            
            guard let jsonArray = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]],
                  let firstResult = jsonArray.first,
                  let passed = firstResult["passed"] as? Bool else {
                return false
            }
            
            return passed
        } catch {
            print("Error checking Ground School Test status: \(error)")
            return false
        }
    }
    
    // MARK: - Automatically promote to Commander
    
    func autoPromoteToCommander(pilotId: UUID) async throws {
        // Check if pilot has Lieutenant promotion
        guard await hasLieutenantPromotion(pilotId: pilotId) else {
            throw NSError(
                domain: "ExpressPromotionService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Must be promoted to Lieutenant via Express Promotion first"]
            )
        }
        
        // Check if pilot passed Ground School Test
        guard try await checkGroundSchoolTestStatus(pilotId: pilotId) else {
            throw NSError(
                domain: "ExpressPromotionService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Must pass Ground School Test first"]
            )
        }
        
        // Check if Commander application already exists
        let existingApplications: [ExpressPromotionApplication] = try await supabase
            .from("express_promotion_applications")
            .select()
            .eq("pilot_id", value: pilotId.uuidString)
            .eq("promotion_type", value: "commander")
            .execute()
            .value
        
        if existingApplications.isEmpty {
            // Create automatic Commander application
            let application: [String: AnyJSON] = [
                "pilot_id": .string(pilotId.uuidString),
                "promotion_type": .string("commander"),
                "document_type": .string("ground_school_test"),
                "document_urls": .array([]),
                "status": .string("verified"),
                "target_tier": .integer(3)
            ]
            
            _ = try await supabase
                .from("express_promotion_applications")
                .insert(application)
                .execute()
        } else {
            // Update existing application to verified
            let now = Date()
            _ = try await supabase
                .from("express_promotion_applications")
                .update([
                    "status": "verified",
                    "reviewed_at": AnyJSON.string(ISO8601DateFormatter().string(from: now)),
                    "updated_at": AnyJSON.string(ISO8601DateFormatter().string(from: now))
                ])
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("promotion_type", value: "commander")
                .execute()
        }
        
        // Update pilot tier to Commander (3)
        let now = Date()
        _ = try await supabase
            .from("pilot_stats")
            .update([
                "tier": 3,
                "updated_at": AnyJSON.string(ISO8601DateFormatter().string(from: now))
            ])
            .eq("pilot_id", value: pilotId.uuidString)
            .execute()
        
        // Reload applications
        try await loadApplications(pilotId: pilotId)
    }
    
    // MARK: - Withdraw Application
    
    func withdrawApplication(applicationId: UUID, pilotId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Only allow withdrawal if status is pending or in_review
            // Delete the application record
            _ = try await supabase
                .from("express_promotion_applications")
                .delete()
                .eq("id", value: applicationId.uuidString)
                .eq("pilot_id", value: pilotId.uuidString)
                .in("status", value: ["pending", "in_review"])
                .execute()
            
            // Reload applications
            try await loadApplications(pilotId: pilotId)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to withdraw application: \(error.localizedDescription)"
            throw error
        }
    }
}

