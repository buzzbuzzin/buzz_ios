//
//  ATIS.swift
//  Buzz
//
//  Created by Xinyu Fang on 1/27/26.
//

import Foundation
import CoreLocation

/// Represents wind information parsed from ATIS
struct ATISWind {
    let direction: Int?     // Degrees (nil if variable or calm)
    let speed: Int          // Knots
    let gust: Int?          // Knots (if gusting)
    let isVariable: Bool
    let isCalm: Bool
    
    var description: String {
        if isCalm {
            return "Calm"
        }
        
        var result = ""
        if isVariable {
            result = "VRB"
        } else if let dir = direction {
            result = String(format: "%03d°", dir)
        }
        
        result += "/\(speed)"
        
        if let gust = gust, gust > speed {
            result += "G\(gust)"
        }
        result += "kt"
        
        return result
    }
}

/// Represents an ATIS (Automatic Terminal Information Service) broadcast
struct ATIS: Identifiable {
    let id: String
    let icao: String
    let airportName: String
    let information: String      // "A", "B", "C" etc. (or full word like "ALPHA")
    let observationTime: Date?
    let rawText: String          // Full ATIS text (text format)
    let spokenText: String       // Spoken version (with phonetic alphabet)
    
    // Parsed weather data
    let wind: ATISWind?
    let visibility: String?      // e.g., "10", "3", "1/2"
    let skyCondition: String?    // e.g., "SKY CLEAR", "FEW CLOUDS AT 5000"
    let temperature: Int?        // Celsius
    let dewpoint: Int?           // Celsius
    let altimeter: Double?       // inHg (e.g., 30.02)
    
    // Runway info
    let landingRunways: [String]
    let departingRunways: [String]
    
    // Location for distance calculation
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// Calculate distance from a given coordinate in meters
    func distance(from coordinate: CLLocationCoordinate2D) -> Double {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let fromLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location.distance(from: fromLocation)
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
    
    /// Information letter converted to single letter (e.g., "ALPHA" -> "A")
    var informationLetter: String {
        let phoneticAlphabet: [String: String] = [
            "ALFA": "A", "ALPHA": "A",
            "BRAVO": "B",
            "CHARLIE": "C",
            "DELTA": "D",
            "ECHO": "E",
            "FOXTROT": "F",
            "GOLF": "G",
            "HOTEL": "H",
            "INDIA": "I",
            "JULIET": "J", "JULIETT": "J",
            "KILO": "K",
            "LIMA": "L",
            "MIKE": "M",
            "NOVEMBER": "N",
            "OSCAR": "O",
            "PAPA": "P",
            "QUEBEC": "Q",
            "ROMEO": "R",
            "SIERRA": "S",
            "TANGO": "T",
            "UNIFORM": "U",
            "VICTOR": "V",
            "WHISKEY": "W",
            "XRAY": "X", "X-RAY": "X",
            "YANKEE": "Y",
            "ZULU": "Z"
        ]
        
        let uppercased = information.uppercased()
        if let letter = phoneticAlphabet[uppercased] {
            return letter
        }
        // If it's already a single letter, return it
        if information.count == 1 {
            return information.uppercased()
        }
        return information
    }
}

/// Represents an airport from the ATIS API
struct ATISAirport: Codable, Identifiable {
    let id: Int
    let icao: String
    let name: String
    let runways: String?
    
    // Location - these may not be in the API response, so we'll handle them separately
    var latitude: Double?
    var longitude: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case icao
        case name
        case runways
    }
}
