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
            // If stats don't exist, create them
            do {
                let newStats: [String: AnyJSON] = [
                    "pilot_id": .string(pilotId.uuidString),
                    "total_flight_hours": .double(0.0),
                    "completed_bookings": .integer(0),
                    "tier": .integer(0)
                ]
                
                try await supabase
                    .from("pilot_stats")
                    .insert(newStats)
                    .execute()
                
                // Retry fetching
                try await getPilotStats(pilotId: pilotId)
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
                throw error
            }
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
        
        // TODO: DEMO MODE - Replace this sample data with real backend call
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // SAMPLE DATA FOR DEMO PURPOSES - Replace with real Supabase query when ready
        let sampleLeaderboard = createSampleLeaderboard()
        
        await MainActor.run {
            self.leaderboard = sampleLeaderboard
            self.isLoading = false
        }
        
        return
        
        /* UNCOMMENT WHEN READY TO USE REAL BACKEND:
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
        */
    }
    
    // MARK: - Sample Data for Demo (Leaderboard)
    // TODO: Remove this function when connecting to real backend
    
    private func createSampleLeaderboard() -> [PilotStats] {
        return [
            // Top pilots competing for rankings (Naval rank system)
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 850.5,
                completedBookings: 187,
                tier: 4 // Captain
            ),
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 720.3,
                completedBookings: 165,
                tier: 4 // Captain
            ),
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 680.2,
                completedBookings: 142,
                tier: 4 // Captain
            ),
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 550.8,
                completedBookings: 128,
                tier: 4 // Captain
            ),
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 485.4,
                completedBookings: 115,
                tier: 4 // Captain
            ),
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 420.2,
                completedBookings: 98,
                tier: 4 // Captain
            ),
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 385.6,
                completedBookings: 87,
                tier: 3 // Commander
            ),
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 350.3,
                completedBookings: 76,
                tier: 3 // Commander
            ),
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 320.1,
                completedBookings: 65,
                tier: 3 // Commander
            ),
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 275.7,
                completedBookings: 58,
                tier: 3 // Commander
            ),
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 185.4,
                completedBookings: 52,
                tier: 2 // Lieutenant
            ),
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 145.8,
                completedBookings: 45,
                tier: 2 // Lieutenant
            ),
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 120.3,
                completedBookings: 32,
                tier: 2 // Lieutenant
            ),
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 85.2,
                completedBookings: 28,
                tier: 2 // Lieutenant
            ),
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 60.6,
                completedBookings: 18,
                tier: 1 // Sub Lieutenant
            ),
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 42.3,
                completedBookings: 12,
                tier: 1 // Sub Lieutenant
            ),
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 18.5,
                completedBookings: 6,
                tier: 0 // Ensign
            ),
            PilotStats(
                pilotId: UUID(),
                totalFlightHours: 7.2,
                completedBookings: 3,
                tier: 0 // Ensign
            )
        ]
    }
}

