//
//  FlightRadarView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine
import Auth

enum RadarMode: String, CaseIterable {
    case all = "All"
    case drones = "Drones"
    case flights = "Flights"
}

// Wrapper to show both drones and flights on one map
struct RadarAnnotationItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let kind: Kind

    enum Kind {
        case drone(Transponder, isSelected: Bool)
        case flight(FR24FlightPosition, isSelected: Bool)
    }
}

struct FlightRadarView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var transponderService = TransponderService()
    @StateObject private var fr24Service = FlightRadar24Service()
    @StateObject private var locationManager = FlightRadarLocationManager()
    @State private var activeTransponders: [Transponder] = []
    @State private var selectedTransponder: Transponder?
    @State private var selectedFlight: FR24FlightPosition?
    @State private var radarMode: RadarMode = .all
    @State private var region = MKCoordinateRegion(
        center: LocationHelper.shared.defaultSimulatorLocation,
        span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
    )
    @State private var updateTimer: Timer?
    @State private var isLoading = false
    @State private var flightFetchTask: Task<Void, Never>?
    @State private var flightDetailsTask: Task<Void, Never>?
    
    // Filter transponders to only those with valid locations
    private var activeTranspondersWithLocation: [Transponder] {
        activeTransponders.filter { $0.lastLocation != nil }
    }
    
    // Find nearby drones within 1 km
    private var nearbyDrones: [Transponder] {
        guard let pilotLocation = locationManager.currentLocation else { return [] }
        let pilotCLLocation = CLLocation(latitude: pilotLocation.latitude, longitude: pilotLocation.longitude)
        
        return activeTranspondersWithLocation.filter { transponder in
            guard let droneLocation = transponder.lastLocation else { return false }
            let droneCLLocation = CLLocation(latitude: droneLocation.latitude, longitude: droneLocation.longitude)
            let distance = pilotCLLocation.distance(from: droneCLLocation) // distance in meters
            return distance <= 1000 // 1 km = 1000 meters
        }
    }
    
    // Safety status
    private var safetyStatus: SafetyStatus {
        if nearbyDrones.isEmpty {
            return .safe
        } else {
            return .caution
        }
    }

    // Combined annotations for "All" mode
    private var allAnnotations: [RadarAnnotationItem] {
        let droneItems = activeTranspondersWithLocation.map { transponder in
            RadarAnnotationItem(
                id: "drone-\(transponder.id.uuidString)",
                coordinate: transponder.lastLocation!,
                kind: .drone(transponder, isSelected: selectedTransponder?.id == transponder.id)
            )
        }
        let flightItems = fr24Service.flights.map { flight in
            RadarAnnotationItem(
                id: "flight-\(flight.fr24Id)",
                coordinate: flight.coordinate,
                kind: .flight(flight, isSelected: selectedFlight?.id == flight.id)
            )
        }
        return droneItems + flightItems
    }

    var body: some View {
        ZStack {
            // Map View - switches annotation source based on mode
            if radarMode == .all {
                Map(coordinateRegion: $region, annotationItems: allAnnotations) { item in
                    MapAnnotation(coordinate: item.coordinate) {
                        switch item.kind {
                        case .drone(let transponder, let isSelected):
                            DroneAnnotation(transponder: transponder, isSelected: isSelected)
                                .onTapGesture {
                                    flightDetailsTask?.cancel()
                                    withAnimation {
                                        selectedTransponder = transponder
                                        selectedFlight = nil
                                    }
                                }
                        case .flight(let flight, let isSelected):
                            FlightAnnotation(flight: flight, isSelected: isSelected)
                                .onTapGesture {
                                    selectFlight(flight)
                                }
                        }
                    }
                }
                .ignoresSafeArea(edges: .top)
            } else if radarMode == .drones {
                Map(coordinateRegion: $region, annotationItems: activeTranspondersWithLocation) { transponder in
                    MapAnnotation(coordinate: transponder.lastLocation!) {
                        DroneAnnotation(
                            transponder: transponder,
                            isSelected: selectedTransponder?.id == transponder.id
                        )
                        .onTapGesture {
                            flightDetailsTask?.cancel()
                            withAnimation {
                                selectedTransponder = transponder
                                selectedFlight = nil
                            }
                        }
                    }
                }
                .ignoresSafeArea(edges: .top)
            } else {
                Map(coordinateRegion: $region, annotationItems: fr24Service.flights) { flight in
                    MapAnnotation(coordinate: flight.coordinate) {
                        FlightAnnotation(
                            flight: flight,
                            isSelected: selectedFlight?.id == flight.id
                        )
                        .onTapGesture {
                            selectFlight(flight)
                        }
                    }
                }
                .ignoresSafeArea(edges: .top)
            }

            // Info Overlay
            VStack {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Flight Radar")
                                .font(.title2)
                                .fontWeight(.bold)

                            if radarMode == .all {
                                Text("\(activeTransponders.count) drone\(activeTransponders.count == 1 ? "" : "s"), \(fr24Service.flights.count) aircraft")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if radarMode == .drones {
                                Text("\(activeTransponders.count) active drone\(activeTransponders.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(fr24Service.flights.count) flight\(fr24Service.flights.count == 1 ? "" : "s") in view")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text("Refreshes every 10 seconds")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.7))
                        }

                        Spacer()

                        HStack(spacing: 12) {
                            // My Location Button
                            Button(action: {
                                centerOnUserLocation()
                            }) {
                                Image(systemName: "location.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }

                            // Refresh Button
                            Button(action: {
                                Task {
                                    if radarMode == .all {
                                        await loadActiveTransponders()
                                        await loadLiveFlights(force: true)
                                    } else if radarMode == .drones {
                                        await loadActiveTransponders()
                                    } else {
                                        await loadLiveFlights(force: true)
                                    }
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                        }
                    }

                    // Mode Picker
                    Picker("Mode", selection: $radarMode) {
                        ForEach(RadarMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(Color(.systemBackground).opacity(0.95))

                // Safety Notification Card (drones and all mode)
                if (radarMode == .drones || radarMode == .all), locationManager.currentLocation != nil {
                    SafetyNotificationCard(status: safetyStatus, nearbyDroneCount: nearbyDrones.count)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Error message for flights/all mode
                if (radarMode == .flights || radarMode == .all), let error = fr24Service.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.white)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Selected Drone Info Card
                if (radarMode == .drones || radarMode == .all), let selected = selectedTransponder, selected.lastLocation != nil {
                    DroneInfoCard(
                        transponder: selected,
                        onDismiss: {
                            withAnimation {
                                selectedTransponder = nil
                            }
                        },
                        onZoomToDrone: {
                            zoomToDrone(selected)
                        }
                    )
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Selected Flight Info Card
                if (radarMode == .flights || radarMode == .all), let selected = selectedFlight {
                    FlightInfoCard(
                        flight: selected,
                        onDismiss: {
                            flightDetailsTask?.cancel()
                            withAnimation {
                                selectedFlight = nil
                            }
                        },
                        onZoomToFlight: {
                            zoomToFlight(selected)
                        }
                    )
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Loading Indicator
            if isLoading || ((radarMode == .all || radarMode == .flights) && fr24Service.isLoading) {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                    .background(Color(.systemBackground).opacity(0.8))
                    .clipShape(Circle())
            }
        }
        .navigationTitle("Flight Radar")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await loadActiveTransponders()
                if radarMode == .all || radarMode == .flights {
                    await loadLiveFlights(force: true)
                }
            }
            startPeriodicUpdates()
            adjustMapRegion()
            locationManager.requestPermission()
            locationManager.startLocationUpdates()
        }
        .onDisappear {
            stopPeriodicUpdates()
            flightFetchTask?.cancel()
            flightDetailsTask?.cancel()
            locationManager.stopLocationUpdates()
        }
        .onChange(of: radarMode) { _ in
            // Clear selections when switching mode
            flightFetchTask?.cancel()
            flightDetailsTask?.cancel()
            withAnimation {
                selectedTransponder = nil
                selectedFlight = nil
            }
            // Load data for new mode
            stopPeriodicUpdates()
            switch radarMode {
            case .all:
                Task {
                    await loadActiveTransponders()
                    await loadLiveFlights(force: true)
                }
            case .drones:
                Task { await loadActiveTransponders() }
            case .flights:
                Task { await loadLiveFlights(force: true) }
            }
            startPeriodicUpdates()
        }
        .onChange(of: region.center.latitude) { _ in
            if radarMode == .flights || radarMode == .all {
                debouncedFetchFlights()
            }
        }
        .onChange(of: region.center.longitude) { _ in
            if radarMode == .flights || radarMode == .all {
                debouncedFetchFlights()
            }
        }
        .onChange(of: region.span.latitudeDelta) { _ in
            if radarMode == .flights || radarMode == .all {
                debouncedFetchFlights()
            }
        }
        .onChange(of: region.span.longitudeDelta) { _ in
            if radarMode == .flights || radarMode == .all {
                debouncedFetchFlights()
            }
        }
    }
    
    private func loadActiveTransponders() async {
        isLoading = true
        do {
            let transponders = try await transponderService.fetchAllActiveTransponders()
            await MainActor.run {
                self.activeTransponders = transponders
                self.isLoading = false
                adjustMapRegion()
            }
            
            // Check for nearby drone activity and notify if needed
            if let pilotId = authService.currentUser?.id,
               let pilotLocation = locationManager.currentLocation {
                await transponderService.checkForNearbyDroneActivity(
                    pilotId: pilotId,
                    pilotLocation: pilotLocation,
                    alertRadius: 5.0 // 5 miles
                )
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func adjustMapRegion() {
        guard !activeTransponders.isEmpty else { return }
        
        let locations = activeTransponders.compactMap { $0.lastLocation }
        guard !locations.isEmpty else { return }
        
        // Calculate bounding box
        let latitudes = locations.map { $0.latitude }
        let longitudes = locations.map { $0.longitude }
        
        let defaultLocation = LocationHelper.shared.defaultSimulatorLocation
        let minLat = latitudes.min() ?? defaultLocation.latitude
        let maxLat = latitudes.max() ?? defaultLocation.latitude
        let minLng = longitudes.min() ?? defaultLocation.longitude
        let maxLng = longitudes.max() ?? defaultLocation.longitude
        
        let centerLat = (minLat + maxLat) / 2
        let centerLng = (minLng + maxLng) / 2
        
        // Add padding
        let latDelta = max((maxLat - minLat) * 1.5, 0.1)
        let lngDelta = max((maxLng - minLng) * 1.5, 0.1)
        
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
        )
    }
    
    private func loadLiveFlights(force: Bool = false) async {
        await fr24Service.fetchFlights(region: region, force: force)
    }

    private func debouncedFetchFlights() {
        flightFetchTask?.cancel()
        flightFetchTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s debounce
            guard !Task.isCancelled else { return }
            await loadLiveFlights()
        }
    }

    private func selectFlight(_ flight: FR24FlightPosition) {
        flightDetailsTask?.cancel()
        withAnimation {
            selectedTransponder = nil
            selectedFlight = flight
        }

        flightDetailsTask = Task {
            let details = await fr24Service.fetchFlightDetails(fr24Id: flight.fr24Id)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                withAnimation {
                    selectedFlight = details ?? flight
                }
            }
        }
    }

    private func zoomToFlight(_ flight: FR24FlightPosition) {
        withAnimation(.easeInOut(duration: 0.5)) {
            region = MKCoordinateRegion(
                center: flight.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        }
    }

    private func startPeriodicUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task {
                switch await self.radarMode {
                case .all:
                    await self.loadActiveTransponders()
                    await self.loadLiveFlights()
                case .drones:
                    await self.loadActiveTransponders()
                case .flights:
                    await self.loadLiveFlights()
                }
            }
        }
    }
    
    private func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func centerOnUserLocation() {
        // If we have location, center immediately
        if let userLocation = locationManager.currentLocation {
            withAnimation(.easeInOut(duration: 0.5)) {
                region = MKCoordinateRegion(
                    center: userLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
            return
        }
        
        // If no location available, request permission and start updates
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestPermission()
        }
        
        // Start location updates if we have permission, or wait for permission to be granted
        Task {
            // Wait for permission to be granted (if it was just requested)
            if locationManager.authorizationStatus == .notDetermined {
                // Wait up to 2 seconds for user to respond to permission request
                for _ in 0..<4 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    if locationManager.authorizationStatus != .notDetermined {
                        break
                    }
                }
            }
            
            // Start location updates if we have permission
            if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                locationManager.startLocationUpdates()
                
                // Wait for location to become available (up to 3 seconds)
                for _ in 0..<6 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    if let userLocation = locationManager.currentLocation {
                        await MainActor.run {
        withAnimation(.easeInOut(duration: 0.5)) {
            region = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
                            }
                        }
                        return
                    }
                }
            }
        }
    }
    
    private func zoomToDrone(_ transponder: Transponder) {
        guard let droneLocation = transponder.lastLocation else { return }
        
        // Zoom to drone location with a close-up view
        withAnimation(.easeInOut(duration: 0.5)) {
            region = MKCoordinateRegion(
                center: droneLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
}

// MARK: - Drone Annotation

struct DroneAnnotation: View {
    let transponder: Transponder
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : Color.red)
                    .frame(width: isSelected ? 50 : 40, height: isSelected ? 50 : 40)
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Image(systemName: "airplane")
                    .foregroundColor(.white)
                    .font(.system(size: isSelected ? 22 : 18))
                    .rotationEffect(.degrees(45))
            }
            
            // Tail/pointer
            Image(systemName: "triangle.fill")
                .foregroundColor(isSelected ? .blue : .red)
                .font(.system(size: 8))
                .offset(y: -4)
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Drone Info Card

struct DroneInfoCard: View {
    let transponder: Transponder
    let onDismiss: () -> Void
    let onZoomToDrone: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transponder.deviceName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Remote ID: \(transponder.remoteId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            
            Divider()
            
            if let location = transponder.lastLocation {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Label {
                            Text(String(format: "%.6f, %.6f", location.latitude, location.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        if let lastUpdate = transponder.lastLocationUpdate {
                            Label {
                                Text(timeAgoString(from: lastUpdate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } icon: {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    // Speed and Altitude Row
                    HStack(spacing: 16) {
                        if let speed = transponder.speed {
                            Label {
                                Text(formatSpeed(speed))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } icon: {
                                Image(systemName: "speedometer")
                                    .foregroundColor(.green)
                            }
                        }
                        
                        if let altitude = transponder.altitude {
                            Label {
                                Text(formatAltitude(altitude))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } icon: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.purple)
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
            
            // Zoom Button
            Button(action: onZoomToDrone) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                    Text("Zoom to Drone")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let timeInterval = Date().timeIntervalSince(date)
        let minutes = Int(timeInterval / 60)
        let seconds = Int(timeInterval.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s ago"
        } else {
            return "\(seconds)s ago"
        }
    }
    
    private func formatSpeed(_ speedMetersPerSecond: Double) -> String {
        // Convert m/s to mph (1 m/s = 2.23694 mph)
        let speedMph = speedMetersPerSecond * 2.23694
        return String(format: "%.1f mph", speedMph)
    }
    
    private func formatAltitude(_ altitudeMeters: Double) -> String {
        // Convert meters to feet (1 meter = 3.28084 feet)
        let altitudeFeet = altitudeMeters * 3.28084
        return String(format: "%.0f ft", altitudeFeet)
    }
}

// MARK: - Flight Annotation

struct FlightAnnotation: View {
    let flight: FR24FlightPosition
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.orange : Color.orange.opacity(0.8))
                    .frame(width: isSelected ? 44 : 34, height: isSelected ? 44 : 34)
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)

                Image(systemName: "airplane")
                    .foregroundColor(.white)
                    .font(.system(size: isSelected ? 18 : 14))
                    .rotationEffect(.degrees(Double(flight.track) - 90))
            }

            if let callsign = flight.callsign {
                Text(callsign)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(.systemBackground).opacity(0.85))
                    .cornerRadius(4)
            }
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Flight Info Card

struct FlightInfoCard: View {
    let flight: FR24FlightPosition
    let onDismiss: () -> Void
    let onZoomToFlight: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(flight.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        if let reg = flight.reg {
                            Text(reg)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let type = flight.type {
                            Text(type)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }

            Divider()

            VStack(spacing: 8) {
                // Route
                if let route = flight.routeString {
                    HStack(spacing: 12) {
                        Label {
                            Text(route)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        } icon: {
                            Image(systemName: "airplane.departure")
                                .foregroundColor(.orange)
                        }

                        Spacer()

                        if let airline = flight.operatingAs ?? flight.paintedAs {
                            Text(airline)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Location
                HStack(spacing: 12) {
                    Label {
                        Text(String(format: "%.4f, %.4f", flight.lat, flight.lon))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                    }
                    Spacer()
                }

                // Speed, Altitude, Heading row
                HStack(spacing: 16) {
                    Label {
                        Text("\(flight.gspeed) kts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "speedometer")
                            .foregroundColor(.green)
                    }

                    Label {
                        Text("\(formatAltitude(flight.alt)) ft")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.purple)
                    }

                    Label {
                        Text("\(flight.track)\u{00B0}")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "safari")
                            .foregroundColor(.teal)
                    }

                    Spacer()
                }

                // Vertical speed (if non-zero)
                if flight.vspeed != 0 {
                    HStack(spacing: 12) {
                        Label {
                            Text("\(flight.vspeed > 0 ? "+" : "")\(flight.vspeed) fpm")
                                .font(.caption)
                                .foregroundColor(flight.vspeed > 0 ? .green : .orange)
                        } icon: {
                            Image(systemName: flight.vspeed > 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundColor(flight.vspeed > 0 ? .green : .orange)
                        }
                        Spacer()
                    }
                }
            }

            // Zoom Button
            Button(action: onZoomToFlight) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                    Text("Zoom to Flight")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    private func formatAltitude(_ altFeet: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: altFeet)) ?? "\(altFeet)"
    }
}

// MARK: - Safety Status

enum SafetyStatus {
    case safe
    case caution
    
    var title: String {
        switch self {
        case .safe:
            return "No active drones around"
        case .caution:
            return "Caution"
        }
    }
    
    var message: String {
        switch self {
        case .safe:
            return "Watch out for weather and obstacles"
        case .caution:
            return "Active drones flying nearby"
        }
    }
    
    var color: Color {
        switch self {
        case .safe:
            return .green
        case .caution:
            return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .safe:
            return "checkmark.shield.fill"
        case .caution:
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Safety Notification Card

struct SafetyNotificationCard: View {
    let status: SafetyStatus
    let nearbyDroneCount: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.icon)
                .font(.title3)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(status.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(status.message)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                
                if status == .caution && nearbyDroneCount > 0 {
                    Text("\(nearbyDroneCount) drone\(nearbyDroneCount == 1 ? "" : "s") within 1 km")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
        }
        .padding()
        .background(status.color)
        .cornerRadius(12)
    }
}

// MARK: - Location Manager for Flight Radar

class FlightRadarLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
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
