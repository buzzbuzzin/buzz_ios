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
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var thresholds: FlyingThresholds = .default
    @Published var currentLocationString: String?

    private var currentCoordinate: CLLocationCoordinate2D?

    private let baseURL = "https://api.weather.gov"
    private let noaaSpaceWeatherURL = "https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json"
    private let openMeteoURL = "https://api.open-meteo.com/v1/forecast"

    // Cache
    private var lastFetchTime: Date?
    private var lastFetchCoordinate: CLLocationCoordinate2D?
    private let cacheValiditySeconds: TimeInterval = 600 // 10 minutes

    // MARK: - Initialization

    init() {
        loadThresholds()
    }

    // MARK: - Reverse Geocoding

    private func reverseGeocodeLocation(_ coordinate: CLLocationCoordinate2D) async {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                var locationParts: [String] = []

                if let city = placemark.locality {
                    locationParts.append(city)
                }

                if let state = placemark.administrativeArea {
                    locationParts.append(state)
                }

                currentLocationString = locationParts.isEmpty ? nil : locationParts.joined(separator: ", ")
            }
        } catch {
            // Reverse geocoding failed, but don't fail the whole request
            print("Reverse geocoding failed: \(error.localizedDescription)")
            currentLocationString = nil
        }
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
            // Fetch KP index and Open-Meteo in parallel (both global, always work)
            async let kpResult = fetchKPIndex()
            async let openMeteoResult = fetchOpenMeteoData(coordinate: coordinate)

            // Try NWS hourly (may fail for non-US locations)
            var nwsHourlyData: [HourlyForecast]? = nil
            do {
                nwsHourlyData = try await fetchHourlyForecast(coordinate: coordinate)
            } catch {
                print("NWS hourly forecast unavailable (likely non-US location): \(error.localizedDescription)")
            }

            let (kpData, openMeteoData) = try await (kpResult, openMeteoResult)

            // Build hourly data: prefer NWS, fall back to Open-Meteo
            let hourlyData: [HourlyForecast]
            if let nwsData = nwsHourlyData {
                hourlyData = nwsData
            } else {
                // Construct HourlyForecast array from Open-Meteo data alone
                hourlyData = buildHourlyForecastFromOpenMeteo(openMeteoData)
            }

            // Combine and evaluate safety using Open-Meteo data
            hourlyForecasts = evaluateSafety(hourly: hourlyData, kpIndex: kpData, openMeteoData: openMeteoData)
            currentKPIndex = kpData
            currentCoordinate = coordinate

            // Group hours by day with sunrise/sunset
            dayGroups = groupHoursByDay(hourlyForecasts, coordinate: coordinate)

            // Reverse geocode the location for display
            await reverseGeocodeLocation(coordinate)

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


    // MARK: - Fetch Hourly Data from Open-Meteo (Global)

    private func fetchOpenMeteoData(coordinate: CLLocationCoordinate2D) async throws -> [Date: OpenMeteoHourlyEntry] {
        let urlString = "\(openMeteoURL)?latitude=\(coordinate.latitude)&longitude=\(coordinate.longitude)" +
            "&hourly=temperature_2m,wind_speed_10m,wind_direction_10m,wind_gusts_10m,precipitation_probability,visibility,cloud_cover,weather_code,relative_humidity_2m" +
            "&temperature_unit=fahrenheit&wind_speed_unit=mph&forecast_days=2&timezone=auto"
        guard let url = URL(string: urlString) else {
            throw SafeFlyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SafeFlyError.invalidResponse
        }

        let openMeteoResponse = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

        // Convert to dictionary keyed by date
        // Open-Meteo uses format: "2026-01-30T00:00" (no seconds, no timezone)
        // With timezone=auto, times are in the location's local timezone
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        if let utcOffset = openMeteoResponse.utcOffsetSeconds {
            dateFormatter.timeZone = TimeZone(secondsFromGMT: utcOffset)
        } else {
            dateFormatter.timeZone = TimeZone.current
        }

        var result: [Date: OpenMeteoHourlyEntry] = [:]
        let hourly = openMeteoResponse.hourly

        for (index, timeString) in hourly.time.enumerated() {
            guard let date = dateFormatter.date(from: timeString) else { continue }

            // Visibility is always in meters from Open-Meteo regardless of unit settings
            let visibilityMiles = hourly.visibility[index].map { $0 / 1609.34 }

            // With wind_speed_unit=mph, gusts come in mph -- no conversion needed
            let gustMph = hourly.windGusts10m[index]

            // Helper to safely get optional array element
            func safeGet<T>(_ array: [T?]?) -> T? {
                guard let arr = array, index < arr.count else { return nil }
                return arr[index]
            }

            result[date] = OpenMeteoHourlyEntry(
                gust: gustMph,
                visibility: visibilityMiles,
                temperature: safeGet(hourly.temperature2m),
                windSpeed: safeGet(hourly.windSpeed10m),
                windDirection: safeGet(hourly.windDirection10m),
                precipitation: safeGet(hourly.precipitationProbability),
                cloudCover: safeGet(hourly.cloudCover),
                weatherCode: safeGet(hourly.weatherCode),
                humidity: safeGet(hourly.relativeHumidity2m)
            )
        }

        return result
    }

    // MARK: - Build Hourly Forecast from Open-Meteo (when NWS unavailable)

    func buildHourlyForecastFromOpenMeteo(_ data: [Date: OpenMeteoHourlyEntry]) -> [HourlyForecast] {
        return data.sorted { $0.key < $1.key }.prefix(48).compactMap { (date, entry) -> HourlyForecast? in
            let (forecastText, _) = OpenMeteoUtils.mapWMOWeatherCode(entry.weatherCode ?? 0)

            return HourlyForecast(
                time: date,
                temperature: entry.temperature ?? 0,
                windSpeed: entry.windSpeed ?? 0,
                windGust: entry.gust,
                windDirection: OpenMeteoUtils.cardinalDirection(from: entry.windDirection ?? 0),
                windDirectionDegrees: entry.windDirection,
                precipitation: entry.precipitation ?? 0,
                cloudCover: entry.cloudCover,
                humidity: entry.humidity,
                shortForecast: forecastText,
                visibility: entry.visibility
            )
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

    private func evaluateSafety(hourly: [HourlyForecast], kpIndex: KPIndexData?, openMeteoData: [Date: OpenMeteoHourlyEntry]) -> [SafeFlyHour] {
        return hourly.map { forecast in
            var violations: [SafetyViolation] = []
            var severity: FlyingSafetyStatus = .good

            // Get gust and visibility from Open-Meteo data for this specific hour
            let openMeteoValues = openMeteoData[forecast.time]
            let effectiveGust = openMeteoValues?.gust ?? forecast.windGust
            let effectiveVisibility = openMeteoValues?.visibility

            // Update forecast with Open-Meteo gust data if available
            var updatedForecast = forecast
            if let openMeteoGust = openMeteoValues?.gust {
                updatedForecast.windGust = openMeteoGust > 0 ? openMeteoGust : nil
            }

            // Wind speed check
            if forecast.windSpeed > thresholds.maxWindSpeed {
                violations.append(SafetyViolation(
                    parameter: "Wind Speed",
                    currentValue: "\(Int(forecast.windSpeed)) mph",
                    threshold: "\(Int(thresholds.maxWindSpeed)) mph",
                    severity: forecast.windSpeed > thresholds.maxWindGust ? .critical : .warning
                ))
            }

            // Wind gust check (using Open-Meteo data if available, otherwise forecast data)
            if let gust = effectiveGust, gust > thresholds.maxWindGust {
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

            // Visibility check (using Open-Meteo visibility)
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
                time: updatedForecast.time,
                forecast: updatedForecast,
                kpIndex: kpIndex?.kpValue,
                visibility: effectiveVisibility,  // Use Open-Meteo visibility
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
            // Create Open-Meteo data dict with current values for re-evaluation
            var openMeteoData: [Date: OpenMeteoHourlyEntry] = [:]
            for hour in hourlyForecasts {
                openMeteoData[hour.time] = OpenMeteoHourlyEntry(
                    gust: hour.forecast.windGust,
                    visibility: hour.visibility,
                    temperature: nil,
                    windSpeed: nil,
                    windDirection: nil,
                    precipitation: nil,
                    cloudCover: nil,
                    weatherCode: nil,
                    humidity: nil
                )
            }
            hourlyForecasts = evaluateSafety(hourly: forecasts, kpIndex: currentKPIndex, openMeteoData: openMeteoData)

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
                visibility: nil  // Will be populated from Open-Meteo
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
