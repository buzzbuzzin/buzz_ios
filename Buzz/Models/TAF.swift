//
//  TAF.swift
//  Buzz
//
//  Created by Xinyu Fang on 3/26/26.
//

import Foundation
import CoreLocation

/// Represents a TAF (Terminal Aerodrome Forecast)
struct TAF: Identifiable {
    let id: String                      // stationId + validFrom timestamp
    let stationId: String               // ICAO code (e.g., "KITH")
    let stationName: String?            // Airport name if available
    let rawTAF: String                  // Raw TAF string
    let issueTime: Date
    let validFrom: Date
    let validTo: Date
    let latitude: Double
    let longitude: Double
    let elevation: Int?                 // Feet
    let forecastPeriods: [TAFForecastPeriod]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Calculate distance from a given coordinate in meters
    func distance(from coordinate: CLLocationCoordinate2D) -> Double {
        let stationLocation = CLLocation(latitude: latitude, longitude: longitude)
        let fromLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return stationLocation.distance(from: fromLocation)
    }

    /// Distance formatted as a string (in miles)
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

/// Represents a single forecast period within a TAF
struct TAFForecastPeriod: Identifiable {
    let id = UUID()
    let timeFrom: Date
    let timeTo: Date
    let changeType: TAFChangeType?      // nil for base forecast
    let probability: Int?               // 30 or 40 for PROB forecasts
    let windDirection: Int?             // Degrees (nil if VRB)
    let windSpeed: Int?                 // Knots
    let windGust: Int?                  // Knots
    let visibility: Double?             // Statute miles
    let weatherPhenomena: String?       // e.g., "RA BR", "SN FG"
    let clouds: [CloudLayer]
    let verticalVisibility: Int?        // Feet (when sky is obscured)

    /// Derive flight category from ceiling and visibility using standard aviation rules
    var derivedFlightCategory: FlightCategory {
        // Find ceiling (lowest BKN, OVC, or VV layer)
        let ceilingLayers = clouds.filter {
            $0.cover == .bkn || $0.cover == .ovc || $0.cover == .vv
        }
        let ceiling = ceilingLayers.compactMap({ $0.base }).min() ?? verticalVisibility

        let vis = visibility

        // LIFR: ceiling < 500 ft OR visibility < 1 SM
        if let c = ceiling, c < 500 { return .lifr }
        if let v = vis, v < 1 { return .lifr }

        // IFR: ceiling 500-999 ft OR visibility 1-2 SM
        if let c = ceiling, c < 1000 { return .ifr }
        if let v = vis, v < 3 { return .ifr }

        // MVFR: ceiling 1000-2999 ft OR visibility 3-4 SM
        if let c = ceiling, c < 3000 { return .mvfr }
        if let v = vis, v <= 5 { return .mvfr }

        // VFR: ceiling >= 3000 ft AND visibility > 5 SM
        return .vfr
    }
}

/// TAF forecast change indicator
enum TAFChangeType: String, CaseIterable {
    case fm = "FM"
    case tempo = "TEMPO"
    case becmg = "BECMG"
    case prob = "PROB"

    var displayName: String {
        switch self {
        case .fm: return "From"
        case .tempo: return "Temporary"
        case .becmg: return "Becoming"
        case .prob: return "Probability"
        }
    }
}
