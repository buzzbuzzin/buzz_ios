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
    @Published var dayGroups: [SafeFlyDayGroup] = []
    @Published var currentKPIndex: KPIndexData?
    @Published var currentVisibility: Double?  // From nearest METAR (statute miles)
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var thresholds: FlyingThresholds = .default

    private var currentCoordinate: CLLocationCoordinate2D?
    private let metarService = METARService()

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
            // Fetch in parallel: weather, KP index, and METAR for visibility
            async let hourlyResult = fetchHourlyForecast(coordinate: coordinate)
            async let kpResult = fetchKPIndex()
            async let metarResult = fetchNearestMETAR(coordinate: coordinate)

            let (hourlyData, kpData, metarData) = try await (hourlyResult, kpResult, metarResult)

            // Get visibility from nearest METAR
            currentVisibility = metarData?.visibility

            // Combine and evaluate safety (apply METAR visibility to forecasts)
            hourlyForecasts = evaluateSafety(hourly: hourlyData, kpIndex: kpData, metarVisibility: currentVisibility)
            currentKPIndex = kpData
            currentCoordinate = coordinate

            // Group hours by day with sunrise/sunset
            dayGroups = groupHoursByDay(hourlyForecasts, coordinate: coordinate)

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

        // Parse to model (extend to 48 hours for 2-day forecast)
        return parseHourlyForecast(Array(forecast.properties.periods.prefix(48)))
    }

    // MARK: - Fetch Nearest METAR for Visibility

    private func fetchNearestMETAR(coordinate: CLLocationCoordinate2D) async throws -> METAR? {
        do {
            let metars = try await metarService.fetchMETARsNearLocation(coordinate: coordinate)
            // Return the closest METAR (already sorted by distance)
            return metars.first
        } catch {
            // METAR is optional, don't fail the whole request
            print("Could not fetch METAR: \(error.localizedDescription)")
            return nil
        }
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

    private func evaluateSafety(hourly: [HourlyForecast], kpIndex: KPIndexData?, metarVisibility: Double? = nil) -> [SafeFlyHour] {
        return hourly.map { forecast in
            var violations: [SafetyViolation] = []
            var severity: FlyingSafetyStatus = .good

            // Use METAR visibility if available, otherwise use forecast visibility
            let effectiveVisibility = metarVisibility ?? forecast.visibility

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

            // Visibility check (using METAR visibility if available)
            if let vis = effectiveVisibility, vis < thresholds.minVisibility {
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
                visibility: effectiveVisibility,  // Use METAR visibility if available
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
            hourlyForecasts = evaluateSafety(hourly: forecasts, kpIndex: currentKPIndex, metarVisibility: currentVisibility)

            // Re-group days with updated safety statuses
            if let coordinate = currentCoordinate {
                dayGroups = groupHoursByDay(hourlyForecasts, coordinate: coordinate)
            }
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
        dayGroups = []
    }

    // MARK: - Day Grouping

    private func groupHoursByDay(_ hours: [SafeFlyHour], coordinate: CLLocationCoordinate2D) -> [SafeFlyDayGroup] {
        let calendar = Calendar.current

        // Group hours by day
        let grouped = Dictionary(grouping: hours) { hour in
            calendar.startOfDay(for: hour.time)
        }

        return grouped.sorted { $0.key < $1.key }.map { date, dayHours in
            let sunTimes = calculateSunTimes(for: date, coordinate: coordinate)
            return SafeFlyDayGroup(
                date: date,
                sunrise: sunTimes.sunrise,
                sunset: sunTimes.sunset,
                solarNoon: sunTimes.solarNoon,
                hours: dayHours.sorted { $0.time < $1.time }
            )
        }
    }

    // MARK: - Sunrise/Sunset Calculation

    /// Calculate sunrise, sunset, and solar noon for a given date and location
    /// Uses simplified solar position algorithm
    private func calculateSunTimes(for date: Date, coordinate: CLLocationCoordinate2D) -> (sunrise: Date?, sunset: Date?, solarNoon: Date?) {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let lat = coordinate.latitude
        let lon = coordinate.longitude

        // Fractional year in radians
        let gamma = 2 * Double.pi / 365 * (Double(dayOfYear) - 1 + 0.5)

        // Equation of time (minutes)
        let eqtime = 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
                              - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))

        // Solar declination (radians)
        let decl = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma)
                 - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma)
                 - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)

        // Hour angle at sunrise/sunset
        let latRad = lat * Double.pi / 180
        let zenith = 90.833 * Double.pi / 180 // Official sunrise/sunset zenith

        let cosHA = (cos(zenith) / (cos(latRad) * cos(decl))) - tan(latRad) * tan(decl)

        // Check for polar day/night
        guard cosHA >= -1 && cosHA <= 1 else {
            return (nil, nil, nil)
        }

        let ha = acos(cosHA) * 180 / Double.pi // Hour angle in degrees

        // Solar noon (minutes from midnight UTC)
        let solarNoonMinutes = 720 - 4 * lon - eqtime

        // Sunrise and sunset times (minutes from midnight UTC)
        let sunriseMinutes = solarNoonMinutes - ha * 4
        let sunsetMinutes = solarNoonMinutes + ha * 4

        // Convert to local time
        let startOfDay = calendar.startOfDay(for: date)

        // Get timezone offset
        let timezone = TimeZone.current
        let offsetSeconds = timezone.secondsFromGMT(for: date)

        let sunrise = startOfDay.addingTimeInterval(sunriseMinutes * 60 + Double(offsetSeconds))
        let sunset = startOfDay.addingTimeInterval(sunsetMinutes * 60 + Double(offsetSeconds))
        let solarNoon = startOfDay.addingTimeInterval(solarNoonMinutes * 60 + Double(offsetSeconds))

        return (sunrise, sunset, solarNoon)
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
            var windGust: Double = 0
            if let windString = period.windSpeed {
                let components = windString.components(separatedBy: " ")
                if let first = components.first, let speed = Double(first) {
                    windSpeed = speed
                    windGust = speed // Default gust to same as wind speed
                }
                // Check for "to" pattern for range - use higher value as gust
                if windString.contains("to"), components.count >= 3 {
                    if let highSpeed = Double(components[2]) {
                        windGust = highSpeed
                    }
                }
            }

            // Estimate cloud cover from forecast text
            let cloudCover = estimateCloudCover(from: period.shortForecast)

            return HourlyForecast(
                time: time,
                temperature: Double(period.temperature ?? 0),
                windSpeed: windSpeed,
                windGust: windGust > 0 ? windGust : nil,
                windDirection: period.windDirection ?? "N",
                windDirectionDegrees: nil,
                precipitation: period.probabilityOfPrecipitation?.value ?? 0,
                cloudCover: cloudCover,  // Now always returns a value
                humidity: period.relativeHumidity?.value,
                shortForecast: period.shortForecast,
                visibility: nil  // Will be populated from METAR
            )
        }
    }

    private func estimateCloudCover(from forecast: String) -> Int {
        let lowercased = forecast.lowercased()

        // Check from most specific to least specific patterns
        // Clear conditions (0-10%)
        if lowercased.contains("sunny") && !lowercased.contains("partly") && !lowercased.contains("mostly") {
            return 0
        }
        if lowercased.contains("clear") && !lowercased.contains("partly") && !lowercased.contains("mostly") {
            return 0
        }

        // Mostly clear/sunny (10-25%)
        if lowercased.contains("mostly clear") || lowercased.contains("mostly sunny") {
            return 20
        }

        // Partly cloudy/sunny (25-50%)
        if lowercased.contains("partly cloudy") || lowercased.contains("partly sunny") ||
           lowercased.contains("a few clouds") || lowercased.contains("scattered clouds") {
            return 40
        }

        // Mostly cloudy (50-75%)
        if lowercased.contains("mostly cloudy") || lowercased.contains("considerable cloudiness") {
            return 70
        }

        // Overcast/Cloudy (75-100%)
        if lowercased.contains("overcast") || lowercased.contains("cloudy") {
            return 90
        }

        // Weather conditions that imply high cloud cover
        if lowercased.contains("rain") || lowercased.contains("shower") ||
           lowercased.contains("storm") || lowercased.contains("thunder") ||
           lowercased.contains("snow") || lowercased.contains("sleet") ||
           lowercased.contains("drizzle") || lowercased.contains("freezing") {
            return 85
        }

        // Fog/mist conditions
        if lowercased.contains("fog") || lowercased.contains("mist") ||
           lowercased.contains("haze") || lowercased.contains("smoke") {
            return 80
        }

        // Patchy conditions
        if lowercased.contains("patchy") {
            return 50
        }

        // Default to partly cloudy if we can't determine
        return 50
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
