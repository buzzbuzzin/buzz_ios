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
    var windGust: Double?             // mph
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

// MARK: - Day Group for Table Display

struct SafeFlyDayGroup: Identifiable {
    let id = UUID()
    let date: Date
    let sunrise: Date?
    let sunset: Date?
    let solarNoon: Date?
    let hours: [SafeFlyHour]

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Dewpoint Extension

extension HourlyForecast {
    /// Approximate dewpoint from temperature and humidity using Magnus formula
    var dewpoint: Double? {
        guard let humidity = humidity, humidity > 0 else { return nil }
        // Convert Fahrenheit to Celsius
        let tempC = (temperature - 32) * 5.0 / 9.0
        let rh = Double(humidity)

        let a = 17.27
        let b = 237.7
        let alpha = ((a * tempC) / (b + tempC)) + log(rh / 100.0)
        let dewpointC = (b * alpha) / (a - alpha)

        // Convert back to Fahrenheit
        return dewpointC * 9.0 / 5.0 + 32
    }
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

// MARK: - Open-Meteo Response

struct OpenMeteoResponse: Codable {
    let hourly: OpenMeteoHourlyData
    let utcOffsetSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case hourly
        case utcOffsetSeconds = "utc_offset_seconds"
    }
}

struct OpenMeteoHourlyData: Codable {
    let time: [String]
    let windGusts10m: [Double?]
    let visibility: [Double?]
    // Extended fields for full hourly forecast (used when NWS is unavailable)
    let temperature2m: [Double?]?
    let windSpeed10m: [Double?]?
    let windDirection10m: [Int?]?
    let precipitationProbability: [Int?]?
    let cloudCover: [Int?]?
    let weatherCode: [Int?]?
    let relativeHumidity2m: [Int?]?

    enum CodingKeys: String, CodingKey {
        case time
        case windGusts10m = "wind_gusts_10m"
        case visibility
        case temperature2m = "temperature_2m"
        case windSpeed10m = "wind_speed_10m"
        case windDirection10m = "wind_direction_10m"
        case precipitationProbability = "precipitation_probability"
        case cloudCover = "cloud_cover"
        case weatherCode = "weather_code"
        case relativeHumidity2m = "relative_humidity_2m"
    }
}

/// Rich container for parsed Open-Meteo hourly data
struct OpenMeteoHourlyEntry {
    let gust: Double?        // mph
    let visibility: Double?  // miles
    let temperature: Double? // Fahrenheit
    let windSpeed: Double?   // mph
    let windDirection: Int?  // degrees
    let precipitation: Int?  // probability %
    let cloudCover: Int?     // %
    let weatherCode: Int?    // WMO code
    let humidity: Int?       // %
}
