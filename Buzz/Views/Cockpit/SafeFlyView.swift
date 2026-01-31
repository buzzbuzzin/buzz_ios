//
//  SafeFlyView.swift
//  Buzz
//
//  Created by Claude on 1/30/26.
//

import SwiftUI
import CoreLocation
import Combine
import Auth

struct SafeFlyView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var safeFlyService = SafeFlyService()
    @StateObject private var locationManager = SafeFlyLocationManager()
    @State private var showSettings = false
    @State private var showDetailedTable = true

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current Status Summary
                if let firstHour = safeFlyService.hourlyForecasts.first {
                    CurrentStatusCard(
                        hour: firstHour,
                        locationString: safeFlyService.currentLocationString,
                        thresholds: safeFlyService.thresholds,
                        sunrise: safeFlyService.dayGroups.first?.sunrise,
                        sunset: safeFlyService.dayGroups.first?.sunset
                    )
                }

                // View Toggle
                if !safeFlyService.hourlyForecasts.isEmpty {
                    Picker("View Mode", selection: $showDetailedTable) {
                        Text("Table").tag(true)
                        Text("Cards").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                // Hourly Forecast - Conditional View
                if !safeFlyService.hourlyForecasts.isEmpty {
                    if showDetailedTable {
                        HourlyForecastTableView(
                            dayGroups: safeFlyService.dayGroups,
                            thresholds: safeFlyService.thresholds
                        )
                    } else {
                        HourlyForecastSection(hours: safeFlyService.hourlyForecasts)
                    }
                } else if safeFlyService.isLoading {
                    LoadingSection()
                } else if safeFlyService.errorMessage != nil {
                    EmptyStateSection(error: safeFlyService.errorMessage)
                } else {
                    // Initial state - waiting for location
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Getting your location...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding()
        }
        .navigationTitle("Safe Fly")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SafeFlySettingsView(safeFlyService: safeFlyService)
        }
        .task {
            await loadData()
        }
        .refreshable {
            safeFlyService.clearCache()
            await loadData()
        }
    }

    private func loadData() async {
        // Request location permission if needed
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestPermission()
        }

        // Start location updates
        if locationManager.authorizationStatus == .authorizedWhenInUse ||
           locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startLocationUpdates()
            // Wait a moment for location to be acquired
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        guard let location = locationManager.currentLocation else {
            // If no location, wait a bit more and try again
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if let loc = locationManager.currentLocation {
                await safeFlyService.fetchSafeFlyData(coordinate: loc)
            }
            return
        }

        await safeFlyService.fetchSafeFlyData(coordinate: location)
    }
}

// MARK: - Location Manager

class SafeFlyLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let locationHelper = LocationHelper.shared

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus

        // Set default location for simulator if running in simulator
        if locationHelper.isRunningInSimulator {
            currentLocation = locationHelper.defaultSimulatorLocation
        }
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startLocationUpdates() {
        // In simulator, use default location if no GPS available
        if locationHelper.isRunningInSimulator && currentLocation == nil {
            currentLocation = locationHelper.defaultSimulatorLocation
        }

        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            // In simulator, still provide default location even without permission
            if locationHelper.isRunningInSimulator && currentLocation == nil {
                currentLocation = locationHelper.defaultSimulatorLocation
            }
            return
        }
        manager.startUpdatingLocation()
    }

    func stopLocationUpdates() {
        manager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startLocationUpdates()
        }

        // In simulator, set default location if permission not granted
        if locationHelper.isRunningInSimulator &&
           (authorizationStatus == .denied || authorizationStatus == .notDetermined) {
            currentLocation = locationHelper.defaultSimulatorLocation
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")

        // In simulator, fallback to default location on error
        if locationHelper.isRunningInSimulator && currentLocation == nil {
            currentLocation = locationHelper.defaultSimulatorLocation
        }
    }
}

// MARK: - Current Status Card

struct CurrentStatusCard: View {
    let hour: SafeFlyHour
    let locationString: String?
    let thresholds: FlyingThresholds
    let sunrise: Date?
    let sunset: Date?

    // MARK: - Threshold Status Calculations

    private var windStatus: WeatherBoxStatus {
        let value = hour.forecast.windSpeed
        let max = thresholds.maxWindSpeed
        if value > max { return .exceeded }
        if value > max * 0.8 { return .caution }
        return .safe
    }

    private var gustStatus: WeatherBoxStatus {
        guard let gust = hour.forecast.windGust else { return .safe }
        let max = thresholds.maxWindGust
        if gust > max { return .exceeded }
        if gust > max * 0.8 { return .caution }
        return .safe
    }

    private var tempStatus: WeatherBoxStatus {
        let temp = hour.forecast.temperature
        let min = thresholds.minTemperature
        let max = thresholds.maxTemperature
        if temp < min || temp > max { return .exceeded }
        if temp < min + 5 || temp > max - 5 { return .caution }
        return .safe
    }

    private var precipStatus: WeatherBoxStatus {
        let value = hour.forecast.precipitation
        let max = thresholds.maxPrecipitation
        if value > max { return .exceeded }
        if value > Int(Double(max) * 0.8) { return .caution }
        return .safe
    }

    private var visibilityStatus: WeatherBoxStatus {
        guard let vis = hour.visibility else { return .safe }
        let min = thresholds.minVisibility
        if vis < min { return .exceeded }
        if vis < min * 1.5 { return .caution }
        return .safe
    }

    private var kpStatus: WeatherBoxStatus {
        guard let kp = hour.kpIndex else { return .safe }
        let max = thresholds.maxKPIndex
        if kp > max { return .exceeded }
        if kp > max * 0.8 { return .caution }
        return .safe
    }

    /// Returns true if ALL thresholds are within safe limits (no exceeded status)
    private var isSafeToFly: Bool {
        let statuses = [windStatus, gustStatus, tempStatus, precipStatus, visibilityStatus, kpStatus]
        return !statuses.contains(.exceeded)
    }

    /// Returns a list of exceeded thresholds with parameter name, current value, and limit
    private var exceededThresholds: [(parameter: String, current: String, limit: String)] {
        var exceeded: [(String, String, String)] = []

        if tempStatus == .exceeded {
            exceeded.append(("Temperature", "\(Int(hour.forecast.temperature))°F", "\(Int(thresholds.minTemperature))°F - \(Int(thresholds.maxTemperature))°F"))
        }
        if windStatus == .exceeded {
            exceeded.append(("Wind Speed", "\(Int(hour.forecast.windSpeed)) mph", "\(Int(thresholds.maxWindSpeed)) mph"))
        }
        if gustStatus == .exceeded, let gust = hour.forecast.windGust {
            exceeded.append(("Wind Gusts", "\(Int(gust)) mph", "\(Int(thresholds.maxWindGust)) mph"))
        }
        if precipStatus == .exceeded {
            exceeded.append(("Precipitation", "\(hour.forecast.precipitation)%", "\(thresholds.maxPrecipitation)%"))
        }
        if visibilityStatus == .exceeded, let vis = hour.visibility {
            exceeded.append(("Visibility", String(format: "%.1f mi", vis), String(format: "%.1f mi", thresholds.minVisibility)))
        }
        if kpStatus == .exceeded, let kp = hour.kpIndex {
            exceeded.append(("KP Index", String(format: "%.1f", kp), String(format: "%.1f", thresholds.maxKPIndex)))
        }

        return exceeded
    }

    /// Format time for display
    private func timeString(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top status banner
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fly?")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text(locationString.map { "Current Conditions (\($0))" } ?? "Current Conditions")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                // Large Yes/No
                Text(isSafeToFly ? "Yes" : "No")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)

                Image(systemName: isSafeToFly ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .padding(.leading, 8)
            }
            .padding()
            .background(isSafeToFly ? Color.green.opacity(0.85) : Color.red.opacity(0.85))

            // Weather boxes grid (3x3)
            VStack(spacing: 8) {
                // First row: Weather, Sun Times, Temp
                HStack(spacing: 8) {
                    WeatherConditionBox(
                        shortForecast: hour.forecast.shortForecast
                    )
                    SunTimesBox(
                        sunrise: sunrise,
                        sunset: sunset
                    )
                    WeatherBox(
                        label: "Temp",
                        value: "\(Int(hour.forecast.temperature))°F",
                        status: tempStatus
                    )
                }

                // Second row: Wind, Gusts, Wind Dir
                HStack(spacing: 8) {
                    WeatherBox(
                        label: "Wind",
                        value: "\(Int(hour.forecast.windSpeed)) mph",
                        status: windStatus
                    )
                    WeatherBox(
                        label: "Gusts",
                        value: hour.forecast.windGust.map { "\(Int($0)) mph" } ?? "-",
                        status: gustStatus
                    )
                    WindDirectionBox(
                        direction: hour.forecast.windDirection,
                        degrees: hour.forecast.windDirectionDegrees
                    )
                }

                // Third row: Precip, Visibility, Kp Index
                HStack(spacing: 8) {
                    WeatherBox(
                        label: "Precip",
                        value: "\(hour.forecast.precipitation)%",
                        status: precipStatus
                    )
                    WeatherBox(
                        label: "Visibility",
                        value: hour.visibility.map { String(format: "%.0f mi", $0) } ?? "-",
                        status: visibilityStatus
                    )
                    WeatherBox(
                        label: "Kp Index",
                        value: hour.kpIndex.map { String(format: "%.1f", $0) } ?? "-",
                        status: kpStatus
                    )
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Weather Box Status

enum WeatherBoxStatus {
    case safe
    case caution
    case exceeded

    /// Background color matching table cell colors for consistency
    var backgroundColor: Color {
        switch self {
        case .safe: return Color.green.opacity(0.15)
        case .caution: return Color.orange.opacity(0.20)
        case .exceeded: return Color.red.opacity(0.20)
        }
    }

    /// Text color for the value (darker for readability on light backgrounds)
    var textColor: Color {
        switch self {
        case .safe: return Color.green
        case .caution: return Color.orange
        case .exceeded: return Color.red
        }
    }

    /// Label text color
    var labelColor: Color {
        return .primary
    }
}

// MARK: - Uniform Box Height
private let uniformBoxHeight: CGFloat = 70

// MARK: - Weather Box

struct WeatherBox: View {
    let label: String
    let value: String
    let status: WeatherBoxStatus

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(status.labelColor)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(status.textColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: uniformBoxHeight)
        .background(status.backgroundColor)
        .cornerRadius(8)
    }
}

// MARK: - Wind Direction Box with Compass

struct WindDirectionBox: View {
    let direction: String
    let degrees: Int?

    /// Convert cardinal direction to degrees if degrees not provided
    private var rotationDegrees: Double {
        if let deg = degrees {
            // Wind direction indicates where wind comes FROM
            // Arrow should point in the direction wind blows TO (opposite direction)
            return Double(deg) + 180
        }
        // Fallback based on cardinal direction
        let directionMap: [String: Double] = [
            "N": 180, "NNE": 202.5, "NE": 225, "ENE": 247.5,
            "E": 270, "ESE": 292.5, "SE": 315, "SSE": 337.5,
            "S": 0, "SSW": 22.5, "SW": 45, "WSW": 67.5,
            "W": 90, "WNW": 112.5, "NW": 135, "NNW": 157.5
        ]
        return directionMap[direction.uppercased()] ?? 0
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("Wind Dir.")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            ZStack {
                // Compass circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: 32, height: 32)

                // Cardinal direction labels
                Text("N")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
                    .offset(y: -18)
                Text("S")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
                    .offset(y: 18)
                Text("E")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
                    .offset(x: 18)
                Text("W")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
                    .offset(x: -18)

                // Wind direction arrow
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(rotationDegrees))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: uniformBoxHeight)
        .background(Color.green.opacity(0.15))
        .cornerRadius(8)
    }
}

// MARK: - Sun Times Box

struct SunTimesBox: View {
    let sunrise: Date?
    let sunset: Date?

    private func timeString(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("Sun Times")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(timeString(sunrise))
                        .font(.caption)
                        .monospacedDigit()
                }

                HStack(spacing: 4) {
                    Image(systemName: "sunset.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(timeString(sunset))
                        .font(.caption)
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: uniformBoxHeight)
        .background(Color.yellow.opacity(0.20))
        .cornerRadius(8)
    }
}

// MARK: - Weather Condition Box

struct WeatherConditionBox: View {
    let shortForecast: String

    /// Get appropriate weather icon based on forecast description
    private var weatherIcon: String {
        let forecast = shortForecast.lowercased()
        if forecast.contains("sunny") || forecast.contains("clear") {
            return "sun.max.fill"
        } else if forecast.contains("partly cloudy") || forecast.contains("partly sunny") {
            return "cloud.sun.fill"
        } else if forecast.contains("mostly cloudy") {
            return "cloud.fill"
        } else if forecast.contains("cloudy") || forecast.contains("overcast") {
            return "smoke.fill"
        } else if forecast.contains("rain") || forecast.contains("showers") {
            return "cloud.rain.fill"
        } else if forecast.contains("thunderstorm") || forecast.contains("storm") {
            return "cloud.bolt.rain.fill"
        } else if forecast.contains("snow") {
            return "cloud.snow.fill"
        } else if forecast.contains("fog") || forecast.contains("mist") {
            return "cloud.fog.fill"
        } else if forecast.contains("wind") {
            return "wind"
        } else {
            return "cloud.fill"
        }
    }

    /// Get icon color based on weather type
    private var iconColor: Color {
        let forecast = shortForecast.lowercased()
        if forecast.contains("sunny") || forecast.contains("clear") {
            return .yellow
        } else if forecast.contains("rain") || forecast.contains("showers") {
            return .blue
        } else if forecast.contains("thunderstorm") || forecast.contains("storm") {
            return .purple
        } else if forecast.contains("snow") {
            return .cyan
        } else {
            return .gray
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("Weather")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Image(systemName: weatherIcon)
                .font(.system(size: 28))
                .foregroundColor(iconColor)
        }
        .frame(maxWidth: .infinity)
        .frame(height: uniformBoxHeight)
        .background(Color.gray.opacity(0.10))
        .cornerRadius(8)
    }
}


// MARK: - KP Index Card

struct KPIndexCard: View {
    let kpData: KPIndexData

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "sun.max.trianglebadge.exclamationmark.fill")
                        .foregroundColor(kpData.isGPSSafe ? .green : .orange)
                    Text("GPS Conditions")
                        .font(.headline)
                }
                Text("KP Index: \(String(format: "%.1f", kpData.kpValue)) - \(kpData.description)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(kpData.isGPSSafe ? "Safe" : "Caution")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(kpData.isGPSSafe ? .green : .orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(kpData.isGPSSafe ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Hourly Forecast Section

struct HourlyForecastSection: View {
    let hours: [SafeFlyHour]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("24-Hour Forecast")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(hours) { hour in
                        HourlyForecastCell(hour: hour)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Hourly Forecast Cell

struct HourlyForecastCell: View {
    let hour: SafeFlyHour

    /// Simplified status: only green (safe) or red (not safe)
    private var isSafe: Bool {
        hour.safetyStatus == .good
    }

    private var statusColor: Color {
        isSafe ? .green : .red
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: hour.time).lowercased()
    }

    var body: some View {
        VStack(spacing: 8) {
            // Time
            Text(timeString)
                .font(.caption)
                .foregroundColor(.secondary)

            // Status indicator - only checkmark (green) or xmark (red)
            Circle()
                .fill(statusColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: isSafe ? "checkmark" : "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                )

            // Temperature
            Text("\(Int(hour.forecast.temperature))°")
                .font(.subheadline)
                .fontWeight(.medium)

            // Wind
            HStack(spacing: 2) {
                Image(systemName: "wind")
                    .font(.caption2)
                Text("\(Int(hour.forecast.windSpeed))")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)

            // Precipitation
            if hour.forecast.precipitation > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.caption2)
                    Text("\(hour.forecast.precipitation)%")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
            }
        }
        .frame(width: 60)
        .padding(.vertical, 12)
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Loading & Empty States

struct LoadingSection: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading forecast data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct EmptyStateSection: View {
    let error: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud.slash.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Unable to load forecast")
                .font(.subheadline)
                .foregroundColor(.secondary)
            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    NavigationView {
        SafeFlyView()
    }
}
