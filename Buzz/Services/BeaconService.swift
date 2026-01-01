//
//  BeaconService.swift
//  Buzz
//
//  Created by Xinyu Fang on 12/31/24.
//

import Foundation
import Supabase
import Combine
import UIKit

@MainActor
class BeaconService: ObservableObject {
    @Published var trainingProgress: [BeaconTrainingProgress] = []
    @Published var volunteerStatus: BeaconVolunteer?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    
    // MARK: - Training Progress
    
    /// Get all training progress for a user
    func getTrainingProgress(userId: UUID) async throws -> [BeaconTrainingProgress] {
        let progress: [BeaconTrainingProgress] = try await supabase
            .from("beacon_training_progress")
            .select()
            .eq("pilot_id", value: userId.uuidString)
            .execute()
            .value
        
        await MainActor.run {
            self.trainingProgress = progress
        }
        
        return progress
    }
    
    /// Check if a specific training type is completed
    func isTrainingCompleted(userId: UUID, trainingType: BeaconTrainingType) async throws -> Bool {
        let progress = try await getTrainingProgress(userId: userId)
        return progress.contains { $0.trainingType == trainingType }
    }
    
    /// Check if all required training is completed
    func isAllTrainingCompleted(userId: UUID) async throws -> Bool {
        let progress = try await getTrainingProgress(userId: userId)
        let completedTypes = Set(progress.map { $0.trainingType })
        let requiredTypes = Set(BeaconTrainingType.allCases)
        return completedTypes == requiredTypes
    }
    
    /// Upload a training certificate
    func uploadTrainingCertificate(
        userId: UUID,
        trainingType: BeaconTrainingType,
        data: Data,
        fileName: String,
        isPDF: Bool
    ) async throws -> BeaconTrainingProgress {
        isLoading = true
        defer { isLoading = false }
        
        // Generate unique file path - user ID must come right after folder for RLS policy
        let uniqueFileName = "\(trainingType.rawValue)_\(Date().timeIntervalSince1970)_\(fileName)"
        let filePath = "beacon-certificates/\(userId.uuidString)/\(uniqueFileName)"
        
        // Determine content type
        let contentType = isPDF ? "application/pdf" : "image/jpeg"
        
        // Upload to storage
        try await supabase.storage
            .from("certificates")
            .upload(
                path: filePath,
                file: data,
                options: FileOptions(contentType: contentType)
            )
        
        // Get public URL
        let publicUrl = try supabase.storage
            .from("certificates")
            .getPublicURL(path: filePath)
        
        // Insert training progress record
        let trainingRecord: [String: AnyJSON] = [
            "pilot_id": .string(userId.uuidString),
            "training_type": .string(trainingType.rawValue),
            "certificate_url": .string(publicUrl.absoluteString)
        ]
        
        let insertedProgress: BeaconTrainingProgress = try await supabase
            .from("beacon_training_progress")
            .upsert(trainingRecord, onConflict: "pilot_id,training_type")
            .select()
            .single()
            .execute()
            .value
        
        // Update local state
        await MainActor.run {
            if let index = self.trainingProgress.firstIndex(where: { $0.trainingType == trainingType }) {
                self.trainingProgress[index] = insertedProgress
            } else {
                self.trainingProgress.append(insertedProgress)
            }
        }
        
        return insertedProgress
    }
    
    // MARK: - Volunteer Status
    
    /// Check if user is a beacon volunteer
    func isUserBeaconVolunteer(userId: UUID) async throws -> Bool {
        do {
            let _: BeaconVolunteer = try await supabase
                .from("beacon_volunteers")
                .select()
                .eq("pilot_id", value: userId.uuidString)
                .single()
                .execute()
                .value
            return true
        } catch {
            return false
        }
    }
    
    /// Get volunteer status for a user
    func getVolunteerStatus(userId: UUID) async throws -> BeaconVolunteer? {
        do {
            let volunteer: BeaconVolunteer = try await supabase
                .from("beacon_volunteers")
                .select()
                .eq("pilot_id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                self.volunteerStatus = volunteer
            }
            
            return volunteer
        } catch {
            return nil
        }
    }
    
    /// Enroll user as a beacon volunteer (after completing all training)
    func enrollAsVolunteer(userId: UUID) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Verify all training is complete
        guard try await isAllTrainingCompleted(userId: userId) else {
            throw BeaconError.trainingIncomplete
        }
        
        // Use the database function to enroll
        try await supabase
            .rpc("enroll_beacon_volunteer", params: ["p_pilot_id": userId.uuidString])
            .execute()
        
        // Refresh volunteer status
        _ = try await getVolunteerStatus(userId: userId)
        
        // Note: Badge is automatically awarded via database trigger
        // See migration: 20260101_add_beacon_volunteer_badge.sql
    }
    
    /// Update volunteer availability
    func updateAvailability(userId: UUID, isAvailable: Bool) async throws {
        try await supabase
            .from("beacon_volunteers")
            .update(["is_available": isAvailable])
            .eq("pilot_id", value: userId.uuidString)
            .execute()
        
        await MainActor.run {
            self.volunteerStatus?.isAvailable = isAvailable
        }
    }
    
    /// Update volunteer location
    func updateLocation(userId: UUID, lat: Double, lng: Double) async throws {
        let updates: [String: AnyJSON] = [
            "last_location_lat": .double(lat),
            "last_location_lng": .double(lng),
            "last_location_update": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        
        try await supabase
            .from("beacon_volunteers")
            .update(updates)
            .eq("pilot_id", value: userId.uuidString)
            .execute()
    }
    
    /// Update notification radius
    func updateNotificationRadius(userId: UUID, radiusMiles: Int) async throws {
        try await supabase
            .from("beacon_volunteers")
            .update(["notification_radius_miles": radiusMiles])
            .eq("pilot_id", value: userId.uuidString)
            .execute()
        
        await MainActor.run {
            self.volunteerStatus?.notificationRadiusMiles = radiusMiles
        }
    }
    
    // MARK: - Emergency Dispatch
    
    /// Find nearby volunteers for emergency dispatch
    func findNearbyVolunteers(lat: Double, lng: Double, radiusMiles: Int = 25) async throws -> [NearbyVolunteer] {
        let volunteers: [NearbyVolunteer] = try await supabase
            .rpc("find_nearby_beacon_volunteers", params: [
                "p_lat": lat,
                "p_lng": lng,
                "p_radius_miles": Double(radiusMiles)
            ])
            .execute()
            .value
        
        return volunteers
    }
}

// MARK: - Nearby Volunteer Model

struct NearbyVolunteer: Codable, Identifiable {
    let volunteerId: UUID
    let pilotId: UUID
    let distanceMiles: Double
    let notificationRadiusMiles: Int
    
    var id: UUID { volunteerId }
    
    enum CodingKeys: String, CodingKey {
        case volunteerId = "volunteer_id"
        case pilotId = "pilot_id"
        case distanceMiles = "distance_miles"
        case notificationRadiusMiles = "notification_radius_miles"
    }
}

// MARK: - Beacon Errors

enum BeaconError: LocalizedError {
    case trainingIncomplete
    case uploadFailed
    case enrollmentFailed
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .trainingIncomplete:
            return "Please complete all required training before enrolling as a volunteer."
        case .uploadFailed:
            return "Failed to upload certificate. Please try again."
        case .enrollmentFailed:
            return "Failed to enroll as volunteer. Please try again."
        case .notFound:
            return "Volunteer record not found."
        }
    }
}

