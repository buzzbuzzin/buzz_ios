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
                    CurrentStatusCard(hour: firstHour, locationString: safeFlyService.currentLocationString)
                }

                // KP Index Card (if available)
                if let kpIndex = safeFlyService.currentKPIndex {
                    KPIndexCard(kpData: kpIndex)
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

    private var statusColor: Color {
        switch hour.safetyStatus {
        case .good: return .green
        case .marginal: return .red
        case .poor: return .red
        case .unknown: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Status indicator
            HStack {
                Image(systemName: hour.safetyStatus.icon)
                    .font(.system(size: 48))
                    .foregroundColor(statusColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(locationString.map { "Current Conditions (\($0))" } ?? "Current Conditions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(hour.safetyStatus.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(statusColor)
                }
                Spacer()
            }

            // Quick stats row
            HStack(spacing: 16) {
                QuickStatView(
                    icon: "thermometer",
                    value: "\(Int(hour.forecast.temperature))°F",
                    label: "Temp"
                )
                QuickStatView(
                    icon: "wind",
                    value: "\(Int(hour.forecast.windSpeed)) mph",
                    label: "Wind"
                )
                if let gust = hour.forecast.windGust {
                    QuickStatView(
                        icon: "wind",
                        value: "\(Int(gust)) mph",
                        label: "Gusts"
                    )
                }
                QuickStatView(
                    icon: "drop.fill",
                    value: "\(hour.forecast.precipitation)%",
                    label: "Precip"
                )
            }

            // Violations (if any)
            if !hour.violations.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Warnings")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    ForEach(hour.violations) { violation in
                        HStack {
                            Image(systemName: violation.severity == .critical ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(violation.severity == .critical ? .red : .yellow)
                                .font(.subheadline)
                            Text("\(violation.parameter): \(violation.currentValue)")
                                .font(.subheadline)
                            Spacer()
                            Text("Limit: \(violation.threshold)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Quick Stat View

struct QuickStatView: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
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

    private var statusColor: Color {
        switch hour.safetyStatus {
        case .good: return .green
        case .marginal: return .red
        case .poor: return .red
        case .unknown: return .gray
        }
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

            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: hour.safetyStatus == .good ? "checkmark" :
                          hour.safetyStatus == .marginal ? "exclamationmark" : "xmark")
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
