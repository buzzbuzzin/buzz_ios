//
//  Weather.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import CoreLocation

struct Weather {
    let location: String
    let coordinate: CLLocationCoordinate2D
    let temperature: Double // Fahrenheit
    let temperatureMin: Double?
    let temperatureMax: Double?
    let condition: String
    let conditionIcon: String?
    let windSpeed: Double // mph
    let windDirection: String // Cardinal direction (e.g., "N", "WNW")
    let windDirectionDegrees: Int? // Degrees (0-360)
    let windGust: Double? // mph
    let humidity: Int // percentage
    let cloudCover: Int? // percentage
    let precipitation: Int? // percentage
    let lowAltCloud: Int? // percentage
    let highAltCloud: Int? // percentage
    let sunrise: Date?
    let sunset: Date?
    let lastUpdated: Date
}

