//
//  SafeFly.swift
//  Buzz
//
//  Created by Claude on 1/30/26.
//

import Foundation
import CoreLocation

// MARK: - Hourly Forecast

struct HourlyForecast: Identifiable {
    let id = UUID()
    let time: Date
    let temperature: Double           // Fahrenheit
    let windSpeed: Double             // mph
    let windGust: Double?             // mph
    let windDirection: String         // Cardinal direction
    let windDirectionDegrees: Int?    // 0-360
    let precipitation: Int            // percentage probability
    let cloudCover: Int?              // percentage
    let humidity: Int?                // percentage
    let shortForecast: String         // e.g., "Partly Cloudy"
    let visibility: Double?           // miles (from METAR if available)
}

// MARK: - Flying Safety Status

enum FlyingSafetyStatus: String {
    case good = "Good to Fly"
    case marginal = "Marginal"
    case poor = "Not Recommended"
    case unknown = "Unknown"

    var color: String {
        switch self {
        case .good: return "green"
        case .marginal: return "yellow"
        case .poor: return "red"
        case .unknown: return "gray"
        }
    }

    var icon: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .marginal: return "exclamationmark.triangle.fill"
        case .poor: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Safe Fly Hour (Combined Data)

struct SafeFlyHour: Identifiable {
    let id = UUID()
    let time: Date
    let forecast: HourlyForecast
    let kpIndex: Double?              // 0-9 scale
    let visibility: Double?           // miles
    var safetyStatus: FlyingSafetyStatus
    var violations: [SafetyViolation] // Which thresholds are violated
}

// MARK: - Safety Violation

struct SafetyViolation: Identifiable {
    let id = UUID()
    let parameter: String             // e.g., "Wind Speed"
    let currentValue: String          // e.g., "32 mph"
    let threshold: String             // e.g., "25 mph"
    let severity: ViolationSeverity
}

enum ViolationSeverity {
    case warning   // Marginal
    case critical  // Poor
}

// MARK: - KP Index Data

struct KPIndexData {
    let timestamp: Date
    let kpValue: Double               // 0-9 scale
    let gScore: String?               // G0-G5 geomagnetic storm scale

    var description: String {
        switch kpValue {
        case 0..<4: return "Quiet"
        case 4..<5: return "Active"
        case 5..<6: return "Minor Storm"
        case 6..<7: return "Moderate Storm"
        case 7..<8: return "Strong Storm"
        default: return "Severe Storm"
        }
    }

    var isGPSSafe: Bool {
        kpValue < 5
    }
}

// MARK: - Flying Thresholds (User Customizable)

struct FlyingThresholds: Codable {
    var maxWindSpeed: Double = 25.0        // mph
    var maxWindGust: Double = 35.0         // mph
    var minVisibility: Double = 3.0        // miles
    var maxPrecipitation: Int = 20         // percentage
    var minTemperature: Double = 32.0      // Fahrenheit
    var maxTemperature: Double = 104.0     // Fahrenheit
    var maxKPIndex: Double = 5.0           // KP scale
    var maxCloudCover: Int = 90            // percentage

    static let `default` = FlyingThresholds()

    // Keys for UserDefaults
    static let storageKey = "safeFlyThresholds"
}

// MARK: - NWS Hourly Forecast Response

struct HourlyForecastResponse: Codable {
    let properties: HourlyForecastProperties
}

struct HourlyForecastProperties: Codable {
    let periods: [HourlyForecastPeriod]
}

struct HourlyForecastPeriod: Codable {
    let number: Int
    let startTime: String
    let endTime: String
    let temperature: Int?
    let temperatureUnit: String?
    let windSpeed: String?
    let windDirection: String?
    let shortForecast: String
    let probabilityOfPrecipitation: HourlyProbabilityValue?
    let relativeHumidity: HourlyHumidityPercentage?
}

struct HourlyProbabilityValue: Codable {
    let value: Int?
}

struct HourlyHumidityPercentage: Codable {
    let value: Int?
}

// MARK: - NWS Grid Point Response (for hourly forecast URL)

struct SafeFlyGridPointResponse: Codable {
    let properties: SafeFlyGridPointProperties
}

struct SafeFlyGridPointProperties: Codable {
    let forecast: String?
    let forecastHourly: String?
    let observationStations: String?
}
