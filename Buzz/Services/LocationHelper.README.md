# LocationHelper - Simulator Location Support

## Overview

`LocationHelper` provides automatic default GPS location when running the app in iOS Simulator. This allows you to test location-dependent features without manually setting GPS coordinates each time.

## How It Works

When the app runs in the simulator:
- All `LocationManager` classes automatically use the default simulator location
- Location-dependent features (Flight Radar, Weather, Transponder) work immediately
- No need to manually set GPS location in simulator settings

## Default Location

The default location is set to **San Francisco, CA** (37.7749, -122.4194), which is near the demo drone locations used in Flight Radar.

## Changing the Default Location

To change the default location for testing, edit `LocationHelper.swift`:

```swift
var defaultSimulatorLocation: CLLocationCoordinate2D {
    // Change this line to use a different location:
    return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    
    // Or uncomment one of these:
    // return testLocationWithNearbyDrones // Tests "Caution" status
    // return testLocationFarFromDrones    // Tests "Safe" status
    // return testLocationLosAngeles       // Los Angeles area
    // return testLocationNewYork          // New York area
}
```

## Pre-configured Test Locations

- **`testLocationWithNearbyDrones`** - Location within 1 km of active drones (tests "Caution" status in Flight Radar)
- **`testLocationFarFromDrones`** - Location far from all drones (tests "Safe" status in Flight Radar)
- **`testLocationLosAngeles`** - Los Angeles area
- **`testLocationNewYork`** - New York area

## Features Using LocationHelper

All location managers automatically use LocationHelper:
- **FlightRadarLocationManager** - For Flight Radar feature
- **LocationManager** - For Transponder location tracking
- **WeatherLocationManager** - For Weather feature

## Testing Scenarios

### Test "Safe to Fly" Status:
Change `defaultSimulatorLocation` to return `testLocationFarFromDrones`:
```swift
return testLocationFarFromDrones
```
Run the app → Open Flight Radar → Should show green "Safe to Fly" notification

### Test "Caution" Status:
Change `defaultSimulatorLocation` to return `testLocationWithNearbyDrones`:
```swift
return testLocationWithNearbyDrones
```
Run the app → Open Flight Radar → Should show orange "Caution" notification with drone count

## Real Device Behavior

On real devices, LocationHelper does not interfere with actual GPS:
- Returns `nil` from `getCurrentLocation()` on real devices
- LocationManager classes use actual GPS location from CLLocationManager
- No impact on production functionality

## Notes

- Location is set automatically when the app starts in simulator
- Location persists throughout the app session
- To test different locations, simply change `defaultSimulatorLocation` and restart the app
- Location updates automatically when CLLocationManager provides GPS updates (if permission granted)

