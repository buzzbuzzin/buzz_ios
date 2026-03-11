//
//  BeaconServiceTests.swift
//  BuzzTests
//
//  Unit tests for BeaconService using MockBeaconBackend.
//

import XCTest
@testable import Buzz

@MainActor
final class BeaconServiceTests: XCTestCase {

    // MARK: - Training Progress

    func testGetTrainingProgress_callsBackend() async throws {
        let backend = MockBeaconBackend()
        backend.trainingProgress = [BeaconTestHelpers.sampleTrainingProgress()]
        let service = BeaconService(backend: backend)

        _ = try await service.getTrainingProgress(userId: UUID())

        XCTAssertTrue(backend.syncBadgesCalled, "Should sync badges on first call")
        XCTAssertTrue(backend.getProgressCalled)
    }

    func testGetTrainingProgress_updatesPublishedProperty() async throws {
        let backend = MockBeaconBackend()
        let sample = BeaconTestHelpers.sampleTrainingProgress(trainingType: .cpr)
        backend.trainingProgress = [sample]
        let service = BeaconService(backend: backend)

        let result = try await service.getTrainingProgress(userId: UUID())

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(service.trainingProgress.count, 1)
        XCTAssertEqual(service.trainingProgress.first?.trainingType, .cpr)
    }

    func testGetTrainingProgress_syncsBadgesOnlyOnce() async throws {
        let backend = MockBeaconBackend()
        backend.trainingProgress = []
        let service = BeaconService(backend: backend)

        _ = try await service.getTrainingProgress(userId: UUID())
        XCTAssertTrue(backend.syncBadgesCalled)

        // Reset tracking and call again
        backend.syncBadgesCalled = false
        _ = try await service.getTrainingProgress(userId: UUID())
        XCTAssertFalse(backend.syncBadgesCalled, "Should not sync badges on second call")
    }

    func testSyncBadgesToTraining_callsBackend() async throws {
        let backend = MockBeaconBackend()
        let service = BeaconService(backend: backend)

        try await service.syncBadgesToTraining(userId: UUID())

        XCTAssertTrue(backend.syncBadgesCalled)
    }

    func testIsAllTrainingCompleted_allDone_returnsTrue() async throws {
        let backend = MockBeaconBackend()
        backend.trainingProgress = BeaconTestHelpers.allTrainingCompleted()
        let service = BeaconService(backend: backend)

        let result = try await service.isAllTrainingCompleted(userId: UUID())

        XCTAssertTrue(result)
    }

    func testIsAllTrainingCompleted_missing_returnsFalse() async throws {
        let backend = MockBeaconBackend()
        // Only CPR and firefighting - missing cert
        backend.trainingProgress = [
            BeaconTestHelpers.sampleTrainingProgress(trainingType: .cpr),
            BeaconTestHelpers.sampleTrainingProgress(trainingType: .firefighting)
        ]
        let service = BeaconService(backend: backend)

        let result = try await service.isAllTrainingCompleted(userId: UUID())

        XCTAssertFalse(result)
    }

    func testIsTrainingCompleted_specific_returnsTrue() async throws {
        let backend = MockBeaconBackend()
        backend.trainingProgress = [BeaconTestHelpers.sampleTrainingProgress(trainingType: .firefighting)]
        let service = BeaconService(backend: backend)

        let result = try await service.isTrainingCompleted(userId: UUID(), trainingType: .firefighting)

        XCTAssertTrue(result)
    }

    func testIsTrainingCompleted_specific_returnsFalse() async throws {
        let backend = MockBeaconBackend()
        backend.trainingProgress = [BeaconTestHelpers.sampleTrainingProgress(trainingType: .cpr)]
        let service = BeaconService(backend: backend)

        let result = try await service.isTrainingCompleted(userId: UUID(), trainingType: .firefighting)

        XCTAssertFalse(result)
    }

    func testUploadCertificate_callsBackend() async throws {
        let backend = MockBeaconBackend()
        let service = BeaconService(backend: backend)

        _ = try await service.uploadTrainingCertificate(
            userId: UUID(), trainingType: .cpr, data: Data(), fileName: "cert.pdf", isPDF: true, expiresAt: Date().addingTimeInterval(86400)
        )

        XCTAssertTrue(backend.uploadCertCalled)
    }

    func testUploadCertificate_updatesProgress() async throws {
        let backend = MockBeaconBackend()
        let service = BeaconService(backend: backend)

        let result = try await service.uploadTrainingCertificate(
            userId: UUID(), trainingType: .cert, data: Data(), fileName: "cert.pdf", isPDF: true, expiresAt: Date().addingTimeInterval(86400)
        )

        XCTAssertEqual(result.trainingType, .cert)
        XCTAssertEqual(service.trainingProgress.count, 1)
        XCTAssertEqual(service.trainingProgress.first?.trainingType, .cert)
    }

    func testUploadCertificate_error_propagated() async throws {
        let backend = MockBeaconBackend()
        backend.shouldThrowOnUpload = true
        let service = BeaconService(backend: backend)

        do {
            _ = try await service.uploadTrainingCertificate(
                userId: UUID(), trainingType: .cpr, data: Data(), fileName: "cert.pdf", isPDF: true, expiresAt: Date().addingTimeInterval(86400)
            )
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(backend.uploadCertCalled)
        }
    }

    func testUpdateTrainingExpiration_updatesProgress() async throws {
        let backend = MockBeaconBackend()
        let progressId = UUID()
        backend.trainingProgress = [BeaconTestHelpers.sampleTrainingProgress(id: progressId, trainingType: .cpr, expiresAt: nil)]
        let service = BeaconService(backend: backend)
        let futureDate = Date().addingTimeInterval(7 * 86400)

        _ = try await service.getTrainingProgress(userId: UUID())
        let result = try await service.updateTrainingExpiration(
            progressId: progressId,
            expiresAt: futureDate
        )

        XCTAssertTrue(backend.updateExpirationCalled)
        XCTAssertEqual(result.trainingType, .cpr)
        XCTAssertEqual(service.trainingProgress.first?.trainingType, .cpr)
        XCTAssertNotNil(service.trainingProgress.first?.expiresAt)
    }

    // MARK: - Enrollment

    func testEnrollAsVolunteer_callsBackend() async throws {
        let backend = MockBeaconBackend()
        backend.trainingProgress = BeaconTestHelpers.allTrainingCompleted()
        let service = BeaconService(backend: backend)

        try await service.enrollAsVolunteer(userId: UUID())

        XCTAssertTrue(backend.enrollCalled)
    }

    func testEnrollAsVolunteer_incompleteTraining_throws() async throws {
        let backend = MockBeaconBackend()
        // Only 2 of 3 training types
        backend.trainingProgress = [
            BeaconTestHelpers.sampleTrainingProgress(trainingType: .cpr),
            BeaconTestHelpers.sampleTrainingProgress(trainingType: .firefighting)
        ]
        let service = BeaconService(backend: backend)

        do {
            try await service.enrollAsVolunteer(userId: UUID())
            XCTFail("Should have thrown BeaconError.trainingIncomplete")
        } catch let error as BeaconError {
            XCTAssertEqual(error, .trainingIncomplete)
            XCTAssertFalse(backend.enrollCalled, "Should not call enroll when training incomplete")
        }
    }

    func testIsUserBeaconVolunteer_returnsBackendResult() async throws {
        let backend = MockBeaconBackend()
        backend.isVolunteerResult = true
        backend.trainingProgress = BeaconTestHelpers.allTrainingCompleted()
        let service = BeaconService(backend: backend)

        let result = try await service.isUserBeaconVolunteer(userId: UUID())

        XCTAssertTrue(result)
        XCTAssertTrue(backend.isVolunteerCalled)
    }

    func testIsUserBeaconVolunteer_returnsFalse() async throws {
        let backend = MockBeaconBackend()
        backend.isVolunteerResult = false
        let service = BeaconService(backend: backend)

        let result = try await service.isUserBeaconVolunteer(userId: UUID())

        XCTAssertFalse(result)
    }

    func testIsUserBeaconVolunteer_expiredQualification_returnsFalse() async throws {
        let backend = MockBeaconBackend()
        backend.isVolunteerResult = true
        backend.trainingProgress = [
            BeaconTestHelpers.sampleTrainingProgress(trainingType: .cpr, expiresAt: Date().addingTimeInterval(-86400)),
            BeaconTestHelpers.sampleTrainingProgress(trainingType: .firefighting),
            BeaconTestHelpers.sampleTrainingProgress(trainingType: .cert)
        ]
        let service = BeaconService(backend: backend)

        let result = try await service.isUserBeaconVolunteer(userId: UUID())

        XCTAssertFalse(result)
    }

    func testIsAllTrainingCompleted_missingExpiration_returnsFalse() async throws {
        let backend = MockBeaconBackend()
        backend.trainingProgress = [
            BeaconTestHelpers.sampleTrainingProgress(trainingType: .cpr, expiresAt: nil),
            BeaconTestHelpers.sampleTrainingProgress(trainingType: .firefighting),
            BeaconTestHelpers.sampleTrainingProgress(trainingType: .cert)
        ]
        let service = BeaconService(backend: backend)

        let result = try await service.isAllTrainingCompleted(userId: UUID())

        XCTAssertFalse(result)
    }

    func testTrainingProgress_expiringSoon_returnsTrueWithinThirtyDays() {
        let record = BeaconTestHelpers.sampleTrainingProgress(
            trainingType: .cpr,
            expiresAt: Date().addingTimeInterval(10 * 86400)
        )

        XCTAssertTrue(record.isExpiringSoon)
        XCTAssertFalse(record.isExpired)
    }

    func testTrainingProgress_expiringSoon_returnsFalseBeyondThirtyDays() {
        let record = BeaconTestHelpers.sampleTrainingProgress(
            trainingType: .cpr,
            expiresAt: Date().addingTimeInterval(45 * 86400)
        )

        XCTAssertFalse(record.isExpiringSoon)
        XCTAssertTrue(record.isCurrent)
    }

    // MARK: - Volunteer Status

    func testGetVolunteerStatus_updatesPublishedProperty() async throws {
        let backend = MockBeaconBackend()
        backend.volunteerStatus = BeaconTestHelpers.sampleVolunteer(isAvailable: true)
        let service = BeaconService(backend: backend)

        let result = try await service.getVolunteerStatus(userId: UUID())

        XCTAssertNotNil(result)
        XCTAssertNotNil(service.volunteerStatus)
        XCTAssertTrue(service.volunteerStatus!.isAvailable)
    }

    func testGetVolunteerStatus_nilWhenNotFound() async throws {
        let backend = MockBeaconBackend()
        backend.volunteerStatus = nil
        let service = BeaconService(backend: backend)

        let result = try await service.getVolunteerStatus(userId: UUID())

        XCTAssertNil(result)
        XCTAssertNil(service.volunteerStatus)
    }

    func testUpdateAvailability_callsBackendWithCorrectValue() async throws {
        let backend = MockBeaconBackend()
        let service = BeaconService(backend: backend)

        try await service.updateAvailability(userId: UUID(), isAvailable: false)

        XCTAssertTrue(backend.updateAvailabilityCalled)
        XCTAssertEqual(backend.lastAvailability, false)
    }

    func testUpdateLocation_callsBackendWithCoordinates() async throws {
        let backend = MockBeaconBackend()
        let service = BeaconService(backend: backend)

        try await service.updateLocation(userId: UUID(), lat: 42.0, lng: -76.0)

        XCTAssertTrue(backend.updateLocationCalled)
        XCTAssertEqual(backend.lastLocation?.lat, 42.0)
        XCTAssertEqual(backend.lastLocation?.lng, -76.0)
    }

    func testUpdateNotificationRadius_callsBackend() async throws {
        let backend = MockBeaconBackend()
        let service = BeaconService(backend: backend)

        try await service.updateNotificationRadius(userId: UUID(), radiusMiles: 50)

        XCTAssertTrue(backend.updateRadiusCalled)
        XCTAssertEqual(backend.lastRadius, 50)
    }

    func testFindNearbyVolunteers_returnsResults() async throws {
        let backend = MockBeaconBackend()
        backend.nearbyVolunteers = [
            BeaconTestHelpers.sampleNearbyVolunteer(distanceMiles: 3.0),
            BeaconTestHelpers.sampleNearbyVolunteer(distanceMiles: 10.0)
        ]
        let service = BeaconService(backend: backend)

        let result = try await service.findNearbyVolunteers(lat: 42.0, lng: -76.0, radiusMiles: 25)

        XCTAssertTrue(backend.findNearbyCalled)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.distanceMiles, 3.0)
    }
}
