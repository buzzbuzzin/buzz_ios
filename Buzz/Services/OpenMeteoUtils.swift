//
//  OpenMeteoUtils.swift
//  Buzz
//
//  Shared utilities for Open-Meteo API integration
//

import Foundation

enum OpenMeteoUtils {
    /// Map WMO weather code to (condition text, SF Symbol icon name)
    static func mapWMOWeatherCode(_ code: Int) -> (condition: String, icon: String) {
        switch code {
        case 0:
            return ("Clear sky", "sun.max.fill")
        case 1:
            return ("Mainly clear", "sun.max.fill")
        case 2:
            return ("Partly cloudy", "cloud.sun.fill")
        case 3:
            return ("Overcast", "cloud.fill")
        case 45, 48:
            return ("Fog", "cloud.fog.fill")
        case 51, 53, 55:
            return ("Drizzle", "cloud.drizzle.fill")
        case 56, 57:
            return ("Freezing drizzle", "cloud.sleet.fill")
        case 61:
            return ("Light rain", "cloud.rain.fill")
        case 63:
            return ("Rain", "cloud.rain.fill")
        case 65:
            return ("Heavy rain", "cloud.heavyrain.fill")
        case 66, 67:
            return ("Freezing rain", "cloud.sleet.fill")
        case 71:
            return ("Light snow", "cloud.snow.fill")
        case 73:
            return ("Snow", "cloud.snow.fill")
        case 75:
            return ("Heavy snow", "cloud.snow.fill")
        case 77:
            return ("Snow grains", "cloud.snow.fill")
        case 80, 81, 82:
            return ("Rain showers", "cloud.rain.fill")
        case 85, 86:
            return ("Snow showers", "cloud.snow.fill")
        case 95:
            return ("Thunderstorm", "cloud.bolt.fill")
        case 96, 99:
            return ("Thunderstorm with hail", "cloud.bolt.rain.fill")
        default:
            return ("Unknown", "cloud.fill")
        }
    }

    /// Convert wind direction degrees to 16-point cardinal direction string
    static func cardinalDirection(from degrees: Int) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((Double(degrees) + 11.25) / 22.5) % 16
        return directions[index]
    }
}
