//
//  FlightLogService.swift
//  Buzz
//
//  Created for flight log management
//

import Foundation
import Supabase
import UIKit
import Combine

@MainActor
class FlightLogService: ObservableObject {
    @Published var flightLogs: [FlightLog] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSaving = false
    
    private let supabase = SupabaseClient.shared.client
    
    // MARK: - Fetch Flight Logs
    
    func fetchFlightLogs(pilotId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let logs: [FlightLog] = try await supabase
                .from("flight_logs")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            flightLogs = logs
            isLoading = false
        } catch {
            errorMessage = "Failed to load flight logs: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Get Next Sheet Number
    
    func getNextSheetNumber(pilotId: UUID, aircraftNumber: String) async -> Int {
        do {
            let logs: [FlightLog] = try await supabase
                .from("flight_logs")
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
    
    // MARK: - Submit Flight Log
    
    func submitFlightLog(
        pilotId: UUID,
        aircraftNumber: String,
        descriptionOfFlight: String,
        date: Date,
        timeOut: Date,
        timeIn: Date,
        totalAirtimeMinutes: Int,
        comments: String?,
        signatureImage: UIImage
    ) async throws {
        isSaving = true
        errorMessage = nil
        
        do {
            // Convert signature image to base64 PNG
            guard let signatureData = signatureImage.pngData() else {
                throw NSError(
                    domain: "FlightLogService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to convert signature to PNG"]
                )
            }
            let signatureBase64 = signatureData.base64EncodedString()
            
            // Get next sheet number
            let sheetNumber = await getNextSheetNumber(pilotId: pilotId, aircraftNumber: aircraftNumber)
            
            // Create insert object
            let flightLogInsert = FlightLogInsert(
                pilotId: pilotId,
                aircraftNumber: aircraftNumber,
                sheetNumber: sheetNumber,
                descriptionOfFlight: descriptionOfFlight,
                date: date,
                timeOut: timeOut,
                timeIn: timeIn,
                totalAirtimeMinutes: totalAirtimeMinutes,
                comments: comments,
                signatureData: signatureBase64,
                isLocked: true
            )
            
            // Insert into database
            let _: FlightLog = try await supabase
                .from("flight_logs")
                .insert(flightLogInsert)
                .select()
                .single()
                .execute()
                .value
            
            isSaving = false
        } catch {
            isSaving = false
            errorMessage = "Failed to submit flight log: \(error.localizedDescription)"
            throw error
        }
    }
}

