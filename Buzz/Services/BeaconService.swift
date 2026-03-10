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

// MARK: - BeaconBackend Protocol

protocol BeaconBackend {
    func syncBadgesToTraining(userId: UUID) async throws
    func getTrainingProgress(userId: UUID) async throws -> [BeaconTrainingProgress]
    func uploadTrainingCertificate(userId: UUID, trainingType: BeaconTrainingType, data: Data, fileName: String, isPDF: Bool, expiresAt: Date) async throws -> BeaconTrainingProgress
    func updateTrainingExpiration(userId: UUID, trainingType: BeaconTrainingType, expiresAt: Date) async throws -> BeaconTrainingProgress
    func isUserBeaconVolunteer(userId: UUID) async throws -> Bool
    func getVolunteerStatus(userId: UUID) async throws -> BeaconVolunteer?
    func enrollAsVolunteer(userId: UUID) async throws
    func updateAvailability(userId: UUID, isAvailable: Bool) async throws
    func updateLocation(userId: UUID, lat: Double, lng: Double) async throws
    func updateNotificationRadius(userId: UUID, radiusMiles: Int) async throws
    func findNearbyVolunteers(lat: Double, lng: Double, radiusMiles: Int) async throws -> [NearbyVolunteer]
}

// MARK: - Supabase Implementation

private struct SupabaseBeaconBackend: BeaconBackend {
    private let client = SupabaseClient.shared.client

    func syncBadgesToTraining(userId: UUID) async throws {
        try await client
            .rpc("sync_badges_to_beacon_training", params: ["p_pilot_id": userId.uuidString])
            .execute()
    }

    func getTrainingProgress(userId: UUID) async throws -> [BeaconTrainingProgress] {
        try await client
            .from("beacon_training_progress")
            .select()
            .eq("pilot_id", value: userId.uuidString)
            .execute()
            .value
    }

    func uploadTrainingCertificate(userId: UUID, trainingType: BeaconTrainingType, data: Data, fileName: String, isPDF: Bool, expiresAt: Date) async throws -> BeaconTrainingProgress {
        // Generate unique file path - user ID must come right after folder for RLS policy
        let uniqueFileName = "\(trainingType.rawValue)_\(Date().timeIntervalSince1970)_\(fileName)"
        let filePath = "beacon-certificates/\(userId.uuidString)/\(uniqueFileName)"

        // Determine content type
        let contentType = isPDF ? "application/pdf" : "image/jpeg"

        // Upload to storage
        try await client.storage
            .from("certificates")
            .upload(
                path: filePath,
                file: data,
                options: FileOptions(contentType: contentType)
            )

        // Get public URL
        let publicUrl = try client.storage
            .from("certificates")
            .getPublicURL(path: filePath)

        // Insert training progress record
        let trainingRecord: [String: AnyJSON] = [
            "pilot_id": .string(userId.uuidString),
            "training_type": .string(trainingType.rawValue),
            "certificate_url": .string(publicUrl.absoluteString),
            "uploaded_at": .string(ISO8601DateFormatter().string(from: Date())),
            "expires_at": .string(ISO8601DateFormatter().string(from: expiresAt))
        ]

        return try await client
            .from("beacon_training_progress")
            .upsert(trainingRecord, onConflict: "pilot_id,training_type")
            .select()
            .single()
            .execute()
            .value
    }

    func updateTrainingExpiration(userId: UUID, trainingType: BeaconTrainingType, expiresAt: Date) async throws -> BeaconTrainingProgress {
        let updates: [String: AnyJSON] = [
            "expires_at": .string(ISO8601DateFormatter().string(from: expiresAt))
        ]

        return try await client
            .from("beacon_training_progress")
            .update(updates)
            .eq("pilot_id", value: userId.uuidString)
            .eq("training_type", value: trainingType.rawValue)
            .select()
            .single()
            .execute()
            .value
    }

    func isUserBeaconVolunteer(userId: UUID) async throws -> Bool {
        do {
            let _: BeaconVolunteer = try await client
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

    func getVolunteerStatus(userId: UUID) async throws -> BeaconVolunteer? {
        do {
            let volunteer: BeaconVolunteer = try await client
                .from("beacon_volunteers")
                .select()
                .eq("pilot_id", value: userId.uuidString)
                .single()
                .execute()
                .value
            return volunteer
        } catch {
            return nil
        }
    }

    func enrollAsVolunteer(userId: UUID) async throws {
        try await client
            .rpc("enroll_beacon_volunteer", params: ["p_pilot_id": userId.uuidString])
            .execute()
    }

    func updateAvailability(userId: UUID, isAvailable: Bool) async throws {
        try await client
            .from("beacon_volunteers")
            .update(["is_available": isAvailable])
            .eq("pilot_id", value: userId.uuidString)
            .execute()
    }

    func updateLocation(userId: UUID, lat: Double, lng: Double) async throws {
        let updates: [String: AnyJSON] = [
            "last_location_lat": .double(lat),
            "last_location_lng": .double(lng),
            "last_location_update": .string(ISO8601DateFormatter().string(from: Date()))
        ]

        try await client
            .from("beacon_volunteers")
            .update(updates)
            .eq("pilot_id", value: userId.uuidString)
            .execute()
    }

    func updateNotificationRadius(userId: UUID, radiusMiles: Int) async throws {
        try await client
            .from("beacon_volunteers")
            .update(["notification_radius_miles": radiusMiles])
            .eq("pilot_id", value: userId.uuidString)
            .execute()
    }

    func findNearbyVolunteers(lat: Double, lng: Double, radiusMiles: Int) async throws -> [NearbyVolunteer] {
        try await client
            .rpc("find_nearby_beacon_volunteers", params: [
                "p_lat": lat,
                "p_lng": lng,
                "p_radius_miles": Double(radiusMiles)
            ])
            .execute()
            .value
    }
}

// MARK: - BeaconService

@MainActor
class BeaconService: ObservableObject {
    @Published var trainingProgress: [BeaconTrainingProgress] = []
    @Published var volunteerStatus: BeaconVolunteer?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let backend: BeaconBackend
    private var hasSyncedBadges = false

    init(backend: BeaconBackend? = nil) {
        self.backend = backend ?? SupabaseBeaconBackend()
    }

    // MARK: - Training Progress

    /// Sync existing badges to training progress records
    /// This allows pilots who already earned badges to have training requirements fulfilled
    func syncBadgesToTraining(userId: UUID) async throws {
        try await backend.syncBadgesToTraining(userId: userId)
        hasSyncedBadges = true
    }

    /// Get all training progress for a user
    func getTrainingProgress(userId: UUID) async throws -> [BeaconTrainingProgress] {
        // Only sync badges once per session to avoid redundant RPC calls
        if !hasSyncedBadges {
            try await syncBadgesToTraining(userId: userId)
        }

        let progress = try await backend.getTrainingProgress(userId: userId)

        self.trainingProgress = progress
        return progress
    }
    
    /// Check if a specific training type is completed
    func isTrainingCompleted(userId: UUID, trainingType: BeaconTrainingType) async throws -> Bool {
        let progress = try await getTrainingProgress(userId: userId)
        return progress.contains { $0.trainingType == trainingType && $0.isCurrent }
    }
    
    /// Check if all required training is completed
    func isAllTrainingCompleted(userId: UUID) async throws -> Bool {
        let progress = try await getTrainingProgress(userId: userId)
        return hasCurrentTrainingQualifications(progress)
    }
    
    /// Upload a training certificate
    func uploadTrainingCertificate(
        userId: UUID,
        trainingType: BeaconTrainingType,
        data: Data,
        fileName: String,
        isPDF: Bool,
        expiresAt: Date
    ) async throws -> BeaconTrainingProgress {
        isLoading = true
        defer { isLoading = false }

        let normalizedExpiration = normalizedExpirationDate(expiresAt)
        let insertedProgress = try await backend.uploadTrainingCertificate(
            userId: userId,
            trainingType: trainingType,
            data: data,
            fileName: fileName,
            isPDF: isPDF,
            expiresAt: normalizedExpiration
        )

        // Update local state
        if let index = self.trainingProgress.firstIndex(where: { $0.trainingType == trainingType }) {
            self.trainingProgress[index] = insertedProgress
        } else {
            self.trainingProgress.append(insertedProgress)
        }

        return insertedProgress
    }

    func updateTrainingExpiration(
        userId: UUID,
        trainingType: BeaconTrainingType,
        expiresAt: Date
    ) async throws -> BeaconTrainingProgress {
        isLoading = true
        defer { isLoading = false }

        let updatedProgress = try await backend.updateTrainingExpiration(
            userId: userId,
            trainingType: trainingType,
            expiresAt: normalizedExpirationDate(expiresAt)
        )

        if let index = self.trainingProgress.firstIndex(where: { $0.trainingType == trainingType }) {
            self.trainingProgress[index] = updatedProgress
        } else {
            self.trainingProgress.append(updatedProgress)
        }

        return updatedProgress
    }
    
    // MARK: - Volunteer Status
    
    /// Check if user is a beacon volunteer
    func isUserBeaconVolunteer(userId: UUID) async throws -> Bool {
        guard try await backend.isUserBeaconVolunteer(userId: userId) else {
            return false
        }

        let progress = try await getTrainingProgress(userId: userId)
        return hasCurrentTrainingQualifications(progress)
    }

    /// Get volunteer status for a user
    func getVolunteerStatus(userId: UUID) async throws -> BeaconVolunteer? {
        let volunteer = try await backend.getVolunteerStatus(userId: userId)
        self.volunteerStatus = volunteer
        return volunteer
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
        try await backend.enrollAsVolunteer(userId: userId)

        // Refresh volunteer status
        _ = try await getVolunteerStatus(userId: userId)

        // Note: Badge is automatically awarded via database trigger
        // See migration: 20260101_add_beacon_volunteer_badge.sql
    }

    /// Update volunteer availability
    func updateAvailability(userId: UUID, isAvailable: Bool) async throws {
        try await backend.updateAvailability(userId: userId, isAvailable: isAvailable)
        self.volunteerStatus?.isAvailable = isAvailable
    }

    /// Update volunteer location
    func updateLocation(userId: UUID, lat: Double, lng: Double) async throws {
        try await backend.updateLocation(userId: userId, lat: lat, lng: lng)
    }

    /// Update notification radius
    func updateNotificationRadius(userId: UUID, radiusMiles: Int) async throws {
        try await backend.updateNotificationRadius(userId: userId, radiusMiles: radiusMiles)
        self.volunteerStatus?.notificationRadiusMiles = radiusMiles
    }

    // MARK: - Emergency Dispatch

    /// Find nearby volunteers for emergency dispatch
    func findNearbyVolunteers(lat: Double, lng: Double, radiusMiles: Int = 25) async throws -> [NearbyVolunteer] {
        try await backend.findNearbyVolunteers(lat: lat, lng: lng, radiusMiles: radiusMiles)
    }

    func hasCurrentTrainingQualifications(_ progress: [BeaconTrainingProgress]) -> Bool {
        let currentTypes = Set(
            progress
                .filter(\.isCurrent)
                .map(\.trainingType)
        )

        return currentTypes == Set(BeaconTrainingType.allCases)
    }

    func qualificationAttentionMessage(for progress: [BeaconTrainingProgress]) -> String? {
        let expiredTypes = progress
            .filter(\.isExpired)
            .map(\.trainingType.displayName)
        if !expiredTypes.isEmpty {
            return "One or more Beacon qualifications have expired. Upload renewed certificates before continuing as an active volunteer."
        }

        let missingExpirationTypes = progress
            .filter(\.needsExpiration)
            .map(\.trainingType.displayName)
        if !missingExpirationTypes.isEmpty {
            return "Beacon now tracks qualification expiration dates. Add expiration dates for your existing documents to keep your volunteer status active."
        }

        return nil
    }

    private func normalizedExpirationDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: components.year,
            month: components.month,
            day: components.day,
            hour: 23,
            minute: 59,
            second: 59
        )) ?? date
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

enum BeaconError: LocalizedError, Equatable {
    case trainingIncomplete
    case uploadFailed
    case enrollmentFailed
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .trainingIncomplete:
            return "Please upload current Beacon qualifications with expiration dates for First Aid/CPR, Firefighting, and Disaster Response before enrolling as a volunteer."
        case .uploadFailed:
            return "Failed to upload certificate. Please try again."
        case .enrollmentFailed:
            return "Failed to enroll as volunteer. Please try again."
        case .notFound:
            return "Volunteer record not found."
        }
    }
}
