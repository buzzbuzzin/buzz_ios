//
//  MaintenanceLogService.swift
//  Buzz
//
//  Created for maintenance log management
//

import Foundation
import Supabase
import UIKit
import Combine

@MainActor
class MaintenanceLogService: ObservableObject {
    @Published var maintenanceLogs: [MaintenanceLog] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSaving = false
    
    private let supabase = SupabaseClient.shared.client
    
    // MARK: - Fetch Maintenance Logs
    
    func fetchMaintenanceLogs(pilotId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let logs: [MaintenanceLog] = try await supabase
                .from("maintenance_logs")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            maintenanceLogs = logs
            isLoading = false
        } catch {
            errorMessage = "Failed to load maintenance logs: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Get Next Sheet Number
    
    func getNextSheetNumber(pilotId: UUID, aircraftNumber: String) async -> Int {
        do {
            let logs: [MaintenanceLog] = try await supabase
                .from("maintenance_logs")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("aircraft_number", value: aircraftNumber)
                .order("sheet_number", ascending: false)
                .limit(1)
                .execute()
                .value
            
            if let lastLog = logs.first {
                return lastLog.sheetNumber + 1
            }
            return 1
        } catch {
            return 1
        }
    }
    
    // MARK: - Submit Maintenance Log
    
    func submitMaintenanceLog(
        pilotId: UUID,
        aircraftNumber: String,
        date: Date,
        repairs: String,
        replacementParts: String?,
        comments: String?,
        initialsImage: UIImage
    ) async throws {
        isSaving = true
        errorMessage = nil
        
        do {
            // Convert initials image to base64 PNG
            guard let initialsData = initialsImage.pngData() else {
                throw NSError(
                    domain: "MaintenanceLogService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to convert initials to PNG"]
                )
            }
            let initialsBase64 = initialsData.base64EncodedString()
            
            // Get next sheet number
            let sheetNumber = await getNextSheetNumber(pilotId: pilotId, aircraftNumber: aircraftNumber)
            
            // Create insert object
            let maintenanceLogInsert = MaintenanceLogInsert(
                pilotId: pilotId,
                aircraftNumber: aircraftNumber,
                sheetNumber: sheetNumber,
                date: date,
                repairs: repairs,
                replacementParts: replacementParts,
                comments: comments,
                initialsData: initialsBase64,
                isLocked: true
            )
            
            // Insert into database
            let _: MaintenanceLog = try await supabase
                .from("maintenance_logs")
                .insert(maintenanceLogInsert)
                .select()
                .single()
                .execute()
                .value
            
            isSaving = false
        } catch {
            isSaving = false
            errorMessage = "Failed to submit maintenance log: \(error.localizedDescription)"
            throw error
        }
    }
}

