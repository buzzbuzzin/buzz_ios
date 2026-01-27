//
//  ATISView.swift
//  Buzz
//
//  Created by Xinyu Fang on 1/27/26.
//

import SwiftUI
import CoreLocation
import Auth

struct ATISView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var atisService = ATISService()
    @StateObject private var locationManager = WeatherLocationManager()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Nearby ATIS Reports
                ATISSectionView(atisService: atisService, userCoordinate: locationManager.currentLocation)
            }
            .padding()
        }
        .navigationTitle("ATIS")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadATISData()
        }
        .refreshable {
            await loadATISData()
        }
        .onChange(of: locationManager.currentLocation?.latitude) { _, _ in
            if locationManager.currentLocation != nil {
                Task {
                    await loadNearbyATIS()
                }
            }
        }
        .onChange(of: locationManager.currentLocation?.longitude) { _, _ in
            if locationManager.currentLocation != nil {
                Task {
                    await loadNearbyATIS()
                }
            }
        }
    }
    
    private func loadATISData() async {
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
        
        // Load nearby ATIS
        await loadNearbyATIS()
    }
    
    private func loadNearbyATIS() async {
        guard let userProfile = authService.userProfile,
              userProfile.userType == .pilot else { return }
        
        // Wait for location if not available
        var deviceLocation: CLLocationCoordinate2D? = locationManager.currentLocation
        if deviceLocation == nil {
            for _ in 0..<6 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                deviceLocation = locationManager.currentLocation
                if deviceLocation != nil {
                    break
                }
            }
        }
        
        guard let location = deviceLocation else {
            print("Unable to get device location for ATIS")
            return
        }
        
        do {
            _ = try await atisService.fetchATISNearLocation(coordinate: location)
        } catch {
            print("Error fetching nearby ATIS: \(error.localizedDescription)")
        }
    }
}

// MARK: - ATIS Section View

struct ATISSectionView: View {
    @ObservedObject var atisService: ATISService
    let userCoordinate: CLLocationCoordinate2D?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "radio.fill")
                    .font(.title3)
                    .foregroundColor(.purple)
                Text("Nearby ATIS Broadcasts")
                    .font(.headline)
                Spacer()
            }
            
            if atisService.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Text("Loading ATIS data...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if atisService.nearbyATIS.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "radio.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No ATIS broadcasts available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let error = atisService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(atisService.nearbyATIS) { atis in
                    ATISCard(atis: atis, userCoordinate: userCoordinate)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - ATIS Card

struct ATISCard: View {
    let atis: ATIS
    let userCoordinate: CLLocationCoordinate2D?
    
    @State private var showRawATIS = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with airport ID and information letter
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(atis.icao)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        // Information letter badge
                        ATISInfoBadge(letter: atis.informationLetter)
                    }
                    
                    Text(atis.airportName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Distance from user
                if let coordinate = userCoordinate, atis.latitude != 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(atis.formattedDistance(from: coordinate))
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
                ATISMetric(
                    icon: "eye.fill",
                    label: "Visibility",
                    value: atis.visibility.map { "\($0) SM" } ?? "N/A"
                )
                
                // Wind
                ATISMetric(
                    icon: "wind",
                    label: "Wind",
                    value: atis.wind?.description ?? "N/A"
                )
                
                // Altimeter
                ATISMetric(
                    icon: "gauge",
                    label: "Altimeter",
                    value: atis.altimeter.map { String(format: "%.2f\"", $0) } ?? "N/A"
                )
                
                // Temperature
                ATISMetric(
                    icon: "thermometer",
                    label: "Temp",
                    value: atis.temperature.map { "\($0)°C" } ?? "N/A"
                )
                
                // Dewpoint
                ATISMetric(
                    icon: "drop.fill",
                    label: "Dewpoint",
                    value: atis.dewpoint.map { "\($0)°C" } ?? "N/A"
                )
                
                // Sky Condition
                ATISMetric(
                    icon: "cloud.fill",
                    label: "Sky",
                    value: atis.skyCondition ?? "N/A"
                )
            }
            
            // Active Runways
            if !atis.landingRunways.isEmpty || !atis.departingRunways.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    if !atis.landingRunways.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "airplane.arrival")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("Landing: \(atis.landingRunways.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !atis.departingRunways.isEmpty && atis.departingRunways != atis.landingRunways {
                        HStack(spacing: 4) {
                            Image(systemName: "airplane.departure")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("Departing: \(atis.departingRunways.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Observation time
            HStack {
                if let time = atis.observationTime {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Time: \(formatObservationTime(time))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Toggle raw ATIS
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showRawATIS.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showRawATIS ? "Hide" : "Raw")
                            .font(.caption)
                        Image(systemName: showRawATIS ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.purple)
                }
            }
            
            // Raw ATIS text (collapsible)
            if showRawATIS {
                Text(atis.rawText)
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
    
    private func formatObservationTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm 'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}

// MARK: - ATIS Information Badge

struct ATISInfoBadge: View {
    let letter: String
    
    var body: some View {
        Text(letter)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(Color.purple)
            .cornerRadius(4)
    }
}

// MARK: - ATIS Metric

struct ATISMetric: View {
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
