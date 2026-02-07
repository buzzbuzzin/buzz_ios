//
//  TestHelpers.swift
//  BuzzTests
//
//  Shared mock infrastructure and test utilities for BookingService tests.
//

import XCTest
import CoreLocation
import Supabase
@testable import Buzz

// MARK: - Mock Backend

final class MockBackend: BookingBackend {
    var capturedPayload: [String: AnyJSON] = [:]
    var createBookingResult: Booking
    var fetchBookingResult: Booking
    var userProfileResult: UserProfile
    var updateCalled = false
    var joinCalled = false
    var lastUpdatedValues: [String: AnyJSON]?
    var joinResponse: JoinCrewResponse
    var shouldThrowOnCreate = false
    var shouldThrowOnUpdate = false
    var shouldThrowOnFetch = false

    init(
        createBookingResult: Booking? = nil,
        fetchBookingResult: Booking? = nil,
        userProfileResult: UserProfile = MockBackend.sampleProfile(),
        joinResponse: JoinCrewResponse = JoinCrewResponse(success: true, message: nil, crewMember: nil, crewStatus: nil, error: nil)
    ) {
        let defaultBooking = MockBackend.sampleBooking()
        self.createBookingResult = createBookingResult ?? defaultBooking
        self.fetchBookingResult = fetchBookingResult ?? defaultBooking
        self.userProfileResult = userProfileResult
        self.joinResponse = joinResponse
    }

    func createBooking(payload: [String: AnyJSON], bookingId: UUID) async throws -> Booking {
        if shouldThrowOnCreate {
            throw NSError(domain: "MockBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock create error"])
        }
        capturedPayload = payload
        return createBookingResult
    }

    func fetchBooking(id: UUID) async throws -> Booking {
        if shouldThrowOnFetch {
            throw NSError(domain: "MockBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock fetch error"])
        }
        return fetchBookingResult
    }

    func updateBooking(id: UUID, values: [String: AnyJSON]) async throws {
        if shouldThrowOnUpdate {
            throw NSError(domain: "MockBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock update error"])
        }
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

    // MARK: - Sample Data Factories

    static func sampleProfile(id: UUID = UUID()) -> UserProfile {
        UserProfile(
            id: id,
            userType: .pilot,
            firstName: "Test",
            lastName: "Pilot",
            callSign: "TestCall",
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
            veteranServiceNumber: nil,
            lastLocationLat: nil,
            lastLocationLng: nil,
            lastLocationUpdate: nil,
            referralCredits: nil,
            referredBy: nil,
            isBeaconVolunteer: nil,
            selectedRegion: nil,
            isVerified: nil
        )
    }

    static func sampleBooking(
        id: UUID = UUID(),
        customerId: UUID = UUID(),
        pilotId: UUID? = nil,
        specialization: BookingSpecialization? = .realEstate,
        status: BookingStatus = .available,
        paymentAmount: Decimal = 100,
        estimatedFlightHours: Double = 2.0,
        scheduledDate: Date? = nil,
        endDate: Date? = nil,
        requiredMinimumRank: Int = 0
    ) -> Booking {
        Booking(
            id: id,
            customerId: customerId,
            pilotId: pilotId,
            locationLat: 37.7749,
            locationLng: -122.4194,
            locationName: "Test Location",
            scheduledDate: scheduledDate,
            endDate: endDate,
            specialization: specialization,
            description: "Test description",
            paymentAmount: paymentAmount,
            tipAmount: nil,
            status: status,
            createdAt: Date(),
            estimatedFlightHours: estimatedFlightHours,
            pilotRated: nil,
            customerRated: nil,
            requiredMinimumRank: requiredMinimumRank
        )
    }
}

// MARK: - Mock Notification Manager

final class MockNotificationManager: BookingNotificationManaging {
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

// MARK: - Mock Notification Preferences

final class MockNotificationPreferences: NotificationPreferencesProviding {
    var preferences: NotificationPreferences = {
        var prefs = NotificationPreferences()
        prefs.bookingReminders = NotificationDeliveryOptions(system: true)
        return prefs
    }()

    var loadCalled = false

    func loadPreferences(userId: UUID) async throws {
        loadCalled = true
    }
}

// MARK: - AnyJSON Helpers

extension AnyJSON {
    var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        if case let .double(value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case let .integer(value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }
}
