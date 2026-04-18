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
    /// Number of incident reports that failed to reach the server and are queued
    /// locally for retry. Non-zero means a regulatory-critical report is pending.
    @Published var pendingSubmissionCount: Int = 0

    private let supabase = SupabaseClient.shared.client

    private static let pendingQueueKey = "incident_logs_pending_submission_v1"

    init() {
        self.pendingSubmissionCount = Self.loadQueue().count
    }

    // MARK: - Local Pending Queue (for network-failure retries)

    private static func loadQueue() -> [IncidentLogInsert] {
        guard let data = UserDefaults.standard.data(forKey: pendingQueueKey) else { return [] }
        return (try? JSONDecoder().decode([IncidentLogInsert].self, from: data)) ?? []
    }

    private static func saveQueue(_ items: [IncidentLogInsert]) {
        if items.isEmpty {
            UserDefaults.standard.removeObject(forKey: pendingQueueKey)
        } else if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: pendingQueueKey)
        }
    }

    private func enqueuePending(_ insert: IncidentLogInsert) {
        var queue = Self.loadQueue()
        queue.append(insert)
        Self.saveQueue(queue)
        pendingSubmissionCount = queue.count
    }

    /// Retry any pending submissions. Call on app foreground and when the
    /// network reconnects. Safe to call from anywhere — no-op if queue is empty.
    func retryPendingSubmissions() async {
        var queue = Self.loadQueue()
        guard !queue.isEmpty else {
            pendingSubmissionCount = 0
            return
        }
        var remaining: [IncidentLogInsert] = []
        for insert in queue {
            do {
                let _: IncidentLog = try await supabase
                    .from("incident_logs")
                    .insert(insert)
                    .select()
                    .single()
                    .execute()
                    .value
            } catch {
                // Keep it in the queue for next attempt.
                remaining.append(insert)
            }
        }
        queue = remaining
        Self.saveQueue(queue)
        pendingSubmissionCount = queue.count
    }
    
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
            
            // Attempt to insert. If the network drops or the backend is
            // unreachable, persist the fully-formed insert to a local queue so
            // we can retry on reconnect instead of silently losing a
            // regulatory-required incident report.
            do {
                let _: IncidentLog = try await supabase
                    .from("incident_logs")
                    .insert(incidentLogInsert)
                    .select()
                    .single()
                    .execute()
                    .value
                isSaving = false
            } catch {
                // Classify network-ish errors: NSURLError domain or generic
                // connection failures go to the retry queue. Auth/validation
                // failures (4xx) are caller errors and surface immediately.
                let ns = error as NSError
                let isNetworkError = ns.domain == NSURLErrorDomain
                    || error.localizedDescription.lowercased().contains("connection")
                    || error.localizedDescription.lowercased().contains("timed out")
                    || error.localizedDescription.lowercased().contains("network")
                if isNetworkError {
                    enqueuePending(incidentLogInsert)
                    isSaving = false
                    errorMessage = "You're offline — this incident report has been saved and will be submitted automatically when you reconnect."
                    return
                }
                isSaving = false
                errorMessage = "Failed to submit incident log: \(error.localizedDescription)"
                throw error
            }
        } catch {
            isSaving = false
            errorMessage = "Failed to submit incident log: \(error.localizedDescription)"
            throw error
        }
    }
}

