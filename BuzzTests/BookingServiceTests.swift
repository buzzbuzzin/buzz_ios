//
//  BookingServiceTests.swift
//  BuzzTests
//
//  Created for validating booking creation and acceptance flows.
//

import XCTest
@testable import Buzz

final class BookingServiceTests: XCTestCase {
    func testCreateBookingBuildsPayloadAndReturnsBooking() async throws {
        let customerId = UUID()
        let bookingId = UUID()
        let created = Booking(
            id: bookingId,
            customerId: customerId,
            pilotId: nil,
            locationLat: 1.0,
            locationLng: 2.0,
            locationName: "Test",
            scheduledDate: nil,
            endDate: nil,
            specialization: .realEstate,
            description: "desc",
            paymentAmount: 10,
            tipAmount: nil,
            status: .available,
            createdAt: Date(),
            estimatedFlightHours: 1.5,
            pilotRated: nil,
            customerRated: nil,
            requiredMinimumRank: 0
        )
        
        let backend = MockBackend(createBookingResult: created, fetchBookingResult: created)
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )
        
        let result = try await service.createBooking(
            customerId: customerId,
            location: .init(latitude: 1, longitude: 2),
            locationName: "Test",
            scheduledDate: nil,
            specialization: .realEstate,
            description: "desc",
            paymentAmount: 10,
            estimatedFlightHours: 1.5
        )
        
        XCTAssertEqual(result.id, created.id)
        XCTAssertEqual(backend.capturedPayload["status"]?.stringValue, BookingStatus.available.rawValue)
        XCTAssertEqual(backend.capturedPayload["customer_id"]?.stringValue, customerId.uuidString)
    }
    
    func testAcceptBookingUpdatesNonAutomotive() async throws {
        let bookingId = UUID()
        let pilotId = UUID()
        let booking = Booking(
            id: bookingId,
            customerId: UUID(),
            pilotId: nil,
            locationLat: 0,
            locationLng: 0,
            locationName: "Loc",
            scheduledDate: Date(),
            endDate: nil,
            specialization: .realEstate,
            description: nil,
            paymentAmount: 20,
            tipAmount: nil,
            status: .available,
            createdAt: Date(),
            estimatedFlightHours: 2,
            pilotRated: nil,
            customerRated: nil,
            requiredMinimumRank: 0
        )
        
        let backend = MockBackend(
            createBookingResult: booking,
            fetchBookingResult: booking,
            userProfileResult: MockBackend.sampleProfile(id: pilotId)
        )
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )
        
        try await service.acceptBooking(bookingId: bookingId, pilotId: pilotId)
        
        XCTAssertTrue(backend.updateCalled)
        XCTAssertFalse(backend.joinCalled)
        XCTAssertEqual(backend.lastUpdatedValues?["pilot_id"]?.stringValue, pilotId.uuidString)
    }
    
    func testAcceptBookingUsesCrewJoinForAutomotive() async throws {
        let bookingId = UUID()
        let pilotId = UUID()
        let booking = Booking(
            id: bookingId,
            customerId: UUID(),
            pilotId: nil,
            locationLat: 0,
            locationLng: 0,
            locationName: "Auto",
            scheduledDate: nil,
            endDate: nil,
            specialization: .automotive,
            description: nil,
            paymentAmount: 20,
            tipAmount: nil,
            status: .available,
            createdAt: Date(),
            estimatedFlightHours: 2,
            pilotRated: nil,
            customerRated: nil,
            requiredMinimumRank: 1
        )
        
        let backend = MockBackend(
            createBookingResult: booking,
            fetchBookingResult: booking,
            joinResponse: JoinCrewResponse(success: true, message: nil, crewMember: nil, crewStatus: nil, error: nil)
        )
        let service = BookingService(
            backend: backend,
            notificationManager: MockNotificationManager(),
            notificationPreferencesService: MockNotificationPreferences(),
            skipNetworkCalls: true
        )
        
        try await service.acceptBooking(bookingId: bookingId, pilotId: pilotId)
        
        XCTAssertTrue(backend.joinCalled)
        XCTAssertFalse(backend.updateCalled)
    }
}

// MARK: - Mocks

private final class MockBackend: BookingBackend {
    var capturedPayload: [String: AnyJSON] = [:]
    var createBookingResult: Booking
    var fetchBookingResult: Booking
    var userProfileResult: UserProfile
    var updateCalled = false
    var joinCalled = false
    var lastUpdatedValues: [String: AnyJSON]?
    var joinResponse: JoinCrewResponse
    
    init(
        createBookingResult: Booking,
        fetchBookingResult: Booking,
        userProfileResult: UserProfile = MockBackend.sampleProfile(),
        joinResponse: JoinCrewResponse = JoinCrewResponse(success: true, message: nil, crewMember: nil, crewStatus: nil, error: nil)
    ) {
        self.createBookingResult = createBookingResult
        self.fetchBookingResult = fetchBookingResult
        self.userProfileResult = userProfileResult
        self.joinResponse = joinResponse
    }
    
    func createBooking(payload: [String : AnyJSON], bookingId: UUID) async throws -> Booking {
        capturedPayload = payload
        return createBookingResult
    }
    
    func fetchBooking(id: UUID) async throws -> Booking {
        fetchBookingResult
    }
    
    func updateBooking(id: UUID, values: [String : AnyJSON]) async throws {
        updateCalled = true
        lastUpdatedValues = values
    }
    
    func joinAutomotiveBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse {
        joinCalled = true
        return joinResponse
    }
    
    func fetchUserProfile(userId: UUID) async throws -> UserProfile {
        userProfileResult
    }
    
    static func sampleProfile(id: UUID = UUID()) -> UserProfile {
        UserProfile(
            id: id,
            userType: .pilot,
            firstName: "Test",
            lastName: "Pilot",
            callSign: "call",
            email: "test@example.com",
            phone: nil,
            gender: nil,
            profilePictureUrl: nil,
            communicationPreference: nil,
            role: nil,
            specialization: nil,
            createdAt: Date(),
            balance: nil,
            stripeAccountId: nil,
            isExMilitary: nil,
            isGovernmentEmployee: nil,
            hasFaaCertification: nil,
            isBuzzAffiliate: nil,
            veteranServiceName: nil,
            veteranServiceCountry: nil,
            veteranMilitaryBranch: nil,
            veteranServiceNumber: nil
        )
    }
}

private final class MockNotificationManager: BookingNotificationManaging {
    var acceptedCalls: Int = 0
    var reminderCalls: Int = 0
    var nearbyCalls: Int = 0
    var completionCalls: Int = 0
    
    func notifyBookingAccepted(bookingId: UUID, pilotName: String, aircraftType: String, departureTime: Date) async {
        acceptedCalls += 1
    }
    
    func scheduleBookingReminder(bookingId: UUID, aircraftType: String, departureTime: Date, pilotName: String) async {
        reminderCalls += 1
    }
    
    func notifyNearbyBooking(bookingId: UUID, aircraftType: String, distance: Double, departureTime: Date) async {
        nearbyCalls += 1
    }
    
    func notifyCrewBookingCompleted(bookingId: UUID, payoutAmount: Decimal, role: String) async {
        completionCalls += 1
    }
}

private final class MockNotificationPreferences: NotificationPreferencesProviding {
    var preferences: NotificationPreferences = {
        var prefs = NotificationPreferences()
        prefs.bookingReminders = NotificationDeliveryOptions(system: true)
        return prefs
    }()
    
    func loadPreferences(userId: UUID) async throws { }
}

private extension AnyJSON {
    var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }
}

