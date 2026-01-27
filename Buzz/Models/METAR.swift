//
//  METAR.swift
//  Buzz
//
//  Created by Xinyu Fang on 1/27/26.
//

import Foundation
import CoreLocation

/// Represents a METAR (Meteorological Aerodrome Report) observation
struct METAR: Identifiable {
    let id: String                  // Unique identifier (stationId + observationTime)
    let stationId: String           // ICAO code (e.g., "KITH")
    let stationName: String?        // Airport name if available
    let rawText: String             // Raw METAR string
    let observationTime: Date
    let latitude: Double
    let longitude: Double
    let temperature: Double?        // Celsius
    let dewpoint: Double?           // Celsius
    let windDirection: Int?         // Degrees
    let windSpeed: Int?             // Knots
    let windGust: Int?              // Knots
    let visibility: Double?         // Statute miles
    let altimeter: Double?          // inHg
    let flightCategory: FlightCategory
    let clouds: [CloudLayer]
    let weatherPhenomena: String?   // Weather phenomena (e.g., "RA", "SN", "FG")
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// Calculate distance from a given coordinate in meters
    func distance(from coordinate: CLLocationCoordinate2D) -> Double {
        let stationLocation = CLLocation(latitude: latitude, longitude: longitude)
        let fromLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return stationLocation.distance(from: fromLocation)
    }
    
    /// Distance formatted as a string (in miles or km)
    func formattedDistance(from coordinate: CLLocationCoordinate2D) -> String {
        let meters = distance(from: coordinate)
        let miles = meters / 1609.34
        if miles < 1 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f mi", miles)
        }
    }
}

/// Represents a cloud layer in a METAR report
struct CloudLayer: Identifiable {
    let id = UUID()
    let cover: CloudCover
    let base: Int?                  // Feet AGL (nil for clear sky)
    
    var description: String {
        if let base = base {
            return "\(cover.rawValue) at \(base) ft"
        } else {
            return cover.rawValue
        }
    }
}

/// Cloud cover types
enum CloudCover: String {
    case skc = "SKC"    // Sky Clear
    case clr = "CLR"    // Clear (automated)
    case few = "FEW"    // Few (1/8 - 2/8)
    case sct = "SCT"    // Scattered (3/8 - 4/8)
    case bkn = "BKN"    // Broken (5/8 - 7/8)
    case ovc = "OVC"    // Overcast (8/8)
    case vv = "VV"      // Vertical Visibility (obscured sky)
    
    var displayName: String {
        switch self {
        case .skc, .clr: return "Clear"
        case .few: return "Few"
        case .sct: return "Scattered"
        case .bkn: return "Broken"
        case .ovc: return "Overcast"
        case .vv: return "Obscured"
        }
    }
}

/// Flight category based on ceiling and visibility
enum FlightCategory: String {
    case vfr = "VFR"        // Visual Flight Rules
    case mvfr = "MVFR"      // Marginal VFR
    case ifr = "IFR"        // Instrument Flight Rules
    case lifr = "LIFR"      // Low IFR
    case unknown = "N/A"
    
    var color: String {
        switch self {
        case .vfr: return "green"
        case .mvfr: return "blue"
        case .ifr: return "red"
        case .lifr: return "purple"
        case .unknown: return "gray"
        }
    }
    
    var displayName: String {
        switch self {
        case .vfr: return "VFR"
        case .mvfr: return "Marginal VFR"
        case .ifr: return "IFR"
        case .lifr: return "Low IFR"
        case .unknown: return "Unknown"
        }
    }
}
