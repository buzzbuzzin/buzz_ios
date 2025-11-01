//
//  RankingService.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import Foundation
import Supabase
import Combine

@MainActor
class RankingService: ObservableObject {
    @Published var pilotStats: PilotStats?
    @Published var leaderboard: [PilotStats] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    
    // MARK: - Get Pilot Stats
    
    func getPilotStats(pilotId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let stats: PilotStats = try await supabase
                .from("pilot_stats")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                self.pilotStats = stats
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
    
    // MARK: - Update Flight Hours
    
    func updateFlightHours(pilotId: UUID, additionalHours: Double) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get current stats
            let currentStats: PilotStats = try await supabase
                .from("pilot_stats")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .single()
                .execute()
                .value
            
            let newFlightHours = currentStats.totalFlightHours + additionalHours
            let newCompletedBookings = currentStats.completedBookings + 1
            let newTier = PilotStats.calculateTier(flightHours: newFlightHours)
            
            // Update stats
            let updateData: [String: AnyJSON] = [
                "total_flight_hours": .double(newFlightHours),
                "completed_bookings": .integer(newCompletedBookings),
                "tier": .integer(newTier)
            ]
            
            try await supabase
                .from("pilot_stats")
                .update(updateData)
                .eq("pilot_id", value: pilotId.uuidString)
                .execute()
            
            // Refresh stats
            try await getPilotStats(pilotId: pilotId)
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Get Leaderboard
    
    func fetchLeaderboard(limit: Int = 100) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let stats: [PilotStats] = try await supabase
                .from("pilot_stats")
                .select()
                .order("total_flight_hours", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            await MainActor.run {
                self.leaderboard = stats
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
}

