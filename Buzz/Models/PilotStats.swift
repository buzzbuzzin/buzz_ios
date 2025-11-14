//
//  PilotStats.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import Foundation

struct PilotStats: Codable, Identifiable {
    let pilotId: UUID
    var totalFlightHours: Double
    var completedBookings: Int
    var tier: Int
    var callsign: String?
    
    var id: UUID { pilotId }
    
    enum CodingKeys: String, CodingKey {
        case pilotId = "pilot_id"
        case totalFlightHours = "total_flight_hours"
        case completedBookings = "completed_bookings"
        case tier
        case callsign = "call_sign"
    }
    
    // Tier calculation based on flight hours
    // Naval rank system: Ensign (0) -> Sub Lieutenant (1) -> Lieutenant (2) -> Commander (3) -> Captain (4)
    static func calculateTier(flightHours: Double) -> Int {
        switch flightHours {
        case 0..<25: return 0        // Ensign
        case 25..<75: return 1      // Sub Lieutenant
        case 75..<200: return 2      // Lieutenant
        case 200..<500: return 3    // Commander
        default: return 4            // Captain
        }
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

