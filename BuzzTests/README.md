# Location Testing Helper

This test file helps you set GPS location in the iOS Simulator for testing location-dependent features like Flight Radar.

## How to Use

1. **Add Test Target** (if not already added):
   - In Xcode, go to File → New → Target
   - Select "iOS Unit Testing Bundle"
   - Name it "BuzzTests"

2. **Run Tests**:
   - Select the test you want to run from the test navigator
   - Right-click and select "Run 'testSetLocation...'"
   - Or use Cmd+U to run all tests

3. **Test Locations Available**:
   - `testSetLocationSanFrancisco()` - Sets location to San Francisco (near demo drones)
   - `testSetLocationLosAngeles()` - Sets location to Los Angeles
   - `testSetLocationNewYork()` - Sets location to New York
   - `testSetLocationWithNearbyDrones()` - Sets location close to active drones (tests "Caution" status)
   - `testSetLocationFarFromDrones()` - Sets location far from drones (tests "Safe" status)
   - `testSetCustomLocation()` - Custom location (modify coordinates as needed)

## Testing Flight Radar Features

### Test "Safe to Fly" Status:
Run `testSetLocationFarFromDrones()` to set a location far from all active drones. The Flight Radar should show a green "Safe to Fly" notification.

### Test "Caution" Status:
Run `testSetLocationWithNearbyDrones()` to set a location within 1 km of active drones. The Flight Radar should show an orange "Caution" notification with the count of nearby drones.

### Test My Location Button:
Run any location test, then:
1. Open Flight Radar in the app
2. Tap the "My Location" button (📍)
3. The map should center and zoom to your current location

## Notes

- The location persists in the simulator until you change it or restart the simulator
- You can also manually set location in the simulator: Features → Location → Custom Location
- Location updates may take a moment to propagate to the app

