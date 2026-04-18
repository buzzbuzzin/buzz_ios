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

    // Memberwise initializer — defining `init(from:)` below removes the
    // compiler-synthesized memberwise init, so we restate it here for tests and
    // demo-mode sample data.
    init(
        fr24Id: String,
        lat: Double,
        lon: Double,
        track: Int,
        alt: Int,
        gspeed: Int,
        vspeed: Int,
        squawk: String,
        timestamp: String,
        source: String,
        hex: String? = nil,
        callsign: String? = nil,
        flight: String? = nil,
        type: String? = nil,
        reg: String? = nil,
        paintedAs: String? = nil,
        operatingAs: String? = nil,
        origIata: String? = nil,
        origIcao: String? = nil,
        destIata: String? = nil,
        destIcao: String? = nil,
        eta: String? = nil
    ) {
        self.fr24Id = fr24Id
        self.lat = lat
        self.lon = lon
        self.track = track
        self.alt = alt
        self.gspeed = gspeed
        self.vspeed = vspeed
        self.squawk = squawk
        self.timestamp = timestamp
        self.source = source
        self.hex = hex
        self.callsign = callsign
        self.flight = flight
        self.type = type
        self.reg = reg
        self.paintedAs = paintedAs
        self.operatingAs = operatingAs
        self.origIata = origIata
        self.origIcao = origIcao
        self.destIata = destIata
        self.destIcao = destIcao
        self.eta = eta
    }

    // Custom decoder: FR24 may omit or send null for track/alt/gspeed/vspeed/squawk on
    // parked or taxiing aircraft. A single null in these fields would drop the entire
    // flight list, so fall back to sensible defaults instead of throwing.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fr24Id = try c.decode(String.self, forKey: .fr24Id)
        lat = try c.decodeIfPresent(Double.self, forKey: .lat) ?? 0
        lon = try c.decodeIfPresent(Double.self, forKey: .lon) ?? 0
        track = try c.decodeIfPresent(Int.self, forKey: .track) ?? 0
        alt = try c.decodeIfPresent(Int.self, forKey: .alt) ?? 0
        gspeed = try c.decodeIfPresent(Int.self, forKey: .gspeed) ?? 0
        vspeed = try c.decodeIfPresent(Int.self, forKey: .vspeed) ?? 0
        squawk = try c.decodeIfPresent(String.self, forKey: .squawk) ?? ""
        timestamp = try c.decodeIfPresent(String.self, forKey: .timestamp) ?? ""
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        hex = try c.decodeIfPresent(String.self, forKey: .hex)
        callsign = try c.decodeIfPresent(String.self, forKey: .callsign)
        flight = try c.decodeIfPresent(String.self, forKey: .flight)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        reg = try c.decodeIfPresent(String.self, forKey: .reg)
        paintedAs = try c.decodeIfPresent(String.self, forKey: .paintedAs)
        operatingAs = try c.decodeIfPresent(String.self, forKey: .operatingAs)
        origIata = try c.decodeIfPresent(String.self, forKey: .origIata)
        origIcao = try c.decodeIfPresent(String.self, forKey: .origIcao)
        destIata = try c.decodeIfPresent(String.self, forKey: .destIata)
        destIcao = try c.decodeIfPresent(String.self, forKey: .destIcao)
        eta = try c.decodeIfPresent(String.self, forKey: .eta)
    }
}
