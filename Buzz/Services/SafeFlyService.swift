//
//  SafeFlyService.swift
//  Buzz
//
//  Created by Claude on 1/30/26.
//

import Foundation
import CoreLocation
import Combine

@MainActor
class SafeFlyService: ObservableObject {
    @Published var hourlyForecasts: [SafeFlyHour] = []
    @Published var currentKPIndex: KPIndexData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var thresholds: FlyingThresholds = .default

    private let baseURL = "https://api.weather.gov"
    private let noaaSpaceWeatherURL = "https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json"

    // Cache
    private var lastFetchTime: Date?
    private var lastFetchCoordinate: CLLocationCoordinate2D?
    private let cacheValiditySeconds: TimeInterval = 600 // 10 minutes

    // MARK: - Initialization

    init() {
        loadThresholds()
    }

    // MARK: - Fetch Combined Safe Fly Data

    func fetchSafeFlyData(coordinate: CLLocationCoordinate2D) async {
        // Check cache validity
        if let lastTime = lastFetchTime,
           let lastCoord = lastFetchCoordinate,
           Date().timeIntervalSince(lastTime) < cacheValiditySeconds {
            let latDiff = abs(lastCoord.latitude - coordinate.latitude)
            let lonDiff = abs(lastCoord.longitude - coordinate.longitude)
            if latDiff < 0.01 && lonDiff < 0.01 && !hourlyForecasts.isEmpty {
                return
            }
        }

        isLoading = true
        errorMessage = nil

        do {
            // Fetch in parallel
            async let hourlyResult = fetchHourlyForecast(coordinate: coordinate)
            async let kpResult = fetchKPIndex()

            let (hourlyData, kpData) = try await (hourlyResult, kpResult)

            // Combine and evaluate safety
            hourlyForecasts = evaluateSafety(hourly: hourlyData, kpIndex: kpData)
            currentKPIndex = kpData

            lastFetchTime = Date()
            lastFetchCoordinate = coordinate
            isLoading = false

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Fetch Hourly Forecast from NWS

    private func fetchHourlyForecast(coordinate: CLLocationCoordinate2D) async throws -> [HourlyForecast] {
        // Step 1: Get grid point
        let gridPointURL = "\(baseURL)/points/\(coordinate.latitude),\(coordinate.longitude)"
        guard let url = URL(string: gridPointURL) else {
            throw SafeFlyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SafeFlyError.invalidResponse
        }

        let gridPoint = try JSONDecoder().decode(SafeFlyGridPointResponse.self, from: data)

        // Step 2: Get hourly forecast
        guard let forecastHourlyURL = gridPoint.properties.forecastHourly,
              let hourlyURL = URL(string: forecastHourlyURL) else {
            throw SafeFlyError.missingForecastURL
        }

        var hourlyRequest = URLRequest(url: hourlyURL)
        hourlyRequest.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
        hourlyRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let (hourlyData, hourlyResponse) = try await URLSession.shared.data(for: hourlyRequest)
        guard let hourlyHttpResponse = hourlyResponse as? HTTPURLResponse,
              hourlyHttpResponse.statusCode == 200 else {
            throw SafeFlyError.invalidResponse
        }

        let forecast = try JSONDecoder().decode(HourlyForecastResponse.self, from: hourlyData)

        // Parse to model (limit to 24 hours)
        return parseHourlyForecast(Array(forecast.properties.periods.prefix(24)))
    }

    // MARK: - Fetch KP Index from NOAA

    private func fetchKPIndex() async throws -> KPIndexData? {
        guard let url = URL(string: noaaSpaceWeatherURL) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            // Parse NOAA JSON array format
            return parseKPIndexResponse(data)
        } catch {
            // KP index is optional, don't fail the whole request
            print("Could not fetch KP index: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Safety Evaluation

    private func evaluateSafety(hourly: [HourlyForecast], kpIndex: KPIndexData?) -> [SafeFlyHour] {
        return hourly.map { forecast in
            var violations: [SafetyViolation] = []
            var severity: FlyingSafetyStatus = .good

            // Wind speed check
            if forecast.windSpeed > thresholds.maxWindSpeed {
                violations.append(SafetyViolation(
                    parameter: "Wind Speed",
                    currentValue: "\(Int(forecast.windSpeed)) mph",
                    threshold: "\(Int(thresholds.maxWindSpeed)) mph",
                    severity: forecast.windSpeed > thresholds.maxWindGust ? .critical : .warning
                ))
            }

            // Wind gust check
            if let gust = forecast.windGust, gust > thresholds.maxWindGust {
                violations.append(SafetyViolation(
                    parameter: "Wind Gusts",
                    currentValue: "\(Int(gust)) mph",
                    threshold: "\(Int(thresholds.maxWindGust)) mph",
                    severity: .critical
                ))
            }

            // Temperature checks
            if forecast.temperature < thresholds.minTemperature {
                violations.append(SafetyViolation(
                    parameter: "Temperature",
                    currentValue: "\(Int(forecast.temperature))°F",
                    threshold: "Min \(Int(thresholds.minTemperature))°F",
                    severity: .warning
                ))
            }
            if forecast.temperature > thresholds.maxTemperature {
                violations.append(SafetyViolation(
                    parameter: "Temperature",
                    currentValue: "\(Int(forecast.temperature))°F",
                    threshold: "Max \(Int(thresholds.maxTemperature))°F",
                    severity: .critical
                ))
            }

            // Precipitation check
            if forecast.precipitation > thresholds.maxPrecipitation {
                violations.append(SafetyViolation(
                    parameter: "Precipitation",
                    currentValue: "\(forecast.precipitation)%",
                    threshold: "\(thresholds.maxPrecipitation)%",
                    severity: forecast.precipitation > 50 ? .critical : .warning
                ))
            }

            // Visibility check (if available)
            if let vis = forecast.visibility, vis < thresholds.minVisibility {
                violations.append(SafetyViolation(
                    parameter: "Visibility",
                    currentValue: String(format: "%.1f mi", vis),
                    threshold: String(format: "%.1f mi", thresholds.minVisibility),
                    severity: vis < 1.0 ? .critical : .warning
                ))
            }

            // KP Index check
            if let kp = kpIndex, kp.kpValue > thresholds.maxKPIndex {
                violations.append(SafetyViolation(
                    parameter: "KP Index",
                    currentValue: String(format: "%.1f", kp.kpValue),
                    threshold: String(format: "%.1f", thresholds.maxKPIndex),
                    severity: kp.kpValue > 6 ? .critical : .warning
                ))
            }

            // Determine overall status
            if violations.contains(where: { $0.severity == .critical }) {
                severity = .poor
            } else if !violations.isEmpty {
                severity = .marginal
            }

            return SafeFlyHour(
                time: forecast.time,
                forecast: forecast,
                kpIndex: kpIndex?.kpValue,
                visibility: forecast.visibility,
                safetyStatus: severity,
                violations: violations
            )
        }
    }

    // MARK: - Thresholds Management

    func saveThresholds() {
        if let encoded = try? JSONEncoder().encode(thresholds) {
            UserDefaults.standard.set(encoded, forKey: FlyingThresholds.storageKey)
        }
        // Re-evaluate safety with new thresholds
        if !hourlyForecasts.isEmpty {
            let forecasts = hourlyForecasts.map { $0.forecast }
            hourlyForecasts = evaluateSafety(hourly: forecasts, kpIndex: currentKPIndex)
        }
    }

    private func loadThresholds() {
        if let data = UserDefaults.standard.data(forKey: FlyingThresholds.storageKey),
           let decoded = try? JSONDecoder().decode(FlyingThresholds.self, from: data) {
            thresholds = decoded
        }
    }

    func resetThresholds() {
        thresholds = .default
        saveThresholds()
    }

    func clearCache() {
        lastFetchTime = nil
        lastFetchCoordinate = nil
        hourlyForecasts = []
    }

    // MARK: - Parsing Helpers

    private func parseHourlyForecast(_ periods: [HourlyForecastPeriod]) -> [HourlyForecast] {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        return periods.compactMap { period -> HourlyForecast? in
            guard let time = dateFormatter.date(from: period.startTime) else {
                return nil
            }

            // Parse wind speed (e.g., "10 mph" or "5 to 10 mph")
            var windSpeed: Double = 0
            var windGust: Double? = nil
            if let windString = period.windSpeed {
                let components = windString.components(separatedBy: " ")
                if let first = components.first, let speed = Double(first) {
                    windSpeed = speed
                }
                // Check for "to" pattern for range - use higher value as potential gust
                if windString.contains("to"), components.count >= 3 {
                    if let highSpeed = Double(components[2]) {
                        windGust = highSpeed
                    }
                }
            }

            // Estimate cloud cover from forecast
            let cloudCover = estimateCloudCover(from: period.shortForecast)

            return HourlyForecast(
                time: time,
                temperature: Double(period.temperature ?? 0),
                windSpeed: windSpeed,
                windGust: windGust,
                windDirection: period.windDirection ?? "N",
                windDirectionDegrees: nil,
                precipitation: period.probabilityOfPrecipitation?.value ?? 0,
                cloudCover: cloudCover,
                humidity: period.relativeHumidity?.value,
                shortForecast: period.shortForecast,
                visibility: nil
            )
        }
    }

    private func estimateCloudCover(from forecast: String) -> Int? {
        let lowercased = forecast.lowercased()
        if lowercased.contains("clear") || lowercased.contains("sunny") {
            return 0
        } else if lowercased.contains("mostly clear") || lowercased.contains("mostly sunny") {
            return 25
        } else if lowercased.contains("partly cloudy") || lowercased.contains("partly sunny") {
            return 50
        } else if lowercased.contains("mostly cloudy") {
            return 75
        } else if lowercased.contains("cloudy") || lowercased.contains("overcast") {
            return 100
        }
        return nil
    }

    private func parseKPIndexResponse(_ data: Data) -> KPIndexData? {
        // NOAA returns array of arrays: [["time_tag", "Kp", "a_running", ...], ...]
        // First row is headers, subsequent rows are data
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[Any]],
              jsonArray.count > 1,
              let lastRow = jsonArray.last,
              lastRow.count >= 2 else {
            return nil
        }

        // Parse KP value (index 1 in the array)
        var kpValue: Double = 0
        if let kpString = lastRow[1] as? String, let kp = Double(kpString) {
            kpValue = kp
        } else if let kp = lastRow[1] as? Double {
            kpValue = kp
        } else if let kp = lastRow[1] as? Int {
            kpValue = Double(kp)
        }

        return KPIndexData(
            timestamp: Date(),
            kpValue: kpValue,
            gScore: nil
        )
    }
}

// MARK: - Errors

enum SafeFlyError: LocalizedError {
    case invalidURL
    case invalidResponse
    case missingForecastURL
    case parsingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from weather service"
        case .missingForecastURL: return "Missing hourly forecast URL"
        case .parsingError: return "Error parsing forecast data"
        }
    }
}
