//
//  WeatherView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import CoreLocation
import Combine
import Auth

struct WeatherView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var weatherService = WeatherService()
    @StateObject private var bookingService = BookingService()
    @StateObject private var locationManager = WeatherLocationManager()
    @ObservedObject private var nwsAlertService = NWSAlertService.shared

    @State private var currentLocationName: String = "Current Location"
    @State private var upcomingBooking: Booking?

    private var measurementSystem: MeasurementSystem {
        authService.userProfile?.effectiveMeasurementSystem ?? .imperial
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // NWS Weather Alerts
                if !nwsAlertService.activeAlerts.isEmpty {
                    NWSAlertBannerView(alerts: nwsAlertService.activeAlerts)
                }

                // Current Location Weather
                if let weather = weatherService.currentLocationWeather {
                    WeatherCard(
                        title: "Current Location",
                        location: currentLocationName,
                        weather: weather,
                        measurementSystem: measurementSystem
                    )
                } else if weatherService.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading weather data...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "cloud.slash.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Unable to load weather data")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if let error = weatherService.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
                
                // Upcoming Booking Weather
                if let booking = upcomingBooking, let weather = weatherService.bookingLocationWeather {
                    WeatherCard(
                        title: "Upcoming Booking",
                        location: booking.locationName,
                        weather: weather,
                        measurementSystem: measurementSystem
                    )
                } else if let booking = upcomingBooking {
                    VStack(spacing: 8) {
                        Text("Upcoming Booking: \(booking.locationName)")
                            .font(.headline)
                        ProgressView()
                        Text("Loading weather data...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No upcoming bookings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding()
        }
        .navigationTitle("Weather")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadWeatherData()
        }
        .refreshable {
            await loadWeatherData()
        }
        .onChange(of: locationManager.currentLocation?.latitude) { _, _ in
            if locationManager.currentLocation != nil {
                Task {
                    await loadCurrentLocationWeather()
                }
            }
        }
        .onChange(of: locationManager.currentLocation?.longitude) { _, _ in
            if locationManager.currentLocation != nil {
                Task {
                    await loadCurrentLocationWeather()
                }
            }
        }
    }
    
    private func loadWeatherData() async {
        // Request location permission if needed
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestPermission()
        }
        
        // Start location updates (if permission granted)
        if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startLocationUpdates()
            // Wait a moment for location to be acquired
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // Load current location weather
        await loadCurrentLocationWeather()
        
        // Load upcoming booking
        await loadUpcomingBooking()
        
        // Load booking location weather if available
        if let booking = upcomingBooking {
            await loadBookingLocationWeather(booking: booking)
        }
    }
    
    private func loadCurrentLocationWeather() async {
        guard let userProfile = authService.userProfile,
              userProfile.userType == .pilot else { return }
        
        // Wait for location to be available - check multiple times if needed
        var deviceLocation: CLLocationCoordinate2D? = locationManager.currentLocation
        
        // If location is not immediately available, wait a bit and check again
        if deviceLocation == nil {
            // Wait for location updates (up to 3 seconds)
            for _ in 0..<6 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                deviceLocation = locationManager.currentLocation
                if deviceLocation != nil {
                    break
                }
            }
        }
        
        // Only proceed if we have a location
        guard let location = deviceLocation else {
            print("Unable to get device location for weather")
            return
        }
            
            // Reverse geocode to get location name
            let geocoder = CLGeocoder()
        var locationName: String = "Current Location"
        
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(CLLocation(latitude: location.latitude, longitude: location.longitude))
                if let placemark = placemarks.first {
                    if let city = placemark.locality, let state = placemark.administrativeArea {
                        locationName = "\(city), \(state)"
                    } else if let name = placemark.name {
                        locationName = name
                }
                }
            } catch {
            print("Error reverse geocoding: \(error.localizedDescription)")
        }
        
        // Fetch weather
        do {
            let weather = try await weatherService.fetchWeatherForLocation(
                coordinate: location,
                locationName: locationName
            )
            weatherService.currentLocationWeather = weather
            currentLocationName = locationName
            
            // Check for weather changes and notify pilot if needed
            if let pilotId = authService.currentUser?.id {
                await weatherService.checkForWeatherChanges(
                    pilotId: pilotId,
                    weather: weather,
                    locationName: locationName
                )
                // Check for NWS weather alerts
                await weatherService.checkForNWSAlerts(
                    pilotId: pilotId,
                    coordinate: location
                )
            }
        } catch {
            print("Error fetching current location weather: \(error.localizedDescription)")
        }
    }
    
    private func loadUpcomingBooking() async {
        guard let currentUser = authService.currentUser,
              let userProfile = authService.userProfile,
              userProfile.userType == .pilot else { return }
        
        do {
            try await bookingService.fetchMyBookings(userId: currentUser.id, isPilot: true)
            
            // Find the next upcoming accepted booking
            let now = Date()
            upcomingBooking = bookingService.myBookings
                .filter { $0.status == .accepted }
                .filter { booking in
                    if let scheduledDate = booking.scheduledDate {
                        return scheduledDate > now
                    }
                    return false
                }
                .sorted { booking1, booking2 in
                    guard let date1 = booking1.scheduledDate, let date2 = booking2.scheduledDate else {
                        return false
                    }
                    return date1 < date2
                }
                .first
        } catch {
            print("Error loading bookings: \(error.localizedDescription)")
        }
    }
    
    private func loadBookingLocationWeather(booking: Booking) async {
        do {
            let weather = try await weatherService.fetchWeatherForLocation(
                coordinate: booking.coordinate,
                locationName: booking.locationName
            )
            weatherService.bookingLocationWeather = weather
        } catch {
            print("Error fetching booking location weather: \(error.localizedDescription)")
        }
    }
}

// MARK: - Location Manager for Weather

class WeatherLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
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
        
        // If permission was just granted, start location updates
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

// MARK: - Weather Card

struct WeatherCard: View {
    let title: String
    let location: String
    let weather: Weather
    let measurementSystem: MeasurementSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text(location)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            // Current Weather Summary
            HStack(alignment: .top, spacing: 16) {
                // Temperature
                VStack(alignment: .leading, spacing: 4) {
                    Text(MeasurementFormatter.temperature(weather.temperature, system: measurementSystem))
                        .font(.system(size: 48, weight: .bold))
                    
                    if let min = weather.temperatureMin, let max = weather.temperatureMax {
                        HStack(spacing: 8) {
                            Text("Min \(MeasurementFormatter.temperature(min, system: measurementSystem))")
                            Text("Max \(MeasurementFormatter.temperature(max, system: measurementSystem))")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Condition
                VStack(alignment: .trailing, spacing: 4) {
                    if let iconName = weather.conditionIcon {
                        Image(systemName: iconName)
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    }
                    Text(weather.condition)
                        .font(.subheadline)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Divider()
            
            // Wind Information
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "wind")
                        .font(.title3)
                        .foregroundColor(.blue)
                    Text("WIND")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading)
                ], spacing: 16) {
                    WindInfoRow(label: "Wind", value: MeasurementFormatter.windSpeed(weather.windSpeed, system: measurementSystem))
                    
                    WindInfoRow(
                        label: "Gusts",
                        value: weather.windGust.map { MeasurementFormatter.windSpeed($0, system: measurementSystem) } ?? "N/A"
                    )
                    
                    if let degrees = weather.windDirectionDegrees {
                        WindInfoRow(
                            label: "Direction",
                            value: "\(degrees)° \(weather.windDirection)"
                        )
                    } else {
                        WindInfoRow(label: "Direction", value: weather.windDirection)
                    }
                }
            }
            
            Divider()
            
            // Flying Conditions
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "airplane")
                        .font(.title3)
                        .foregroundColor(.blue)
                    Text("Flying Condition")
                        .font(.headline)
                }
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading)
                ], spacing: 16) {
                    ConditionMetric(label: "Precipitation", value: weather.precipitation.map { "\($0)%" } ?? "0%")
                    ConditionMetric(label: "LowAltCloud", value: weather.lowAltCloud.map { "\($0)%" } ?? "0%")
                    ConditionMetric(label: "Humidity", value: "\(weather.humidity)%")
                    ConditionMetric(label: "Cloud Cover", value: weather.cloudCover.map { "\($0)%" } ?? "N/A")
                    ConditionMetric(label: "HighAltCloud", value: weather.highAltCloud.map { "\($0)%" } ?? "0%")
                }
            }
            
            // Sunshine Hours
            if let sunrise = weather.sunrise, let sunset = weather.sunset {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                        Text("Sunshine Hours")
                            .font(.headline)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sunrise")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(sunrise))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        // Sun arc visualization (simplified)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 8, height: 8)
                            Rectangle()
                                .fill(Color.yellow.opacity(0.3))
                                .frame(height: 2)
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 8, height: 8)
                        }
                        .frame(maxWidth: 100)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Sunset")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(sunset))
                                .font(.subheadline)
                                .fontWeight(.medium)
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
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Wind Info Row

struct WindInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Condition Metric

struct ConditionMetric: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - METAR Section View

struct METARSectionView: View {
    @ObservedObject var metarService: METARService
    let userCoordinate: CLLocationCoordinate2D?
    var title: String = "Nearby METAR Reports"
    var helperText: String? = nil
    var loadingMessage: String = "Loading aviation weather..."
    var emptyStateTitle: String = "No nearby airports found"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "airplane.departure")
                    .font(.title3)
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    if let helperText {
                        Text(helperText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            
            if metarService.nearbyMETARs.isEmpty {
                if metarService.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Text(loadingMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "airplane.circle")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text(emptyStateTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if let error = metarService.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                if metarService.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Refreshing aviation weather...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }

                ForEach(metarService.nearbyMETARs) { metar in
                    METARCard(metar: metar, userCoordinate: userCoordinate)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - METAR Card

struct METARCard: View {
    let metar: METAR
    let userCoordinate: CLLocationCoordinate2D?
    
    @State private var showRawMETAR = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with station ID and flight category
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(metar.stationId)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        // Flight category badge
                        FlightCategoryBadge(category: metar.flightCategory)
                    }
                    
                    if let name = metar.stationName {
                        Text(name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Distance from user
                if let coordinate = userCoordinate {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(metar.formattedDistance(from: coordinate))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("away")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Key metrics grid
            LazyVGrid(columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading)
            ], spacing: 12) {
                // Visibility
                METARMetric(
                    icon: "eye.fill",
                    label: "Visibility",
                    value: metar.visibility.map { "\(formatVisibility($0)) SM" } ?? "N/A"
                )
                
                // Wind
                METARMetric(
                    icon: "wind",
                    label: "Wind",
                    value: formatWind()
                )
                
                // Altimeter
                METARMetric(
                    icon: "gauge",
                    label: "Altimeter",
                    value: metar.altimeter.map { String(format: "%.2f\"", $0) } ?? "N/A"
                )
                
                // Temperature
                METARMetric(
                    icon: "thermometer",
                    label: "Temp",
                    value: metar.temperature.map { "\(Int($0))°C" } ?? "N/A"
                )
                
                // Dewpoint
                METARMetric(
                    icon: "drop.fill",
                    label: "Dewpoint",
                    value: metar.dewpoint.map { "\(Int($0))°C" } ?? "N/A"
                )
                
                // Ceiling
                METARMetric(
                    icon: "cloud.fill",
                    label: "Ceiling",
                    value: formatCeiling()
                )
            }
            
            // Weather phenomena if present
            if let wx = metar.weatherPhenomena, !wx.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "cloud.rain.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Weather: \(wx)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Observation time
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Observed: \(formatObservationTime(metar.observationTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Toggle raw METAR
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showRawMETAR.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showRawMETAR ? "Hide" : "Raw")
                            .font(.caption)
                        Image(systemName: showRawMETAR ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // Raw METAR text (collapsible)
            if showRawMETAR {
                Text(metar.rawText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func formatVisibility(_ visibility: Double) -> String {
        if visibility >= 10 {
            return "10+"
        } else if visibility == floor(visibility) {
            return String(format: "%.0f", visibility)
        } else {
            return String(format: "%.1f", visibility)
        }
    }
    
    private func formatWind() -> String {
        guard let speed = metar.windSpeed else { return "Calm" }
        if speed == 0 { return "Calm" }
        
        var result = ""
        if let dir = metar.windDirection {
            result = String(format: "%03d°", dir)
        } else {
            result = "VRB"
        }
        result += "/\(speed)"
        
        if let gust = metar.windGust, gust > speed {
            result += "G\(gust)"
        }
        result += "kt"
        
        return result
    }
    
    private func formatCeiling() -> String {
        // Find the lowest BKN or OVC layer
        let ceilingLayers = metar.clouds.filter { 
            $0.cover == .bkn || $0.cover == .ovc || $0.cover == .vv 
        }
        
        if let lowestCeiling = ceilingLayers.compactMap({ $0.base }).min() {
            if lowestCeiling >= 10000 {
                return "\(lowestCeiling/1000)k ft"
            }
            return "\(lowestCeiling) ft"
        }
        
        // If no ceiling, check if there are any clouds
        if metar.clouds.isEmpty || metar.clouds.allSatisfy({ $0.cover == .skc || $0.cover == .clr }) {
            return "Clear"
        }
        
        return "N/A"
    }
    
    private func formatObservationTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm 'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}

// MARK: - Flight Category Badge

struct FlightCategoryBadge: View {
    let category: FlightCategory
    
    var badgeColor: Color {
        switch category {
        case .vfr: return .green
        case .mvfr: return .blue
        case .ifr: return .red
        case .lifr: return .purple
        case .unknown: return .gray
        }
    }
    
    var body: some View {
        Text(category.rawValue)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor)
            .cornerRadius(4)
    }
}

// MARK: - METAR Metric

struct METARMetric: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - NWS Alert Banner

struct NWSAlertBannerView: View {
    let alerts: [NWSAlertFeature]
    @State private var expandedAlertId: String?

    var body: some View {
        VStack(spacing: 8) {
            ForEach(alerts) { alert in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: severityIcon(alert.properties.severity))
                            .foregroundColor(severityColor(alert.properties.severity))
                        Text(alert.properties.event)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: expandedAlertId == alert.id ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedAlertId = expandedAlertId == alert.id ? nil : alert.id
                        }
                    }

                    if expandedAlertId == alert.id {
                        if let headline = alert.properties.headline {
                            Text(headline)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        if let areaDesc = alert.properties.areaDesc {
                            Text("Area: \(areaDesc)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let instruction = alert.properties.instruction {
                            Text(instruction)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(severityBackgroundColor(alert.properties.severity))
                .cornerRadius(12)
            }
        }
    }

    private func severityIcon(_ severity: String) -> String {
        switch severity {
        case "Extreme", "Severe":
            return "exclamationmark.triangle.fill"
        case "Moderate":
            return "exclamationmark.circle.fill"
        default:
            return "info.circle.fill"
        }
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity {
        case "Extreme":
            return .red
        case "Severe":
            return .orange
        case "Moderate":
            return .yellow
        default:
            return .blue
        }
    }

    private func severityBackgroundColor(_ severity: String) -> Color {
        switch severity {
        case "Extreme":
            return Color.red.opacity(0.15)
        case "Severe":
            return Color.orange.opacity(0.15)
        case "Moderate":
            return Color.yellow.opacity(0.15)
        default:
            return Color.blue.opacity(0.15)
        }
    }
}
