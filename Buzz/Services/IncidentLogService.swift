//
//  IncidentLogService.swift
//  Buzz
//
//  Created for incident log management
//

import Foundation
import Supabase
import UIKit
import Combine

@MainActor
class IncidentLogService: ObservableObject {
    @Published var incidentLogs: [IncidentLog] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSaving = false
    
    private let supabase = SupabaseClient.shared.client
    
    // MARK: - Fetch Incident Logs
    
    func fetchIncidentLogs(pilotId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let logs: [IncidentLog] = try await supabase
                .from("incident_logs")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            incidentLogs = logs
            isLoading = false
        } catch {
            errorMessage = "Failed to load incident logs: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Check if Incident Log Exists for Booking
    
    func hasIncidentLog(bookingId: UUID, pilotId: UUID) async -> Bool {
        do {
            let logs: [IncidentLog] = try await supabase
                .from("incident_logs")
                .select()
                .eq("booking_id", value: bookingId.uuidString)
                .eq("pilot_id", value: pilotId.uuidString)
                .execute()
                .value
            
            return !logs.isEmpty
        } catch {
            return false
        }
    }
    
    // MARK: - Get Incident Log for Booking
    
    func getIncidentLog(bookingId: UUID, pilotId: UUID) async -> IncidentLog? {
        do {
            let log: IncidentLog = try await supabase
                .from("incident_logs")
                .select()
                .eq("booking_id", value: bookingId.uuidString)
                .eq("pilot_id", value: pilotId.uuidString)
                .single()
                .execute()
                .value
            
            return log
        } catch {
            return nil
        }
    }
    
    // MARK: - Submit Incident Log
    
    func submitIncidentLog(
        bookingId: UUID,
        pilotId: UUID,
        name: String,
        phoneNumber: String,
        dateOfIncident: Date,
        dateOfReport: Date,
        jobTitle: String?,
        operationName: String?,
        organization: String?,
        pic: String?,
        region: String?,
        airspaceClass: String?,
        reportedToPolice: Bool,
        reportedToAtc: Bool,
        locationOfIncident: String,
        descriptionOfIncident: String,
        nameOfWitness: String?,
        signatureImage: UIImage
    ) async throws {
        isSaving = true
        errorMessage = nil
        
        do {
            // Convert signature image to base64 PNG
            guard let signatureData = signatureImage.pngData() else {
                throw NSError(
                    domain: "IncidentLogService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to convert signature to PNG"]
                )
            }
            let signatureBase64 = signatureData.base64EncodedString()
            
            // Create insert object
            let incidentLogInsert = IncidentLogInsert(
                bookingId: bookingId,
                pilotId: pilotId,
                name: name,
                phoneNumber: phoneNumber,
                dateOfIncident: dateOfIncident,
                dateOfReport: dateOfReport,
                jobTitle: jobTitle,
                operationName: operationName,
                organization: organization,
                pic: pic,
                region: region,
                airspaceClass: airspaceClass,
                reportedToPolice: reportedToPolice,
                reportedToAtc: reportedToAtc,
                locationOfIncident: locationOfIncident,
                descriptionOfIncident: descriptionOfIncident,
                nameOfWitness: nameOfWitness,
                signatureData: signatureBase64,
                signatureDate: Date(),
                isLocked: true // Lock immediately after submission
            )
            
            // Insert into database
            let _: IncidentLog = try await supabase
                .from("incident_logs")
                .insert(incidentLogInsert)
                .select()
                .single()
                .execute()
                .value
            
            isSaving = false
        } catch {
            isSaving = false
            errorMessage = "Failed to submit incident log: \(error.localizedDescription)"
            throw error
        }
    }
}

