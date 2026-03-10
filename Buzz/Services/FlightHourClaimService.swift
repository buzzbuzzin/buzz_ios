//
//  FlightHourClaimService.swift
//  Buzz
//
//  Created for flight hour claims management
//

import Foundation
import Supabase
import UIKit
import Combine

@MainActor
class FlightHourClaimService: ObservableObject {
    @Published var claims: [FlightHourClaim] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSaving = false

    private let supabase = SupabaseClient.shared.client

    // MARK: - Fetch Claims

    func fetchClaims(pilotId: UUID) async {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let fetchedClaims: [FlightHourClaim] = try await supabase
                .from("flight_hour_claims")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .order("submitted_at", ascending: false)
                .execute()
                .value

            claims = fetchedClaims
        } catch {
            errorMessage = "Failed to load claims: \(error.localizedDescription)"
        }
    }

    // MARK: - Submit Claim

    func submitClaim(
        pilotId: UUID,
        claimedFlights: Int,
        claimedHours: Double,
        notes: String?,
        evidenceImages: [UIImage]
    ) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        guard claimedFlights > 0, claimedHours > 0 else {
            throw NSError(
                domain: "FlightHourClaimService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Flights and hours must be positive"]
            )
        }

        isSaving = true
        defer { isSaving = false }
        errorMessage = nil

        do {
            // First insert the claim to get its ID
            let claimInsert = FlightHourClaimInsert(
                pilotId: pilotId,
                claimedFlights: claimedFlights,
                claimedHours: claimedHours,
                notes: notes?.isEmpty == true ? nil : notes,
                evidenceFiles: nil
            )

            let insertedClaim: FlightHourClaim = try await supabase
                .from("flight_hour_claims")
                .insert(claimInsert)
                .select()
                .single()
                .execute()
                .value

            // Upload evidence files if any
            var uploadedPaths: [String] = []

            for (index, image) in evidenceImages.enumerated() {
                guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }

                let filePath = "\(pilotId.uuidString)/\(insertedClaim.id.uuidString)/evidence_\(index).jpg"

                try await supabase.storage
                    .from("flight-hour-claims")
                    .upload(
                        path: filePath,
                        file: imageData,
                        options: FileOptions(contentType: "image/jpeg")
                    )

                uploadedPaths.append(filePath)
            }

            // Update claim with evidence file paths if any were uploaded
            if !uploadedPaths.isEmpty {
                let updateData: [String: AnyJSON] = [
                    "evidence_files": .array(uploadedPaths.map { .string($0) })
                ]

                try await supabase
                    .from("flight_hour_claims")
                    .update(updateData)
                    .eq("id", value: insertedClaim.id.uuidString)
                    .execute()
            }
        } catch {
            errorMessage = "Failed to submit claim: \(error.localizedDescription)"
            throw error
        }
    }
}
