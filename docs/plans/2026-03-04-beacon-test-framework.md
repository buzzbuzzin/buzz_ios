# Beacon Mission Test Framework Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build comprehensive test coverage for all beacon/search-rescue features by adding protocol abstractions, mock backends, unit tests, and integration tests.

**Architecture:** Extend `BookingBackend` protocol with S&R methods and create new `BeaconBackend` protocol so both services can be tested with mocks. Unit tests use mocks for fast Swift-logic validation; integration tests hit real Supabase RPCs to catch SQL-level bugs.

**Tech Stack:** XCTest, Swift async/await, Supabase Swift SDK, existing MockBackend pattern

**Parallelization:** Two independent tracks:
- **Track A** (BookingService S&R): Tasks 1-5
- **Track B** (BeaconService): Tasks 6-9
- **Final:** Task 10 (build + verify all tests)

---

## Task 1: Extend BookingBackend Protocol with S&R Methods

**Files:**
- Modify: `Buzz/Services/BookingService.swift:13-19` (BookingBackend protocol)
- Modify: `Buzz/Services/BookingService.swift:2781-2832` (SupabaseBookingBackend)

**Step 1: Add S&R methods to BookingBackend protocol**

At `BookingService.swift:13-19`, add three new methods to the protocol:

```swift
protocol BookingBackend {
    func createBooking(payload: [String: AnyJSON], bookingId: UUID) async throws -> Booking
    func fetchBooking(id: UUID) async throws -> Booking
    func updateBooking(id: UUID, values: [String: AnyJSON]) async throws
    func joinAutomotiveBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse
    func fetchUserProfile(userId: UUID) async throws -> UserProfile
    // S&R crew operations
    func joinSearchRescueBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse
    func leaveSearchRescueBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse
    func fetchBookingCrew(bookingId: UUID) async throws -> [BookingCrewMember]
}
```

**Step 2: Implement S&R methods in SupabaseBookingBackend**

At `BookingService.swift:2781-2832`, add three method implementations to the struct:

```swift
func joinSearchRescueBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse {
    struct JoinResult: Codable {
        let success: Bool
        let error: String?
        let message: String?
    }
    let result: JoinResult = try await client
        .rpc("join_search_rescue_booking", params: [
            "p_booking_id": bookingId.uuidString,
            "p_pilot_id": pilotId.uuidString
        ])
        .execute()
        .value
    if !result.success {
        throw NSError(domain: "BookingService", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: result.error ?? "Failed to join mission"])
    }
    return JoinCrewResponse(success: result.success, message: result.message,
                            crewMember: nil, crewStatus: nil, error: result.error)
}

func leaveSearchRescueBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse {
    struct LeaveResult: Codable {
        let success: Bool
        let error: String?
        let message: String?
    }
    let result: LeaveResult = try await client
        .rpc("leave_search_rescue_booking", params: [
            "p_booking_id": bookingId.uuidString,
            "p_pilot_id": pilotId.uuidString
        ])
        .execute()
        .value
    if !result.success {
        throw NSError(domain: "BookingService", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: result.error ?? "Failed to leave mission"])
    }
    return JoinCrewResponse(success: result.success, message: result.message,
                            crewMember: nil, crewStatus: nil, error: result.error)
}

func fetchBookingCrew(bookingId: UUID) async throws -> [BookingCrewMember] {
    try await client
        .from("booking_crew")
        .select()
        .eq("booking_id", value: bookingId.uuidString)
        .execute()
        .value
}
```

**Step 3: Build to verify compilation**

Run: `xcodebuild -scheme Buzz -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build`
Expected: Build succeeds (MockBackend will fail - that's fixed in Task 3)

Note: The build may fail because MockBackend doesn't conform yet. That's expected and fixed in Task 3. If it fails, proceed to Task 2 before building.

**Step 4: Commit**

```bash
git add Buzz/Services/BookingService.swift
git commit -m "feat: extend BookingBackend protocol with S&R methods"
```

---

## Task 2: Refactor BookingService S&R Methods to Use Backend Protocol

**Files:**
- Modify: `Buzz/Services/BookingService.swift:1154-1209` (joinSearchRescueBooking)
- Modify: `Buzz/Services/BookingService.swift:1213-1250` (leaveSearchRescueBooking)
- Modify: `Buzz/Services/BookingService.swift:2208-2277` (markSearchRescueAsStaffed)
- Modify: `Buzz/Services/BookingService.swift:1624-1708` (completeSearchRescuePayment)
- Modify: `Buzz/Services/BookingService.swift:1711-1765` (completeVoluntaryMission)

**Step 1: Refactor joinSearchRescueBooking to use backend**

Replace the direct `supabase.rpc(...)` call with `backend.joinSearchRescueBooking(...)`. The method should become:

```swift
func joinSearchRescueBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse {
    isLoading = true
    errorMessage = nil
    do {
        let response = try await backend.joinSearchRescueBooking(bookingId: bookingId, pilotId: pilotId)
        isLoading = false

        // Notify the beacon creator that a volunteer accepted
        if !skipNetworkCalls {
            Task {
                let booking = try? await backend.fetchBooking(id: bookingId)
                let pilotProfile = try? await backend.fetchUserProfile(userId: pilotId)
                let volunteerCallSign = pilotProfile?.callSign ?? "A volunteer"
                let missionType = booking?.specialization?.displayName ?? "Search & Rescue"
                if booking != nil {
                    await notificationManager.notifyBeaconAccepted(
                        bookingId: bookingId,
                        volunteerCallSign: volunteerCallSign,
                        missionType: missionType
                    )
                }
            }
        }
        return response
    } catch {
        isLoading = false
        errorMessage = error.localizedDescription
        throw error
    }
}
```

**Step 2: Refactor leaveSearchRescueBooking to use backend**

Replace the direct `supabase.rpc(...)` call with `backend.leaveSearchRescueBooking(...)`:

```swift
func leaveSearchRescueBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse {
    isLoading = true
    errorMessage = nil
    do {
        let response = try await backend.leaveSearchRescueBooking(bookingId: bookingId, pilotId: pilotId)
        isLoading = false
        return response
    } catch {
        isLoading = false
        errorMessage = error.localizedDescription
        throw error
    }
}
```

**Step 3: Refactor markSearchRescueAsStaffed to use backend**

Replace the two direct supabase queries (fetch booking + fetch crew) with backend calls. Replace `supabase.from("bookings")...` with `backend.fetchBooking(id:)` and `supabase.from("booking_crew")...` with `backend.fetchBookingCrew(bookingId:)`. The status update stays as `backend.updateBooking(id:values:)`.

**Step 4: Refactor completeSearchRescuePayment crew fetch**

Replace the direct `supabase.from("booking_crew").select()...` call (around line 1683) with `backend.fetchBookingCrew(bookingId:)`. Keep the rest of the method as-is (payment processing uses edge functions which stay direct).

**Step 5: Refactor completeVoluntaryMission crew + booking fetch**

Replace the direct `supabase.from("bookings")...` with `backend.fetchBooking(id:)` and `supabase.from("booking_crew")...` with `backend.fetchBookingCrew(bookingId:)`.

**Step 6: Commit**

```bash
git add Buzz/Services/BookingService.swift
git commit -m "refactor: BookingService S&R methods use backend protocol"
```

---

## Task 3: Extend MockBackend with S&R Support

**Files:**
- Modify: `BuzzTests/TestHelpers.swift:15-172` (MockBackend class)

**Step 1: Add S&R properties to MockBackend**

After line 26 (`shouldThrowOnFetch`), add:

```swift
var joinSARCalled = false
var leaveSARCalled = false
var fetchCrewCalled = false
var shouldThrowOnJoinSAR = false
var shouldThrowOnLeaveSAR = false
var shouldThrowOnFetchCrew = false
var joinSARResponse: JoinCrewResponse = JoinCrewResponse(
    success: true, message: "Joined mission", crewMember: nil, crewStatus: nil, error: nil
)
var leaveSARResponse: JoinCrewResponse = JoinCrewResponse(
    success: true, message: "Left mission", crewMember: nil, crewStatus: nil, error: nil
)
var crewMembers: [BookingCrewMember] = []
```

**Step 2: Add S&R method implementations to MockBackend**

After the `fetchUserProfile` method (around line 71), add:

```swift
func joinSearchRescueBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse {
    joinSARCalled = true
    if shouldThrowOnJoinSAR {
        throw NSError(domain: "MockBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock join SAR error"])
    }
    return joinSARResponse
}

func leaveSearchRescueBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse {
    leaveSARCalled = true
    if shouldThrowOnLeaveSAR {
        throw NSError(domain: "MockBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock leave SAR error"])
    }
    return leaveSARResponse
}

func fetchBookingCrew(bookingId: UUID) async throws -> [BookingCrewMember] {
    fetchCrewCalled = true
    if shouldThrowOnFetchCrew {
        throw NSError(domain: "MockBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock fetch crew error"])
    }
    return crewMembers
}
```

**Step 3: Add sampleCrewMember factory method**

After the `sampleDispute` factory (around line 172), add:

```swift
static func sampleCrewMember(
    id: UUID = UUID(),
    bookingId: UUID = UUID(),
    pilotId: UUID = UUID(),
    role: String = "crew",
    payoutAmount: Decimal = 0
) -> BookingCrewMember {
    BookingCrewMember(
        id: id,
        bookingId: bookingId,
        pilotId: pilotId,
        role: role,
        rankAtAcceptance: 0,
        payoutAmount: payoutAmount,
        joinedAt: Date()
    )
}
```

Note: Check the actual `BookingCrewMember` struct fields before writing this. Adapt as needed.

**Step 4: Build to verify compilation**

Run: `xcodebuild -scheme Buzz -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add BuzzTests/TestHelpers.swift
git commit -m "feat: add S&R mock support to MockBackend"
```

---

## Task 4: Write BookingServiceSARTests.swift (Unit Tests)

**Files:**
- Create: `BuzzTests/BookingServiceSARTests.swift`

**Step 1: Write all unit tests**

Create the test file with ~25 tests covering all S&R booking methods. Key test groups:

**Join Mission Tests:**
- `testJoinSearchRescueBooking_success`: Mock returns success, verify `joinSARCalled`, verify response
- `testJoinSearchRescueBooking_error_propagated`: Set `shouldThrowOnJoinSAR`, verify error thrown
- `testJoinSearchRescueBooking_notifiesBeaconAccepted`: Use `skipNetworkCalls: false`, verify `beaconAcceptedCalls == 1`
- `testJoinSearchRescueBooking_skipsNotificationInSkipMode`: Use `skipNetworkCalls: true`, verify `beaconAcceptedCalls == 0`
- `testJoinSearchRescueBooking_setsLoadingState`: Verify `isLoading` is false after completion

**Leave Mission Tests:**
- `testLeaveSearchRescueBooking_success`: Mock returns success, verify `leaveSARCalled`
- `testLeaveSearchRescueBooking_error_propagated`: Set `shouldThrowOnLeaveSAR`, verify error thrown
- `testLeaveSearchRescueBooking_setsErrorMessage`: Verify `errorMessage` set on failure

**Mark Staffed Tests:**
- `testMarkSearchRescueAsStaffed_success`: Mock booking with S&R specialization + enough crew, verify update called with status "staffed"
- `testMarkSearchRescueAsStaffed_notSAR_throws`: Mock non-S&R booking, verify error thrown
- `testMarkSearchRescueAsStaffed_notAvailable_throws`: Mock booking with status != available, verify error
- `testMarkSearchRescueAsStaffed_insufficientCrew_throws`: Mock crew count < numberOfPilots, verify error
- `testMarkSearchRescueAsStaffed_demoMode_returnsEarly`: Enable demo mode, verify no backend calls

**Complete Payment Tests:**
- `testCompleteSearchRescuePayment_updatesBookingStatus`: Verify update called with status "completed"
- `testCompleteSearchRescuePayment_fetchesCrew`: Verify `fetchCrewCalled`
- `testCompleteSearchRescuePayment_notifiesBeaconResolved`: Verify `beaconResolvedCalls == 1` (skipNetworkCalls: false)

**Complete Voluntary Tests:**
- `testCompleteVoluntaryMission_updatesStatus`: Verify update called with "completed"
- `testCompleteVoluntaryMission_fetchesCrew`: Verify `fetchCrewCalled`
- `testCompleteVoluntaryMission_notifiesBeaconResolved`: Verify `beaconResolvedCalls == 1`

**Create S&R Booking Tests** (these already partially exist in BookingServiceExtendedTests - add any missing ones):
- `testCreateSearchRescueBooking_setsBeaconFields`: Verify payload includes `uses_beacon_program`, `number_of_pilots`, `assignment_type`

Pattern for each test:
```swift
import XCTest
@testable import Buzz

final class BookingServiceSARTests: XCTestCase {

    func testJoinSearchRescueBooking_success() async throws {
        let bookingId = UUID()
        let pilotId = UUID()
        let backend = MockBackend()
        backend.joinSARResponse = JoinCrewResponse(
            success: true, message: "Joined mission — 1 of 3 pilots",
            crewMember: nil, crewStatus: nil, error: nil
        )
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )

        let response = try await service.joinSearchRescueBooking(bookingId: bookingId, pilotId: pilotId)

        XCTAssertTrue(backend.joinSARCalled)
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.message, "Joined mission — 1 of 3 pilots")
    }

    // ... remaining tests follow same pattern
}
```

**Step 2: Build and run tests**

Run: `xcodebuild test -scheme Buzz -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:BuzzTests/BookingServiceSARTests`
Expected: All tests pass

**Step 3: Commit**

```bash
git add BuzzTests/BookingServiceSARTests.swift
git commit -m "test: add unit tests for BookingService S&R methods"
```

---

## Task 5: Write BookingServiceSARIntegrationTests.swift (Integration Tests)

**Files:**
- Create: `BuzzTests/BookingServiceSARIntegrationTests.swift`

**Step 1: Write integration tests**

Subclass `IntegrationTestCase` (from IntegrationTestHelpers.swift). Uses real Supabase, test user `apptest@buzzbuzzin.com`.

Key tests (~10):

```swift
import XCTest
@testable import Buzz

final class BookingServiceSARIntegrationTests: IntegrationTestCase {

    private var service: BookingService!

    override func setUp() async throws {
        try await super.setUp()
        service = BookingService(
            backend: nil, // real Supabase
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )
    }
```

**Test: Full lifecycle (create -> join -> verify crew)**
- Create S&R booking with `numberOfPilots: 1`
- Join with test user
- Fetch booking, verify status changed to "accepted" (crew full with 1 pilot)
- Clean up: delete booking_crew record, delete booking

**Test: Role column is set correctly (catches the exact bug)**
- Create S&R booking
- Join with test user
- SELECT from booking_crew WHERE booking_id, assert `role == "crew"`
- This is the test that would have caught the missing role column bug

**Test: Multi-pilot join keeps status available until full**
- Create S&R booking with `numberOfPilots: 3`
- Join with test user
- Fetch booking, verify status is still "available" (only 1 of 3)

**Test: Double join prevention**
- Create S&R booking
- Join with test user (succeeds)
- Join again with same user (should throw "Already joined")

**Test: Leave mission after joining**
- Create S&R booking, join, then leave
- Fetch booking_crew, verify empty
- Fetch booking, verify status is "available"

**Test: Crew limit enforcement**
- Create S&R booking with `numberOfPilots: 1`
- Join with test user (fills crew)
- Verify booking status changes to "accepted"
- Note: Can't test additional join without second test user

**Test: Join non-S&R booking fails**
- Create real_estate booking
- Attempt join via RPC, verify error "Not a Search & Rescue booking"

**Step 2: Run integration tests**

Run: `xcodebuild test -scheme Buzz -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:BuzzTests/BookingServiceSARIntegrationTests`
Expected: All tests pass

**Step 3: Commit**

```bash
git add BuzzTests/BookingServiceSARIntegrationTests.swift
git commit -m "test: add integration tests for S&R booking RPCs"
```

---

## Task 6: Create BeaconBackend Protocol and Refactor BeaconService

**Files:**
- Modify: `Buzz/Services/BeaconService.swift`

**Step 1: Define BeaconBackend protocol**

Add at the top of BeaconService.swift (before the class):

```swift
protocol BeaconBackend {
    func syncBadgesToTraining(userId: UUID) async throws
    func getTrainingProgress(userId: UUID) async throws -> [BeaconTrainingProgress]
    func uploadTrainingCertificate(userId: UUID, trainingType: BeaconTrainingType, data: Data, fileName: String, isPDF: Bool) async throws -> BeaconTrainingProgress
    func isUserBeaconVolunteer(userId: UUID) async throws -> Bool
    func getVolunteerStatus(userId: UUID) async throws -> BeaconVolunteer?
    func enrollAsVolunteer(userId: UUID) async throws
    func updateAvailability(userId: UUID, isAvailable: Bool) async throws
    func updateLocation(userId: UUID, lat: Double, lng: Double) async throws
    func updateNotificationRadius(userId: UUID, radiusMiles: Int) async throws
    func findNearbyVolunteers(lat: Double, lng: Double, radiusMiles: Int) async throws -> [NearbyVolunteer]
}
```

**Step 2: Create SupabaseBeaconBackend**

Extract all direct Supabase calls from BeaconService into a private struct:

```swift
private struct SupabaseBeaconBackend: BeaconBackend {
    private let client = SupabaseClient.shared.client

    func syncBadgesToTraining(userId: UUID) async throws {
        try await client.rpc("sync_badges_to_beacon_training", params: ["p_pilot_id": userId.uuidString]).execute()
    }

    func getTrainingProgress(userId: UUID) async throws -> [BeaconTrainingProgress] {
        try await client
            .from("beacon_training_progress")
            .select()
            .eq("pilot_id", value: userId.uuidString)
            .execute()
            .value
    }

    // ... remaining methods follow same pattern, extracting Supabase calls from BeaconService
}
```

**Step 3: Add backend injection to BeaconService**

Change BeaconService init to accept optional backend:

```swift
@MainActor
class BeaconService: ObservableObject {
    @Published var trainingProgress: [BeaconTrainingProgress] = []
    @Published var volunteerStatus: BeaconVolunteer?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let backend: BeaconBackend

    init(backend: BeaconBackend? = nil) {
        self.backend = backend ?? SupabaseBeaconBackend()
    }
```

**Step 4: Refactor all BeaconService methods to use `backend` instead of `supabase`**

Each method replaces its direct Supabase call with the equivalent `backend.methodName(...)`. The service-level logic (loading state, error handling, @Published updates) stays in the service.

**Step 5: Build to verify**

Run: `xcodebuild -scheme Buzz -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build`
Expected: Build succeeds

**Step 6: Commit**

```bash
git add Buzz/Services/BeaconService.swift
git commit -m "refactor: add BeaconBackend protocol for testability"
```

---

## Task 7: Create BeaconTestHelpers.swift

**Files:**
- Create: `BuzzTests/BeaconTestHelpers.swift`

**Step 1: Write MockBeaconBackend and factory methods**

```swift
import XCTest
@testable import Buzz

class MockBeaconBackend: BeaconBackend {
    // Call tracking
    var syncBadgesCalled = false
    var getProgressCalled = false
    var uploadCertCalled = false
    var isVolunteerCalled = false
    var getStatusCalled = false
    var enrollCalled = false
    var updateAvailabilityCalled = false
    var updateLocationCalled = false
    var updateRadiusCalled = false
    var findNearbyCalled = false

    // Error injection
    var shouldThrowOnSync = false
    var shouldThrowOnGetProgress = false
    var shouldThrowOnUpload = false
    var shouldThrowOnIsVolunteer = false
    var shouldThrowOnEnroll = false
    var shouldThrowOnUpdateAvailability = false

    // Configurable returns
    var trainingProgress: [BeaconTrainingProgress] = []
    var isVolunteerResult = false
    var volunteerStatus: BeaconVolunteer? = nil
    var nearbyVolunteers: [NearbyVolunteer] = []
    var uploadResult: BeaconTrainingProgress? = nil

    // Captured parameters
    var lastAvailability: Bool?
    var lastLocation: (lat: Double, lng: Double)?
    var lastRadius: Int?

    func syncBadgesToTraining(userId: UUID) async throws {
        syncBadgesCalled = true
        if shouldThrowOnSync { throw NSError(domain: "Mock", code: -1) }
    }

    func getTrainingProgress(userId: UUID) async throws -> [BeaconTrainingProgress] {
        getProgressCalled = true
        if shouldThrowOnGetProgress { throw NSError(domain: "Mock", code: -1) }
        return trainingProgress
    }

    func uploadTrainingCertificate(userId: UUID, trainingType: BeaconTrainingType, data: Data, fileName: String, isPDF: Bool) async throws -> BeaconTrainingProgress {
        uploadCertCalled = true
        if shouldThrowOnUpload { throw NSError(domain: "Mock", code: -1) }
        return uploadResult ?? BeaconTestHelpers.sampleTrainingProgress(trainingType: trainingType)
    }

    func isUserBeaconVolunteer(userId: UUID) async throws -> Bool {
        isVolunteerCalled = true
        if shouldThrowOnIsVolunteer { throw NSError(domain: "Mock", code: -1) }
        return isVolunteerResult
    }

    func getVolunteerStatus(userId: UUID) async throws -> BeaconVolunteer? {
        getStatusCalled = true
        return volunteerStatus
    }

    func enrollAsVolunteer(userId: UUID) async throws {
        enrollCalled = true
        if shouldThrowOnEnroll { throw NSError(domain: "Mock", code: -1) }
    }

    func updateAvailability(userId: UUID, isAvailable: Bool) async throws {
        updateAvailabilityCalled = true
        lastAvailability = isAvailable
        if shouldThrowOnUpdateAvailability { throw NSError(domain: "Mock", code: -1) }
    }

    func updateLocation(userId: UUID, lat: Double, lng: Double) async throws {
        updateLocationCalled = true
        lastLocation = (lat, lng)
    }

    func updateNotificationRadius(userId: UUID, radiusMiles: Int) async throws {
        updateRadiusCalled = true
        lastRadius = radiusMiles
    }

    func findNearbyVolunteers(lat: Double, lng: Double, radiusMiles: Int) async throws -> [NearbyVolunteer] {
        findNearbyCalled = true
        return nearbyVolunteers
    }
}

enum BeaconTestHelpers {
    static func sampleTrainingProgress(
        trainingType: BeaconTrainingType = .cpr,
        verified: Bool = false
    ) -> BeaconTrainingProgress {
        // Construct with actual struct fields - check BeaconTrainingProgress definition
        BeaconTrainingProgress(
            id: UUID(),
            pilotId: UUID(),
            trainingType: trainingType,
            certificateUrl: "https://example.com/cert.pdf",
            uploadedAt: Date(),
            verified: verified,
            verifiedAt: nil,
            verifiedBy: nil
        )
    }

    static func sampleVolunteer(
        isAvailable: Bool = true,
        notificationRadiusMiles: Int = 25
    ) -> BeaconVolunteer {
        // Construct with actual struct fields - check BeaconVolunteer definition
        BeaconVolunteer(
            id: UUID(),
            pilotId: UUID(),
            enrolledAt: Date(),
            isAvailable: isAvailable,
            lastLocationLat: 42.4396,
            lastLocationLng: -76.4966,
            lastLocationUpdatedAt: Date(),
            notificationRadiusMiles: notificationRadiusMiles,
            missionsCompleted: 0,
            totalHoursVolunteered: 0,
            peopleHelped: 0
        )
    }
}
```

Note: Check the actual `BeaconTrainingProgress`, `BeaconVolunteer`, and `NearbyVolunteer` struct definitions and adapt the factory methods to match their actual fields.

**Step 2: Build to verify**

Run: `xcodebuild -scheme Buzz -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add BuzzTests/BeaconTestHelpers.swift
git commit -m "feat: add MockBeaconBackend and beacon test helpers"
```

---

## Task 8: Write BeaconServiceTests.swift (Unit Tests)

**Files:**
- Create: `BuzzTests/BeaconServiceTests.swift`

**Step 1: Write all unit tests**

~15 tests covering all BeaconService methods:

**Training Tests:**
- `testGetTrainingProgress_callsBackend`: Verify `getProgressCalled`
- `testGetTrainingProgress_updatesPublishedProperty`: Verify `trainingProgress` array updated
- `testSyncBadgesToTraining_callsBackend`: Verify `syncBadgesCalled`
- `testIsAllTrainingCompleted_allDone_returnsTrue`: Mock 3 completed trainings
- `testIsAllTrainingCompleted_missing_returnsFalse`: Mock only 2 trainings
- `testUploadCertificate_callsBackend`: Verify `uploadCertCalled`
- `testUploadCertificate_updatesProgress`: Verify published property updated

**Enrollment Tests:**
- `testEnrollAsVolunteer_callsBackend`: Verify `enrollCalled`
- `testEnrollAsVolunteer_incompleteTraining_throws`: Mock incomplete training, verify `BeaconError.trainingIncomplete`
- `testIsUserBeaconVolunteer_returnsBackendResult`: Verify pass-through

**Volunteer Status Tests:**
- `testGetVolunteerStatus_updatesPublishedProperty`: Verify `volunteerStatus` set
- `testUpdateAvailability_callsBackendWithCorrectValue`: Verify `lastAvailability` matches
- `testUpdateLocation_callsBackendWithCoordinates`: Verify `lastLocation` matches
- `testUpdateNotificationRadius_callsBackend`: Verify `lastRadius` matches
- `testFindNearbyVolunteers_returnsResults`: Verify pass-through of results

Pattern:
```swift
import XCTest
@testable import Buzz

final class BeaconServiceTests: XCTestCase {

    func testGetTrainingProgress_callsBackend() async throws {
        let backend = MockBeaconBackend()
        backend.trainingProgress = [BeaconTestHelpers.sampleTrainingProgress()]
        let service = BeaconService(backend: backend)

        _ = try await service.getTrainingProgress(userId: UUID())

        XCTAssertTrue(backend.getProgressCalled)
    }
}
```

**Step 2: Run tests**

Run: `xcodebuild test -scheme Buzz -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:BuzzTests/BeaconServiceTests`
Expected: All tests pass

**Step 3: Commit**

```bash
git add BuzzTests/BeaconServiceTests.swift
git commit -m "test: add unit tests for BeaconService"
```

---

## Task 9: Write BeaconServiceIntegrationTests.swift (Integration Tests)

**Files:**
- Create: `BuzzTests/BeaconServiceIntegrationTests.swift`

**Step 1: Write integration tests**

Subclass `IntegrationTestCase`. ~8 tests using real Supabase:

```swift
import XCTest
@testable import Buzz

final class BeaconServiceIntegrationTests: IntegrationTestCase {

    private var service: BeaconService!

    override func setUp() async throws {
        try await super.setUp()
        service = BeaconService(backend: nil) // real Supabase
    }
```

**Tests:**
- `testGetTrainingProgress_roundTrip`: Fetch training progress for test user, verify returns array
- `testIsUserBeaconVolunteer_existingVolunteer`: Check test user's volunteer status
- `testGetVolunteerStatus_returnsRecord`: Fetch volunteer record, verify fields populated
- `testUpdateAvailability_toggleRoundTrip`: Set available=false, fetch back, verify, set back to true
- `testUpdateLocation_persistsCoordinates`: Update location, fetch status, verify coordinates
- `testUpdateNotificationRadius_persists`: Update radius, fetch status, verify value
- `testFindNearbyVolunteers_returnsResults`: Query known location, verify response structure
- `testSyncBadgesToTraining_doesNotThrow`: Call sync, verify no error

Note: These tests depend on the test user being enrolled as a beacon volunteer. If not, some tests may need to create/cleanup records. Check the existing data state.

**Step 2: Run tests**

Run: `xcodebuild test -scheme Buzz -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:BuzzTests/BeaconServiceIntegrationTests`
Expected: All tests pass

**Step 3: Commit**

```bash
git add BuzzTests/BeaconServiceIntegrationTests.swift
git commit -m "test: add integration tests for BeaconService"
```

---

## Task 10: Build and Run All Tests

**Step 1: Run full test suite**

Run: `xcodebuild test -scheme Buzz -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'`
Expected: All tests pass including existing tests (no regressions from protocol changes)

**Step 2: Fix any failures**

If existing tests break due to protocol changes (MockBackend not conforming, etc.), fix them.

**Step 3: Final commit**

```bash
git add -A
git commit -m "test: complete beacon mission test framework"
```

---

## Dependency Graph

```
Task 1 (protocol) ──┬── Task 2 (refactor BookingService) ── Task 3 (MockBackend S&R) ── Task 4 (SAR unit tests) ── Task 5 (SAR integration)
                     │
Task 6 (BeaconBackend + refactor) ── Task 7 (BeaconTestHelpers) ── Task 8 (Beacon unit tests) ── Task 9 (Beacon integration)
                     │
                     └── Task 10 (full build + verify)
```

**Track A (BookingService):** Tasks 1 → 2 → 3 → 4 → 5
**Track B (BeaconService):** Tasks 6 → 7 → 8 → 9
**Final:** Task 10 (depends on both tracks)

Track A and Track B can execute in parallel after Task 1 completes (Task 6 is independent of Tasks 1-5).
