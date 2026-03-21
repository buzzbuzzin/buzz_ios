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
    private let userDefaults = UserDefaults.standard

    // MARK: - PilotStats Cache

    private func statsCacheKey(for pilotId: UUID) -> String {
        "pilotStatsCache.\(pilotId.uuidString)"
    }

    private func persistStats(_ stats: PilotStats) {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        userDefaults.set(data, forKey: statsCacheKey(for: stats.pilotId))
    }

    private func restoreCachedStats(for pilotId: UUID) -> PilotStats? {
        guard let data = userDefaults.data(forKey: statsCacheKey(for: pilotId)),
              let stats = try? JSONDecoder().decode(PilotStats.self, from: data) else {
            return nil
        }
        return stats
    }

    // MARK: - Get Pilot Stats

    func getPilotStats(pilotId: UUID) async throws {
        errorMessage = nil

        // Restore from cache immediately to skip spinner
        if let cached = restoreCachedStats(for: pilotId) {
            self.pilotStats = cached
        } else {
            isLoading = true
        }

        do {
            let stats: PilotStats = try await supabase
                .from("pilot_stats")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .single()
                .execute()
                .value

            persistStats(stats)
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
    
    func fetchLeaderboard(limit: Int = 10) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Join with profiles to get callsign
            let response = try await supabase
                .from("pilot_stats")
                .select("*, profiles(call_sign)")
                .order("tier", ascending: false)
                .order("total_flight_hours", ascending: false)
                .limit(limit)
                .execute()
            
            // Parse the response manually to extract callsign from nested profiles object
            let data = try JSONDecoder().decode([LeaderboardResponse].self, from: response.data)
            let stats = data.map { response in
                PilotStats(
                    pilotId: response.pilotId,
                    totalFlightHours: response.totalFlightHours,
                    completedBookings: response.completedBookings,
                    tier: response.tier,
                    callsign: response.callSign
                )
            }
            
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

// MARK: - Helper struct for decoding joined response
private struct LeaderboardResponse: Codable {
    let pilotId: UUID
    let totalFlightHours: Double
    let completedBookings: Int
    let tier: Int
    let profiles: ProfileCallSignOrArray?
    
    enum CodingKeys: String, CodingKey {
        case pilotId = "pilot_id"
        case totalFlightHours = "total_flight_hours"
        case completedBookings = "completed_bookings"
        case tier
        case profiles
    }
    
    var callSign: String? {
        switch profiles {
        case .single(let profile):
            return profile?.callSign
        case .array(let profiles):
            return profiles.first?.callSign
        case .none:
            return nil
        }
    }
}

private enum ProfileCallSignOrArray: Codable {
    case single(ProfileCallSign?)
    case array([ProfileCallSign])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([ProfileCallSign].self) {
            self = .array(array)
        } else if let single = try? container.decode(ProfileCallSign.self) {
            self = .single(single)
        } else {
            self = .single(nil)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let profile):
            if let profile = profile {
                try container.encode(profile)
            } else {
                try container.encodeNil()
            }
        case .array(let profiles):
            try container.encode(profiles)
        }
    }
}

private struct ProfileCallSign: Codable {
    let callSign: String?
    
    enum CodingKeys: String, CodingKey {
        case callSign = "call_sign"
    }
}

