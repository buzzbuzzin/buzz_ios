//
//  TopGunService.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import Supabase
import Combine

@MainActor
class TopGunService: ObservableObject {
    @Published var topGunPilots: [TopGunPilot] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    
    // MARK: - Fetch TopGun Pilots
    
    func fetchTopGunPilots() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch TopGun pilots with their profile and stats information
            // Assuming a topgun_pilots table exists with pilot_id and other metadata
            // For now, we'll query profiles and pilot_stats joined, filtering for TopGun members
            // This assumes there's a topgun_pilots table or a flag in profiles/pilot_stats
            
            // TODO: Update this query once the topgun_pilots table is created
            // Expected table structure:
            // CREATE TABLE topgun_pilots (
            //     pilot_id UUID REFERENCES profiles(id) PRIMARY KEY,
            //     championship_score INTEGER,
            //     selected_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            //     created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            // );
            
            // For now, return empty array if table doesn't exist
            // In production, this would be:
            /*
            let response: [TopGunPilotResponse] = try await supabase
                .from("topgun_pilots")
                .select("""
                    pilot_id,
                    championship_score,
                    profiles!inner(id, call_sign),
                    pilot_stats!inner(pilot_id, total_flight_hours, completed_bookings, tier)
                """)
                .order("championship_score", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.topGunPilots = response.map { $0.toTopGunPilot() }
                self.isLoading = false
            }
            */
            
            // Temporary: Return empty array until table is created
            await MainActor.run {
                self.topGunPilots = []
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                // If table doesn't exist, just return empty array
                self.topGunPilots = []
            }
        }
    }
    
    // MARK: - Check if Pilot is TopGun Member
    
    func isTopGunMember(pilotId: UUID) async -> Bool {
        do {
            // TODO: Query topgun_pilots table once created
            // For now, check if pilot is in the fetched list
            return topGunPilots.contains { $0.id == pilotId }
        } catch {
            return false
        }
    }
}

// MARK: - TopGun Pilot Response Model (for backend response)

struct TopGunPilotResponse: Codable {
    let pilotId: UUID
    let championshipScore: Int?
    let profile: ProfileResponse?
    let stats: PilotStatsResponse?
    
    enum CodingKeys: String, CodingKey {
        case pilotId = "pilot_id"
        case championshipScore = "championship_score"
        case profile = "profiles"
        case stats = "pilot_stats"
    }
    
    func toTopGunPilot() -> TopGunPilot {
        TopGunPilot(
            id: pilotId,
            callsign: profile?.callSign ?? "Unknown",
            flightHours: stats?.totalFlightHours ?? 0,
            completedFlights: stats?.completedBookings ?? 0,
            rank: stats?.tierName ?? "Unknown",
            championshipScore: championshipScore ?? 0
        )
    }
}

struct ProfileResponse: Codable {
    let id: UUID
    let callSign: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case callSign = "call_sign"
    }
}

struct PilotStatsResponse: Codable {
    let pilotId: UUID
    let totalFlightHours: Double
    let completedBookings: Int
    let tier: Int
    
    enum CodingKeys: String, CodingKey {
        case pilotId = "pilot_id"
        case totalFlightHours = "total_flight_hours"
        case completedBookings = "completed_bookings"
        case tier
    }
    
    var tierName: String {
        switch tier {
        case 0: return "Ensign"
        case 1: return "Sub Lieutenant"
        case 2: return "Lieutenant"
        case 3: return "Commander"
        case 4: return "Captain"
        default: return "Unknown"
        }
    }
}

