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
    
    var id: UUID { pilotId }
    
    enum CodingKeys: String, CodingKey {
        case pilotId = "pilot_id"
        case totalFlightHours = "total_flight_hours"
        case completedBookings = "completed_bookings"
        case tier
    }
    
    // Tier calculation based on flight hours
    static func calculateTier(flightHours: Double) -> Int {
        switch flightHours {
        case 0..<10: return 0
        case 10..<25: return 1
        case 25..<50: return 2
        case 50..<100: return 3
        case 100..<200: return 4
        case 200..<350: return 5
        case 350..<550: return 6
        case 550..<800: return 7
        case 800..<1100: return 8
        case 1100..<1500: return 9
        default: return 10
        }
    }
    
    var tierName: String {
        switch tier {
        case 0: return "Novice"
        case 1: return "Apprentice"
        case 2: return "Intermediate"
        case 3: return "Skilled"
        case 4: return "Advanced"
        case 5: return "Expert"
        case 6: return "Master"
        case 7: return "Elite"
        case 8: return "Legend"
        case 9: return "Supreme"
        case 10: return "Grand Master"
        default: return "Unknown"
        }
    }
}

