//
//  LocationTrackingService.swift
//  Buzz
//
//  Created by Xinyu Fang on 12/23/25.
//

import Foundation
import CoreLocation
import Supabase
import Combine

/// Service responsible for tracking and updating user location to the backend
@MainActor
class LocationTrackingService: NSObject, ObservableObject {
    static let shared = LocationTrackingService()
    
    private let supabase = SupabaseClient.shared.client
    private let locationManager = CLLocationManager()
    private let locationHelper = LocationHelper.shared
    
    @Published var lastKnownLocation: CLLocationCoordinate2D?
    @Published var isUpdatingLocation = false
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Set default location for simulator
        if locationHelper.isRunningInSimulator {
            lastKnownLocation = locationHelper.defaultSimulatorLocation
        }
    }
    
    /// Updates the user's last known location in the backend
    /// This should be called when the app launches and the user has granted location permissions
    func updateUserLocation(userId: UUID) async throws {
        guard !isUpdatingLocation else { return }
        
        isUpdatingLocation = true
        defer { isUpdatingLocation = false }
        
        // Get current location
        let location = await getCurrentLocation()
        
        guard let location = location else {
            print("LocationTrackingService: Unable to get current location")
            return
        }
        
        // Update location in backend
        try await updateLocationInBackend(userId: userId, latitude: location.latitude, longitude: location.longitude)
        
        lastKnownLocation = location
        print("LocationTrackingService: Successfully updated location for user \(userId)")
    }
    
    /// Gets the current location from CLLocationManager or returns simulator default
    private func getCurrentLocation() async -> CLLocationCoordinate2D? {
        // If running in simulator, use default location
        if locationHelper.isRunningInSimulator {
            return locationHelper.defaultSimulatorLocation
        }
        
        // Check authorization status
        let authStatus = locationManager.authorizationStatus
        
        guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways else {
            print("LocationTrackingService: Location authorization not granted (status: \(authStatus.rawValue))")
            return nil
        }
        
        // Request location update
        return await withCheckedContinuation { continuation in
            // Store continuation for delegate callback FIRST (before starting timeout)
            self.locationContinuation = continuation
            
            // Set a timeout to prevent hanging indefinitely
            let timeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                // Use the safe resume method that checks for nil to prevent double-resume
                self.resumeLocationContinuation(with: nil)
            }
            
            self.locationTimeoutTask = timeoutTask
            
            // Request single location update
            locationManager.requestLocation()
        }
    }
    
    /// Updates the location in the Supabase backend
    private func updateLocationInBackend(userId: UUID, latitude: Double, longitude: Double) async throws {
        let updates: [String: AnyJSON] = [
            "last_location_lat": .double(latitude),
            "last_location_lng": .double(longitude),
            "last_location_update": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        
        try await supabase
            .from("profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()
    }
    
    // MARK: - Location Continuation Handling
    
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?
    private var locationTimeoutTask: Task<Void, Never>?
    
    private func resumeLocationContinuation(with location: CLLocationCoordinate2D?) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        locationTimeoutTask?.cancel()
        locationTimeoutTask = nil
        continuation.resume(returning: location)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationTrackingService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            resumeLocationContinuation(with: location.coordinate)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("LocationTrackingService: Failed to get location - \(error.localizedDescription)")
            resumeLocationContinuation(with: nil)
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            print("LocationTrackingService: Authorization status changed to \(manager.authorizationStatus.rawValue)")
        }
    }
}

