//
//  LiveFlight.swift
//  Buzz
//
//  FlightRadar24 API response models for live flight tracking
//

import Foundation
import CoreLocation

// MARK: - API Response Wrapper

struct FR24FlightPositionsResponse: Codable {
    let data: [FR24FlightPosition]
}

// MARK: - Flight Position (Full endpoint)

struct FR24FlightPosition: Codable, Identifiable {
    let fr24Id: String
    let lat: Double
    let lon: Double
    let track: Int          // heading in degrees
    let alt: Int            // altitude in feet
    let gspeed: Int         // ground speed in knots
    let vspeed: Int         // vertical speed in fpm
    let squawk: String
    let timestamp: String
    let source: String
    let hex: String?
    let callsign: String?
    let flight: String?     // flight number (e.g., "BA1234")
    let type: String?       // ICAO aircraft type code (e.g., "B738")
    let reg: String?        // aircraft registration
    let paintedAs: String?  // ICAO airline code (painted livery)
    let operatingAs: String? // ICAO airline code (operating carrier)
    let origIata: String?
    let origIcao: String?
    let destIata: String?
    let destIcao: String?
    let eta: String?

    var id: String { fr24Id }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Display name: prefer callsign, fall back to flight number, then fr24_id
    var displayName: String {
        callsign ?? flight ?? fr24Id
    }

    /// Route string like "EGLL → EGCC" or "LHR → MAN"
    var routeString: String? {
        let orig = origIata ?? origIcao
        let dest = destIata ?? destIcao
        guard let orig = orig, let dest = dest else { return nil }
        return "\(orig) → \(dest)"
    }

    enum CodingKeys: String, CodingKey {
        case fr24Id = "fr24_id"
        case lat, lon, track, alt, gspeed, vspeed, squawk, timestamp, source
        case hex, callsign, flight, type, reg
        case paintedAs = "painted_as"
        case operatingAs = "operating_as"
        case origIata = "orig_iata"
        case origIcao = "orig_icao"
        case destIata = "dest_iata"
        case destIcao = "dest_icao"
        case eta
    }
}
