//
//  HangerSpaceTestHelpers.swift
//  BuzzTests
//
//  Sample data factories and utilities for Hanger Space tests.
//

import XCTest
import Foundation
@testable import Buzz

// MARK: - Hanger Space Sample Data Factories

enum HangerSpaceTestData {

    // MARK: - Space

    static func sampleSpace(
        id: UUID = UUID(),
        hostId: UUID = UUID(),
        title: String = "Test Space",
        description: String? = "A test audio space",
        status: HangerSpaceStatus = .live,
        livekitRoomName: String = "room-test-123",
        startedAt: Date? = Date(),
        endedAt: Date? = nil,
        scheduledAt: Date? = nil,
        listenerCount: Int = 0,
        speakerCount: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> HangerSpace {
        HangerSpace(
            id: id,
            hostId: hostId,
            title: title,
            description: description,
            status: status,
            livekitRoomName: livekitRoomName,
            startedAt: startedAt,
            endedAt: endedAt,
            scheduledAt: scheduledAt,
            listenerCount: listenerCount,
            speakerCount: speakerCount,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Space Insert

    static func sampleSpaceInsert(
        hostId: UUID = UUID(),
        title: String = "New Space",
        description: String? = "A new audio space",
        status: HangerSpaceStatus = .live,
        livekitRoomName: String = "room-new-456",
        startedAt: Date? = Date()
    ) -> HangerSpaceInsert {
        HangerSpaceInsert(
            hostId: hostId,
            title: title,
            description: description,
            status: status,
            livekitRoomName: livekitRoomName,
            startedAt: startedAt
        )
    }

    // MARK: - Space With Host

    static func sampleSpaceWithHost(
        id: UUID = UUID(),
        space: HangerSpace? = nil,
        hostCallSign: String? = "TestPilot",
        hostProfilePictureUrl: String? = nil,
        hostFullName: String = "Test Pilot"
    ) -> HangerSpaceWithHost {
        let actualSpace = space ?? sampleSpace(id: id)
        return HangerSpaceWithHost(
            id: id,
            space: actualSpace,
            hostCallSign: hostCallSign,
            hostProfilePictureUrl: hostProfilePictureUrl,
            hostFullName: hostFullName
        )
    }

    // MARK: - Participant

    static func sampleParticipant(
        id: UUID = UUID(),
        spaceId: UUID = UUID(),
        userId: UUID = UUID(),
        role: HangerSpaceRole = .listener,
        joinedAt: Date = Date(),
        leftAt: Date? = nil
    ) -> HangerSpaceParticipant {
        HangerSpaceParticipant(
            id: id,
            spaceId: spaceId,
            userId: userId,
            role: role,
            joinedAt: joinedAt,
            leftAt: leftAt
        )
    }

    // MARK: - Participant With Profile

    static func sampleParticipantWithProfile(
        id: UUID = UUID(),
        userId: UUID = UUID(),
        role: HangerSpaceRole = .listener,
        callSign: String? = "TestPilot",
        profilePictureUrl: String? = nil,
        fullName: String = "Test Pilot",
        isMuted: Bool = false,
        isSpeaking: Bool = false
    ) -> HangerSpaceParticipantWithProfile {
        HangerSpaceParticipantWithProfile(
            id: id,
            userId: userId,
            role: role,
            callSign: callSign,
            profilePictureUrl: profilePictureUrl,
            fullName: fullName,
            isMuted: isMuted,
            isSpeaking: isSpeaking
        )
    }

    // MARK: - Speaker Request

    static func sampleSpeakerRequest(
        id: UUID = UUID(),
        spaceId: UUID = UUID(),
        userId: UUID = UUID(),
        status: String = "pending",
        createdAt: Date = Date()
    ) -> HangerSpaceSpeakerRequest {
        HangerSpaceSpeakerRequest(
            id: id,
            spaceId: spaceId,
            userId: userId,
            status: status,
            createdAt: createdAt
        )
    }

    // MARK: - LiveKit Token Response

    static func sampleLiveKitTokenResponse(
        token: String = "test-token-abc123",
        wsUrl: String = "wss://test.livekit.cloud"
    ) -> LiveKitTokenResponse {
        LiveKitTokenResponse(
            token: token,
            wsUrl: wsUrl
        )
    }
}
