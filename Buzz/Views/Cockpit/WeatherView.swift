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
    
    @State private var currentLocationName: String = "Current Location"
    @State private var upcomingBooking: Booking?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current Location Weather
                if let weather = weatherService.currentLocationWeather {
                    WeatherCard(
                        title: "Current Location",
                        location: currentLocationName,
                        weather: weather
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
                        weather: weather
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
        
        // Load current location weather (will use Ithaca if device location unavailable)
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
        
        // Try to get current location, with fallback to Ithaca for demo
        var location: CLLocationCoordinate2D
        var locationName: String
        
        if let deviceLocation = locationManager.currentLocation {
            location = deviceLocation
            
            // Reverse geocode to get location name
            let geocoder = CLGeocoder()
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(CLLocation(latitude: location.latitude, longitude: location.longitude))
                if let placemark = placemarks.first {
                    if let city = placemark.locality, let state = placemark.administrativeArea {
                        locationName = "\(city), \(state)"
                    } else if let name = placemark.name {
                        locationName = name
                    } else {
                        locationName = "Current Location"
                    }
                } else {
                    locationName = "Current Location"
                }
            } catch {
                locationName = "Current Location"
            }
        } else {
            // Use Ithaca, NY as demo location if device location is not available
            location = CLLocationCoordinate2D(latitude: 42.4430, longitude: -76.5019)
            locationName = "Ithaca, NY"
            currentLocationName = locationName
        }
        
        // Fetch weather
        do {
            let weather = try await weatherService.fetchWeatherForLocation(
                coordinate: location,
                locationName: locationName
            )
            weatherService.currentLocationWeather = weather
            currentLocationName = locationName
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
                    Text("\(Int(weather.temperature))°F")
                        .font(.system(size: 48, weight: .bold))
                    
                    if let min = weather.temperatureMin, let max = weather.temperatureMax {
                        HStack(spacing: 8) {
                            Text("Min \(Int(min))°F")
                            Text("Max \(Int(max))°F")
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
                    WindInfoRow(label: "Wind", value: "\(Int(weather.windSpeed)) mph")
                    
                    WindInfoRow(label: "Gusts", value: weather.windGust.map { "\(Int($0)) mph" } ?? "N/A")
                    
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

