//
//  LocationTestHelper.swift
//  BuzzTests
//
//  Created for testing GPS location in iOS Simulator
//

import XCTest
import CoreLocation

/// Test helper to set GPS location in iOS Simulator for testing Flight Radar and location-based features
/// 
/// Usage:
/// 1. Run this test in the simulator
/// 2. The simulator's location will be set to the specified coordinates
/// 3. You can then test location-dependent features like Flight Radar
final class LocationTestHelper: XCTestCase {
    
    // MARK: - Test Locations
    
    /// San Francisco, CA - Near demo drone locations (good for testing nearby drone detection)
    /// This location is close to demo drones at 37.7749/-122.4194 and 37.7849/-122.4094
    func testSetLocationSanFrancisco() throws {
        let sanFranciscoLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        XCUIDevice.shared.location = XCUILocation(location: sanFranciscoLocation)
        
        // Optional: Add a small delay to ensure location is set
        Thread.sleep(forTimeInterval: 1.0)
        
        print("✅ Set simulator location to San Francisco, CA")
        print("   Latitude: 37.7749, Longitude: -122.4194")
        print("   This location is near demo drone positions for testing Flight Radar")
    }
    
    /// Los Angeles, CA - Near demo drone location
    func testSetLocationLosAngeles() throws {
        let losAngelesLocation = CLLocation(latitude: 34.0522, longitude: -118.2437)
        XCUIDevice.shared.location = XCUILocation(location: losAngelesLocation)
        
        Thread.sleep(forTimeInterval: 1.0)
        
        print("✅ Set simulator location to Los Angeles, CA")
        print("   Latitude: 34.0522, Longitude: -118.2437")
    }
    
    /// New York, NY - Near demo drone locations
    func testSetLocationNewYork() throws {
        let newYorkLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        XCUIDevice.shared.location = XCUILocation(location: newYorkLocation)
        
        Thread.sleep(forTimeInterval: 1.0)
        
        print("✅ Set simulator location to New York, NY")
        print("   Latitude: 40.7128, Longitude: -74.0060")
    }
    
    /// Custom location - Modify coordinates as needed for testing
    func testSetCustomLocation() throws {
        // Customize these coordinates for your testing needs
        let customLatitude: Double = 37.7749
        let customLongitude: Double = -122.4194
        
        let customLocation = CLLocation(latitude: customLatitude, longitude: customLongitude)
        XCUIDevice.shared.location = XCUILocation(location: customLocation)
        
        Thread.sleep(forTimeInterval: 1.0)
        
        print("✅ Set simulator location to custom coordinates")
        print("   Latitude: \(customLatitude), Longitude: \(customLongitude)")
    }
    
    /// Location with nearby drones - Good for testing "Caution" safety status
    /// This location is ~800m from the demo drone at 37.7849/-122.4094
    func testSetLocationWithNearbyDrones() throws {
        // Location close to demo drone (within 1 km for testing nearby detection)
        let nearbyLocation = CLLocation(latitude: 37.7799, longitude: -122.4144)
        XCUIDevice.shared.location = XCUILocation(location: nearbyLocation)
        
        Thread.sleep(forTimeInterval: 1.0)
        
        print("✅ Set simulator location near active drones")
        print("   Latitude: 37.7799, Longitude: -122.4144")
        print("   This should trigger 'Caution' status in Flight Radar")
    }
    
    /// Location far from drones - Good for testing "Safe" safety status
    func testSetLocationFarFromDrones() throws {
        // Location far from all demo drones (should show "Safe" status)
        let remoteLocation = CLLocation(latitude: 38.0000, longitude: -122.0000)
        XCUIDevice.shared.location = XCUILocation(location: remoteLocation)
        
        Thread.sleep(forTimeInterval: 1.0)
        
        print("✅ Set simulator location far from active drones")
        print("   Latitude: 38.0000, Longitude: -122.0000")
        print("   This should show 'Safe to Fly' status in Flight Radar")
    }
}

