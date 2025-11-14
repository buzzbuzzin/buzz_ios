//
//  BookingMapView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

struct BookingMapView: View {
    let bookings: [Booking]
    @Binding var selectedBooking: Booking?
    
    @StateObject private var locationManager = BookingMapLocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var hasInitializedLocation = false
    @State private var locationSubscription: AnyCancellable?
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: bookings) { booking in
                MapAnnotation(coordinate: booking.coordinate) {
                    BookingAnnotation(booking: booking, isSelected: selectedBooking?.id == booking.id)
                        .onTapGesture {
                            selectedBooking = booking
                        }
                }
            }
            
            // My Location Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        centerOnUserLocation()
                    }) {
                        Image(systemName: "location.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .padding(10)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
        .onAppear {
            locationManager.requestPermission()
            locationManager.startLocationUpdates()
            initializeMapLocation()
            
            // Subscribe to location updates to center map when location becomes available
            locationSubscription = locationManager.$currentLocation
                .compactMap { $0 }
                .sink { _ in
                    if !hasInitializedLocation {
                        centerOnUserLocation(animated: false)
                    }
                }
        }
        .onDisappear {
            locationSubscription?.cancel()
            locationSubscription = nil
        }
    }
    
    private func initializeMapLocation() {
        // First, try to center on pilot's location if available
        if let userLocation = locationManager.currentLocation {
            region = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            hasInitializedLocation = true
        } else {
            // If no location yet, center on first booking or use default location at street-scale
            if let firstBooking = bookings.first {
                region = MKCoordinateRegion(
                    center: firstBooking.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            } else {
                // Use default San Francisco location at street-scale
                region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
            // We'll update to pilot location when it becomes available via onChange
        }
    }
    
    private func centerOnUserLocation(animated: Bool = true) {
        guard let userLocation = locationManager.currentLocation else {
            // If no location available, request permission and try again
            locationManager.requestPermission()
            if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                locationManager.startLocationUpdates()
            }
            return
        }
        
        // Zoom to user location with a close-up view (street-scale)
        let newRegion = MKCoordinateRegion(
            center: userLocation,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        if animated {
            withAnimation(.easeInOut(duration: 0.5)) {
                region = newRegion
            }
        } else {
            region = newRegion
        }
        hasInitializedLocation = true
    }
}

struct BookingAnnotation: View {
    let booking: Booking
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : Color.red)
                    .frame(width: 40, height: 40)
                    .shadow(radius: 4)
                
                Image(systemName: "airplane")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
            
            Image(systemName: "triangle.fill")
                .foregroundColor(isSelected ? .blue : .red)
                .font(.system(size: 10))
                .offset(y: -5)
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Location Manager for Booking Map

class BookingMapLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
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

// MARK: - Location Picker Map

struct LocationPickerMap: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var locationName: String
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, interactionModes: .all, showsUserLocation: true)
                .onTapGesture(perform: handleMapTap)
            
            // Pin in center
            if selectedLocation != nil {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                    .offset(y: -20)
            }
        }
        .onChange(of: selectedLocation?.latitude) { _, _ in
            updateLocation()
        }
        .onChange(of: selectedLocation?.longitude) { _, _ in
            updateLocation()
        }
    }
    
    private func updateLocation() {
        if let location = selectedLocation {
            region.center = location
            reverseGeocode(location)
        }
    }
    
    private func handleMapTap(at point: CGPoint) {
        let coordinate = region.center
        selectedLocation = coordinate
    }
    
    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                var components: [String] = []
                if let name = placemark.name {
                    components.append(name)
                }
                if let locality = placemark.locality {
                    components.append(locality)
                }
                if let state = placemark.administrativeArea {
                    components.append(state)
                }
                locationName = components.joined(separator: ", ")
            }
        }
    }
}

