//
//  BeaconTestHelpers.swift
//  BuzzTests
//
//  Mock backend and factory helpers for BeaconService tests.
//

import XCTest
@testable import Buzz

// MARK: - Mock Beacon Backend

final class MockBeaconBackend: BeaconBackend {
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
    var shouldThrowOnUpdateExpiration = false
    var shouldThrowOnIsVolunteer = false
    var shouldThrowOnEnroll = false
    var shouldThrowOnUpdateAvailability = false
    var shouldThrowOnUpdateLocation = false
    var shouldThrowOnUpdateRadius = false
    var shouldThrowOnFindNearby = false

    // Configurable returns
    var trainingProgress: [BeaconTrainingProgress] = []
    var isVolunteerResult = false
    var volunteerStatus: BeaconVolunteer? = nil
    var nearbyVolunteers: [NearbyVolunteer] = []
    var uploadResult: BeaconTrainingProgress? = nil
    var updateExpirationCalled = false
    var lastExpirationUpdate: (trainingType: BeaconTrainingType, expiresAt: Date)?

    // Captured parameters
    var lastAvailability: Bool?
    var lastLocation: (lat: Double, lng: Double)?
    var lastRadius: Int?

    func syncBadgesToTraining(userId: UUID) async throws {
        syncBadgesCalled = true
        if shouldThrowOnSync {
            throw NSError(domain: "MockBeaconBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock sync error"])
        }
    }

    func getTrainingProgress(userId: UUID) async throws -> [BeaconTrainingProgress] {
        getProgressCalled = true
        if shouldThrowOnGetProgress {
            throw NSError(domain: "MockBeaconBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock get progress error"])
        }
        return trainingProgress
    }

    func uploadTrainingCertificate(userId: UUID, trainingType: BeaconTrainingType, data: Data, fileName: String, isPDF: Bool, expiresAt: Date) async throws -> BeaconTrainingProgress {
        uploadCertCalled = true
        if shouldThrowOnUpload {
            throw NSError(domain: "MockBeaconBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock upload error"])
        }
        return uploadResult ?? BeaconTestHelpers.sampleTrainingProgress(trainingType: trainingType, expiresAt: expiresAt)
    }

    func updateTrainingExpiration(userId: UUID, trainingType: BeaconTrainingType, expiresAt: Date) async throws -> BeaconTrainingProgress {
        updateExpirationCalled = true
        lastExpirationUpdate = (trainingType, expiresAt)
        if shouldThrowOnUpdateExpiration {
            throw NSError(domain: "MockBeaconBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock update expiration error"])
        }
        return BeaconTestHelpers.sampleTrainingProgress(trainingType: trainingType, expiresAt: expiresAt)
    }

    func isUserBeaconVolunteer(userId: UUID) async throws -> Bool {
        isVolunteerCalled = true
        if shouldThrowOnIsVolunteer {
            throw NSError(domain: "MockBeaconBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock is volunteer error"])
        }
        return isVolunteerResult
    }

    func getVolunteerStatus(userId: UUID) async throws -> BeaconVolunteer? {
        getStatusCalled = true
        return volunteerStatus
    }

    func enrollAsVolunteer(userId: UUID) async throws {
        enrollCalled = true
        if shouldThrowOnEnroll {
            throw NSError(domain: "MockBeaconBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock enroll error"])
        }
    }

    func updateAvailability(userId: UUID, isAvailable: Bool) async throws {
        updateAvailabilityCalled = true
        lastAvailability = isAvailable
        if shouldThrowOnUpdateAvailability {
            throw NSError(domain: "MockBeaconBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock update availability error"])
        }
    }

    func updateLocation(userId: UUID, lat: Double, lng: Double) async throws {
        updateLocationCalled = true
        lastLocation = (lat, lng)
        if shouldThrowOnUpdateLocation {
            throw NSError(domain: "MockBeaconBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock update location error"])
        }
    }

    func updateNotificationRadius(userId: UUID, radiusMiles: Int) async throws {
        updateRadiusCalled = true
        lastRadius = radiusMiles
        if shouldThrowOnUpdateRadius {
            throw NSError(domain: "MockBeaconBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock update radius error"])
        }
    }

    func findNearbyVolunteers(lat: Double, lng: Double, radiusMiles: Int) async throws -> [NearbyVolunteer] {
        findNearbyCalled = true
        if shouldThrowOnFindNearby {
            throw NSError(domain: "MockBeaconBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock find nearby error"])
        }
        return nearbyVolunteers
    }
}

// MARK: - Sample Data Factories

enum BeaconTestHelpers {
    static func sampleTrainingProgress(
        id: UUID = UUID(),
        pilotId: UUID = UUID(),
        trainingType: BeaconTrainingType = .cpr,
        certificateUrl: String = "https://example.com/cert.pdf",
        uploadedAt: Date = Date(),
        expiresAt: Date? = Calendar.current.date(byAdding: .day, value: 30, to: Date()),
        verified: Bool = false,
        verifiedAt: Date? = nil,
        verifiedBy: UUID? = nil
    ) -> BeaconTrainingProgress {
        BeaconTrainingProgress(
            id: id,
            pilotId: pilotId,
            trainingType: trainingType,
            certificateUrl: certificateUrl,
            uploadedAt: uploadedAt,
            expiresAt: expiresAt,
            verified: verified,
            verifiedAt: verifiedAt,
            verifiedBy: verifiedBy
        )
    }

    static func sampleVolunteer(
        id: UUID = UUID(),
        pilotId: UUID = UUID(),
        enrolledAt: Date = Date(),
        isAvailable: Bool = true,
        lastLocationLat: Double? = 42.4396,
        lastLocationLng: Double? = -76.4966,
        lastLocationUpdate: Date? = Date(),
        notificationRadiusMiles: Int = 25,
        totalMissionsCompleted: Int = 0,
        totalHoursVolunteered: Double = 0,
        peopleHelped: Int = 0
    ) -> BeaconVolunteer {
        BeaconVolunteer(
            id: id,
            pilotId: pilotId,
            enrolledAt: enrolledAt,
            isAvailable: isAvailable,
            lastLocationLat: lastLocationLat,
            lastLocationLng: lastLocationLng,
            lastLocationUpdate: lastLocationUpdate,
            notificationRadiusMiles: notificationRadiusMiles,
            totalMissionsCompleted: totalMissionsCompleted,
            totalHoursVolunteered: totalHoursVolunteered,
            peopleHelped: peopleHelped
        )
    }

    static func sampleNearbyVolunteer(
        volunteerId: UUID = UUID(),
        pilotId: UUID = UUID(),
        distanceMiles: Double = 5.0,
        notificationRadiusMiles: Int = 25
    ) -> NearbyVolunteer {
        NearbyVolunteer(
            volunteerId: volunteerId,
            pilotId: pilotId,
            distanceMiles: distanceMiles,
            notificationRadiusMiles: notificationRadiusMiles
        )
    }

    /// Returns a full set of training progress (all 3 types) for testing "all completed" scenarios.
    static func allTrainingCompleted(pilotId: UUID = UUID()) -> [BeaconTrainingProgress] {
        BeaconTrainingType.allCases.map { type in
            sampleTrainingProgress(pilotId: pilotId, trainingType: type, verified: true)
        }
    }
}
