//
//  LocationHelper.swift
//  Buzz
//
//  Created for providing default GPS location in iOS Simulator
//

import Foundation
import CoreLocation

/// Helper class to provide default location for simulator testing
/// When running in simulator, this provides a test location instead of requiring manual GPS setup
class LocationHelper {
    static let shared = LocationHelper()
    
    // MARK: - Default Test Locations
    
    /// Default location for simulator testing (San Francisco area - near demo drones)
    /// Change this to test different scenarios:
    /// - Use testLocationWithNearbyDrones for testing "Caution" status
    /// - Use testLocationFarFromDrones for testing "Safe" status
    var defaultSimulatorLocation: CLLocationCoordinate2D {
        // San Francisco - Near demo drone locations
        return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Uncomment one of these to test different scenarios:
        // return testLocationWithNearbyDrones // For testing "Caution" status
        // return testLocationFarFromDrones    // For testing "Safe" status
        // return testLocationLosAngeles       // Los Angeles area
        // return testLocationNewYork          // New York area
    }
    
    /// Location near active drones (within 1 km) - for testing "Caution" status
    var testLocationWithNearbyDrones: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: 37.7799, longitude: -122.4144)
    }
    
    /// Location far from all drones - for testing "Safe" status
    var testLocationFarFromDrones: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: 38.0000, longitude: -122.0000)
    }
    
    /// Los Angeles area
    var testLocationLosAngeles: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
    }
    
    /// New York area
    var testLocationNewYork: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
    }
    
    // MARK: - Simulator Detection
    
    /// Check if running in iOS Simulator
    var isRunningInSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Location Provider
    
    /// Get the current device location, with fallback to simulator default location
    /// This should be called when you need the pilot's location
    func getCurrentLocation() -> CLLocationCoordinate2D? {
        if isRunningInSimulator {
            // Return default simulator location for testing
            return defaultSimulatorLocation
        }
        
        // In real device, return nil to let CLLocationManager handle it
        // The actual LocationManager classes will provide the real GPS location
        return nil
    }
    
    /// Get a CLLocation object with the current location (for distance calculations, etc.)
    func getCurrentCLLocation() -> CLLocation? {
        if let coordinate = getCurrentLocation() {
            return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
        return nil
    }
    
    private init() {}
}

