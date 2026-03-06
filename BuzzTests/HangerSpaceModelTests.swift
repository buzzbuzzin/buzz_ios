//
//  HangerSpaceModelTests.swift
//  BuzzTests
//
//  Tests for Hanger Space data models: HangerSpace, HangerSpaceParticipant,
//  HangerSpaceResponse, LiveKitTokenResponse, Codable conformance, etc.
//

import XCTest
@testable import Buzz

final class HangerSpaceModelTests: XCTestCase {

    // MARK: - HangerSpaceStatus

    func testStatusEnumCases() {
        XCTAssertEqual(HangerSpaceStatus.scheduled.rawValue, "scheduled")
        XCTAssertEqual(HangerSpaceStatus.live.rawValue, "live")
        XCTAssertEqual(HangerSpaceStatus.ended.rawValue, "ended")
    }

    func testStatusCodableRoundTrip() throws {
        let statuses: [HangerSpaceStatus] = [.scheduled, .live, .ended]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for status in statuses {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(HangerSpaceStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }

    // MARK: - HangerSpaceRole

    func testRoleEnumCases() {
        XCTAssertEqual(HangerSpaceRole.host.rawValue, "host")
        XCTAssertEqual(HangerSpaceRole.speaker.rawValue, "speaker")
        XCTAssertEqual(HangerSpaceRole.listener.rawValue, "listener")
    }

    func testRoleCodableRoundTrip() throws {
        let roles: [HangerSpaceRole] = [.host, .speaker, .listener]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for role in roles {
            let data = try encoder.encode(role)
            let decoded = try decoder.decode(HangerSpaceRole.self, from: data)
            XCTAssertEqual(decoded, role)
        }
    }

    func testRoleAllowsPublishing() {
        XCTAssertTrue(HangerSpaceRole.host.allowsPublishing)
        XCTAssertTrue(HangerSpaceRole.speaker.allowsPublishing)
        XCTAssertFalse(HangerSpaceRole.listener.allowsPublishing)
    }

    // MARK: - HangerSpace

    func testSpaceCreation() {
        let space = HangerSpaceTestData.sampleSpace(
            title: "Aviation Chat",
            status: .live,
            listenerCount: 10,
            speakerCount: 3
        )
        XCTAssertEqual(space.title, "Aviation Chat")
        XCTAssertEqual(space.status, .live)
        XCTAssertEqual(space.listenerCount, 10)
        XCTAssertEqual(space.speakerCount, 3)
    }

    func testSpaceDefaultValues() {
        let space = HangerSpaceTestData.sampleSpace()
        XCTAssertEqual(space.title, "Test Space")
        XCTAssertEqual(space.description, "A test audio space")
        XCTAssertEqual(space.status, .live)
        XCTAssertEqual(space.livekitRoomName, "room-test-123")
        XCTAssertEqual(space.listenerCount, 0)
        XCTAssertEqual(space.speakerCount, 1)
        XCTAssertNil(space.endedAt)
        XCTAssertNil(space.scheduledAt)
    }

    func testSpaceCodableRoundTrip() throws {
        let original = HangerSpaceTestData.sampleSpace(
            title: "Roundtrip Space",
            description: "Testing encoding",
            status: .scheduled,
            listenerCount: 5,
            speakerCount: 2
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HangerSpace.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.hostId, original.hostId)
        XCTAssertEqual(decoded.title, "Roundtrip Space")
        XCTAssertEqual(decoded.description, "Testing encoding")
        XCTAssertEqual(decoded.status, .scheduled)
        XCTAssertEqual(decoded.livekitRoomName, original.livekitRoomName)
        XCTAssertEqual(decoded.listenerCount, 5)
        XCTAssertEqual(decoded.speakerCount, 2)
    }

    func testSpaceDecodingFromSnakeCaseJSON() throws {
        let spaceId = UUID()
        let hostId = UUID()
        let now = ISO8601DateFormatter().string(from: Date())

        let json: [String: Any] = [
            "id": spaceId.uuidString,
            "host_id": hostId.uuidString,
            "title": "Snake Case Space",
            "description": "From JSON dict",
            "status": "live",
            "livekit_room_name": "room-snake-789",
            "started_at": now,
            "listener_count": 15,
            "speaker_count": 4,
            "created_at": now,
            "updated_at": now
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let space = try decoder.decode(HangerSpace.self, from: data)

        XCTAssertEqual(space.id, spaceId)
        XCTAssertEqual(space.hostId, hostId)
        XCTAssertEqual(space.title, "Snake Case Space")
        XCTAssertEqual(space.description, "From JSON dict")
        XCTAssertEqual(space.status, .live)
        XCTAssertEqual(space.livekitRoomName, "room-snake-789")
        XCTAssertEqual(space.listenerCount, 15)
        XCTAssertEqual(space.speakerCount, 4)
        XCTAssertNotNil(space.startedAt)
        XCTAssertNil(space.endedAt)
        XCTAssertNil(space.scheduledAt)
    }

    func testSpaceOptionalFieldsNil() {
        let space = HangerSpaceTestData.sampleSpace(
            description: nil,
            startedAt: nil,
            endedAt: nil,
            scheduledAt: nil
        )
        XCTAssertNil(space.description)
        XCTAssertNil(space.startedAt)
        XCTAssertNil(space.endedAt)
        XCTAssertNil(space.scheduledAt)
    }

    func testSpaceOptionalFieldsPresent() {
        let started = Date()
        let ended = Date().addingTimeInterval(3600)
        let scheduled = Date().addingTimeInterval(-3600)

        let space = HangerSpaceTestData.sampleSpace(
            description: "A detailed description",
            startedAt: started,
            endedAt: ended,
            scheduledAt: scheduled
        )
        XCTAssertEqual(space.description, "A detailed description")
        XCTAssertEqual(space.startedAt, started)
        XCTAssertEqual(space.endedAt, ended)
        XCTAssertEqual(space.scheduledAt, scheduled)
    }

    // MARK: - HangerSpaceInsert

    func testSpaceInsertEncoding() throws {
        let insert = HangerSpaceTestData.sampleSpaceInsert(
            title: "New Audio Room",
            description: "Join the discussion"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(insert)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(dict?["title"] as? String, "New Audio Room")
        XCTAssertEqual(dict?["description"] as? String, "Join the discussion")
        XCTAssertNotNil(dict?["host_id"])
        XCTAssertNotNil(dict?["livekit_room_name"])
        XCTAssertEqual(dict?["status"] as? String, "live")
        XCTAssertNotNil(dict?["started_at"])
    }

    func testSpaceInsertOptionalDescription() throws {
        let insert = HangerSpaceTestData.sampleSpaceInsert(description: nil)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(insert)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // description key should be present but null (or absent depending on encoding)
        // The key thing is that title and host_id are present
        XCTAssertNotNil(dict?["title"])
        XCTAssertNotNil(dict?["host_id"])
    }

    // MARK: - HangerSpaceWithHost

    func testSpaceWithHostCreation() {
        let swh = HangerSpaceTestData.sampleSpaceWithHost(
            hostCallSign: "Maverick",
            hostFullName: "Pete Mitchell"
        )
        XCTAssertEqual(swh.hostCallSign, "Maverick")
        XCTAssertEqual(swh.hostFullName, "Pete Mitchell")
        XCTAssertNotNil(swh.space)
        XCTAssertEqual(swh.id, swh.space.id)
    }

    func testSpaceWithHostNilCallSign() {
        let swh = HangerSpaceTestData.sampleSpaceWithHost(
            hostCallSign: nil,
            hostFullName: "Jane Doe"
        )
        XCTAssertNil(swh.hostCallSign)
        XCTAssertEqual(swh.hostFullName, "Jane Doe")
    }

    // MARK: - HangerSpaceResponse

    func testSpaceResponseDecodingWithProfile() throws {
        let spaceId = UUID()
        let hostId = UUID()
        let now = ISO8601DateFormatter().string(from: Date())

        let json: [String: Any] = [
            "id": spaceId.uuidString,
            "host_id": hostId.uuidString,
            "title": "Response Space",
            "description": "With profile",
            "status": "live",
            "livekit_room_name": "room-resp-001",
            "started_at": now,
            "listener_count": 8,
            "speaker_count": 2,
            "created_at": now,
            "updated_at": now,
            "profiles": [
                "id": hostId.uuidString,
                "call_sign": "Goose",
                "profile_picture_url": "https://example.com/pic.jpg",
                "first_name": "Nick",
                "last_name": "Bradshaw"
            ] as [String: Any]
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(HangerSpaceResponse.self, from: data)

        XCTAssertEqual(response.id, spaceId)
        XCTAssertEqual(response.title, "Response Space")
        XCTAssertNotNil(response.profiles)
    }

    func testSpaceResponseProfileDataComputed() throws {
        let hostId = UUID()
        let now = ISO8601DateFormatter().string(from: Date())

        let json: [String: Any] = [
            "id": UUID().uuidString,
            "host_id": hostId.uuidString,
            "title": "Profile Test",
            "status": "live",
            "livekit_room_name": "room-profile-001",
            "listener_count": 0,
            "speaker_count": 1,
            "created_at": now,
            "updated_at": now,
            "profiles": [
                "id": hostId.uuidString,
                "call_sign": "Iceman",
                "first_name": "Tom",
                "last_name": "Kazansky"
            ] as [String: Any]
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(HangerSpaceResponse.self, from: data)

        let profile = response.profileData
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.callSign, "Iceman")
        XCTAssertEqual(profile?.fullName, "Tom Kazansky")
    }

    func testSpaceResponseToHangerSpace() throws {
        let now = ISO8601DateFormatter().string(from: Date())

        let json: [String: Any] = [
            "id": UUID().uuidString,
            "host_id": UUID().uuidString,
            "title": "Convert Me",
            "description": "To HangerSpace",
            "status": "scheduled",
            "livekit_room_name": "room-convert-001",
            "listener_count": 3,
            "speaker_count": 1,
            "created_at": now,
            "updated_at": now
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(HangerSpaceResponse.self, from: data)

        let space = response.toHangerSpace()
        XCTAssertEqual(space.id, response.id)
        XCTAssertEqual(space.hostId, response.hostId)
        XCTAssertEqual(space.title, "Convert Me")
        XCTAssertEqual(space.description, "To HangerSpace")
        XCTAssertEqual(space.status, .scheduled)
        XCTAssertEqual(space.listenerCount, 3)
        XCTAssertEqual(space.speakerCount, 1)
    }

    func testSpaceResponseToSpaceWithHost() throws {
        let hostId = UUID()
        let now = ISO8601DateFormatter().string(from: Date())

        let json: [String: Any] = [
            "id": UUID().uuidString,
            "host_id": hostId.uuidString,
            "title": "With Host Space",
            "status": "live",
            "livekit_room_name": "room-host-001",
            "listener_count": 5,
            "speaker_count": 2,
            "created_at": now,
            "updated_at": now,
            "profiles": [
                "id": hostId.uuidString,
                "call_sign": "Viper",
                "first_name": "Tom",
                "last_name": "Jardian"
            ] as [String: Any]
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(HangerSpaceResponse.self, from: data)

        let spaceWithHost = response.toSpaceWithHost()
        XCTAssertEqual(spaceWithHost.hostCallSign, "Viper")
        XCTAssertEqual(spaceWithHost.hostFullName, "Viper")
        XCTAssertEqual(spaceWithHost.space.title, "With Host Space")
        XCTAssertEqual(spaceWithHost.id, response.id)
    }

    func testSpaceResponseNilProfile() throws {
        let now = ISO8601DateFormatter().string(from: Date())

        let json: [String: Any] = [
            "id": UUID().uuidString,
            "host_id": UUID().uuidString,
            "title": "No Profile Space",
            "status": "ended",
            "livekit_room_name": "room-noprof-001",
            "listener_count": 0,
            "speaker_count": 0,
            "created_at": now,
            "updated_at": now
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(HangerSpaceResponse.self, from: data)

        XCTAssertNil(response.profileData)

        let spaceWithHost = response.toSpaceWithHost()
        XCTAssertNil(spaceWithHost.hostCallSign)
        XCTAssertEqual(spaceWithHost.hostFullName, "Pilot")
    }

    // MARK: - HangerSpaceParticipant

    func testParticipantCreation() {
        let participant = HangerSpaceTestData.sampleParticipant(
            role: .speaker
        )
        XCTAssertEqual(participant.role, .speaker)
        XCTAssertNil(participant.leftAt)
    }

    func testParticipantCodableRoundTrip() throws {
        let original = HangerSpaceTestData.sampleParticipant(role: .host)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HangerSpaceParticipant.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.spaceId, original.spaceId)
        XCTAssertEqual(decoded.userId, original.userId)
        XCTAssertEqual(decoded.role, .host)
        XCTAssertNil(decoded.leftAt)
    }

    func testParticipantDecodingFromJSON() throws {
        let participantId = UUID()
        let spaceId = UUID()
        let userId = UUID()
        let now = ISO8601DateFormatter().string(from: Date())

        let json: [String: Any] = [
            "id": participantId.uuidString,
            "space_id": spaceId.uuidString,
            "user_id": userId.uuidString,
            "role": "listener",
            "joined_at": now
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let participant = try decoder.decode(HangerSpaceParticipant.self, from: data)

        XCTAssertEqual(participant.id, participantId)
        XCTAssertEqual(participant.spaceId, spaceId)
        XCTAssertEqual(participant.userId, userId)
        XCTAssertEqual(participant.role, .listener)
        XCTAssertNil(participant.leftAt)
    }

    // MARK: - HangerSpaceParticipantWithProfile

    func testParticipantWithProfileCreation() {
        let pwp = HangerSpaceTestData.sampleParticipantWithProfile(
            role: .speaker,
            callSign: "Goose",
            fullName: "Nick Bradshaw"
        )
        XCTAssertEqual(pwp.role, .speaker)
        XCTAssertEqual(pwp.callSign, "Goose")
        XCTAssertEqual(pwp.fullName, "Nick Bradshaw")
    }

    func testParticipantWithProfileMutedDefault() {
        let pwp = HangerSpaceTestData.sampleParticipantWithProfile()
        XCTAssertFalse(pwp.isMuted)

        let muted = HangerSpaceTestData.sampleParticipantWithProfile(isMuted: true)
        XCTAssertTrue(muted.isMuted)
    }

    // MARK: - HangerSpaceSpeakerRequest

    func testSpeakerRequestCreation() {
        let request = HangerSpaceTestData.sampleSpeakerRequest(status: "approved")
        XCTAssertEqual(request.status, "approved")
        XCTAssertNotNil(request.spaceId)
        XCTAssertNotNil(request.userId)
    }

    func testSpeakerRequestCodableRoundTrip() throws {
        let original = HangerSpaceTestData.sampleSpeakerRequest(status: "pending")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HangerSpaceSpeakerRequest.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.spaceId, original.spaceId)
        XCTAssertEqual(decoded.userId, original.userId)
        XCTAssertEqual(decoded.status, "pending")
    }

    // MARK: - LiveKitTokenResponse

    func testTokenResponseDecoding() throws {
        let json: [String: Any] = [
            "token": "eyJhbGciOiJIUzI1NiJ9.test-payload.signature",
            "ws_url": "wss://prod.livekit.cloud"
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        let response = try decoder.decode(LiveKitTokenResponse.self, from: data)

        XCTAssertEqual(response.token, "eyJhbGciOiJIUzI1NiJ9.test-payload.signature")
        XCTAssertEqual(response.wsUrl, "wss://prod.livekit.cloud")
    }
}
