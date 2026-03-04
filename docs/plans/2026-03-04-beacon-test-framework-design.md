# Beacon Mission Test Framework Design

**Date:** 2026-03-04
**Status:** Approved
**Motivation:** A missing `role` column in the `join_search_rescue_booking` SQL function went undetected because the join mission flow had zero test coverage. S&R methods in BookingService bypass the `BookingBackend` protocol and call Supabase directly, making them unmockable in unit tests.

## Goals

- Make all S&R/beacon methods testable via protocol abstraction
- Unit tests for every BeaconService and BookingService S&R method
- Integration tests that hit real Supabase RPCs to catch SQL-level bugs
- Follow existing project conventions (MockBackend pattern, IntegrationTestCase base class)

## Architecture

### 1. Protocol & Mock Infrastructure

**Extend `BookingBackend` protocol** with S&R methods:
- `joinSearchRescueBooking(bookingId:pilotId:)` -> `JoinCrewResponse`
- `leaveSearchRescueBooking(bookingId:pilotId:)` -> `JoinCrewResponse`
- `fetchBookingCrew(bookingId:)` -> `[BookingCrewMember]`

**Refactor `BookingService`** to call these protocol methods instead of Supabase directly.

**Create `BeaconBackend` protocol** with methods:
- `syncBadgesToTraining(userId:)`
- `getTrainingProgress(userId:)` -> `[BeaconTrainingProgress]`
- `enrollAsVolunteer(userId:)`
- `updateAvailability(userId:isAvailable:)`
- `updateLocation(userId:lat:lng:)`
- `updateNotificationRadius(userId:radiusMiles:)`
- `findNearbyVolunteers(lat:lng:radiusMiles:)` -> `[NearbyVolunteer]`
- `isUserBeaconVolunteer(userId:)` -> `Bool`
- `getVolunteerStatus(userId:)` -> `BeaconVolunteer?`
- `uploadTrainingCertificate(userId:trainingType:data:fileName:isPDF:)` -> `BeaconTrainingProgress`

**Refactor `BeaconService`** to use `BeaconBackend` protocol.

**Extend `MockBackend`** with S&R method support:
- Configurable return values: `joinSARResult`, `leaveSARResult`, `crewMembers`
- Call tracking: `joinSARCalled`, `leaveSARCalled`, `fetchCrewCalled`
- Error injection: `shouldThrowOnJoinSAR`, `shouldThrowOnLeaveSAR`

**Create `MockBeaconBackend`** following same patterns.

### 2. Unit Tests

**`BeaconServiceTests.swift`** (~15 tests):
- Training: sync badges, get progress, upload certificate (success + failure)
- Enrollment: incomplete training -> error, complete training -> success
- Volunteer status: check enrollment, get status
- Availability: toggle on/off
- Location: update coordinates
- Notification radius: update miles
- Nearby volunteers: query returns results, empty results

**`BookingServiceSARTests.swift`** (~25 tests):
- **Join mission:** success, already joined error, crew full error, booking not available error, booking not S&R error, beacon accepted notification triggered
- **Leave mission:** success, not in crew error, status revert when crew drops below threshold
- **Mark staffed:** success, insufficient crew error, wrong status error, demo mode early return
- **Complete payment:** success with hours/amount, payout notification per pilot, flight hours updated
- **Complete voluntary:** success, beacon resolved notification, flight hours updated
- **Create S&R booking:** payload fields validated, payment calculation, expiration date, beacon program flag
- **Error handling:** network failures propagated, invalid state transitions

### 3. Integration Tests

**`BeaconServiceIntegrationTests.swift`** (~8 tests):
- Upload certificate -> verify storage URL persisted
- Enroll as volunteer -> verify volunteer record created
- Availability toggle -> fetch back and verify
- Location update -> fetch back and verify
- Nearby volunteer query with real coordinates
- Training progress round-trip (create, fetch, verify)
- Enrollment fails when training incomplete
- Notification radius update round-trip

**`BookingServiceSARIntegrationTests.swift`** (~10 tests):
- **Full lifecycle:** Create S&R booking -> join pilot -> verify crew -> complete
- **Multi-pilot join:** 1st pilot joins (stays available) -> last pilot joins (transitions to accepted)
- **Join + leave cycle:** Join -> leave -> verify status reverts to available
- **Crew limit enforcement:** Fill crew -> additional join rejected with error
- **Role column validation:** After join, SELECT booking_crew and assert role = 'crew' (catches the exact bug that shipped)
- **Race condition:** Concurrent joins don't exceed crew limit (FOR UPDATE lock test)
- **Voluntary completion:** Full lifecycle without payment processing
- **Leave after acceptance:** Crew drops -> status reverts from accepted to available
- **Invalid booking type:** Join non-S&R booking returns error
- **Double join prevention:** Same pilot joining twice returns error

### 4. Test Helpers

**`BeaconTestHelpers.swift`**:
- `MockBeaconBackend` class with configurable returns and call tracking
- Factory methods: `sampleBeaconVolunteer()`, `sampleTrainingProgress()`, `sampleNearbyVolunteer()`
- Extension to `MockBackend` for S&R methods
- Integration helpers: `createTestSARBooking()`, `cleanupSARBooking()`

### 5. File Structure

```
BuzzTests/
  BeaconTestHelpers.swift          # Mock backends + factory methods
  BeaconServiceTests.swift         # Unit tests for BeaconService
  BeaconServiceIntegrationTests.swift  # Integration tests for BeaconService
  BookingServiceSARTests.swift     # Unit tests for S&R booking methods
  BookingServiceSARIntegrationTests.swift  # Integration tests for S&R RPCs
```

## Implementation Order

1. Extend `BookingBackend` protocol + refactor BookingService S&R methods
2. Create `BeaconBackend` protocol + refactor BeaconService
3. Create `BeaconTestHelpers.swift` with mocks and factories
4. Write `BookingServiceSARTests.swift` (unit tests)
5. Write `BookingServiceSARIntegrationTests.swift` (integration tests)
6. Write `BeaconServiceTests.swift` (unit tests)
7. Write `BeaconServiceIntegrationTests.swift` (integration tests)
8. Verify all tests pass via `xcodebuild test`
