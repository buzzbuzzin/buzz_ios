//
//  HangerSpace.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/22/26.
//

import Foundation

// MARK: - Hanger Space Status

enum HangerSpaceStatus: String, Codable {
    case scheduled
    case live
    case ended
}

// MARK: - Hanger Space Participant Role

enum HangerSpaceRole: String, Codable {
    case host
    case speaker
    case listener
}

// MARK: - Hanger Space

struct HangerSpace: Codable, Identifiable {
    let id: UUID
    let hostId: UUID
    let title: String
    let description: String?
    let status: HangerSpaceStatus
    let livekitRoomName: String
    let startedAt: Date?
    let endedAt: Date?
    let scheduledAt: Date?
    let listenerCount: Int
    let speakerCount: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case hostId = "host_id"
        case title
        case description
        case status
        case livekitRoomName = "livekit_room_name"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case scheduledAt = "scheduled_at"
        case listenerCount = "listener_count"
        case speakerCount = "speaker_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        hostId = try container.decode(UUID.self, forKey: .hostId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        status = try container.decode(HangerSpaceStatus.self, forKey: .status)
        livekitRoomName = try container.decode(String.self, forKey: .livekitRoomName)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        scheduledAt = try container.decodeIfPresent(Date.self, forKey: .scheduledAt)
        listenerCount = try container.decode(Int.self, forKey: .listenerCount)
        speakerCount = try container.decode(Int.self, forKey: .speakerCount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    init(id: UUID, hostId: UUID, title: String, description: String?,
         status: HangerSpaceStatus, livekitRoomName: String,
         startedAt: Date?, endedAt: Date?, scheduledAt: Date?,
         listenerCount: Int, speakerCount: Int,
         createdAt: Date, updatedAt: Date) {
        self.id = id
        self.hostId = hostId
        self.title = title
        self.description = description
        self.status = status
        self.livekitRoomName = livekitRoomName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.scheduledAt = scheduledAt
        self.listenerCount = listenerCount
        self.speakerCount = speakerCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Hanger Space Insert

struct HangerSpaceInsert: Codable {
    let hostId: UUID
    let title: String
    let description: String?
    let status: HangerSpaceStatus
    let livekitRoomName: String
    let startedAt: Date?

    enum CodingKeys: String, CodingKey {
        case hostId = "host_id"
        case title
        case description
        case status
        case livekitRoomName = "livekit_room_name"
        case startedAt = "started_at"
    }
}

// MARK: - Hanger Space with Host (for display)

struct HangerSpaceWithHost: Identifiable {
    let id: UUID
    let space: HangerSpace
    let hostCallSign: String?
    let hostProfilePictureUrl: String?
    let hostFullName: String
}

// MARK: - Supabase Join Response

struct HangerSpaceResponse: Codable {
    let id: UUID
    let hostId: UUID
    let title: String
    let description: String?
    let status: HangerSpaceStatus
    let livekitRoomName: String
    let startedAt: Date?
    let endedAt: Date?
    let scheduledAt: Date?
    let listenerCount: Int
    let speakerCount: Int
    let createdAt: Date
    let updatedAt: Date
    let profiles: HangerAuthorProfileOrArray?

    enum CodingKeys: String, CodingKey {
        case id
        case hostId = "host_id"
        case title
        case description
        case status
        case livekitRoomName = "livekit_room_name"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case scheduledAt = "scheduled_at"
        case listenerCount = "listener_count"
        case speakerCount = "speaker_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case profiles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        hostId = try container.decode(UUID.self, forKey: .hostId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        status = try container.decode(HangerSpaceStatus.self, forKey: .status)
        livekitRoomName = try container.decode(String.self, forKey: .livekitRoomName)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        scheduledAt = try container.decodeIfPresent(Date.self, forKey: .scheduledAt)
        listenerCount = try container.decode(Int.self, forKey: .listenerCount)
        speakerCount = try container.decode(Int.self, forKey: .speakerCount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        profiles = try container.decodeIfPresent(HangerAuthorProfileOrArray.self, forKey: .profiles)
    }

    var profileData: HangerAuthorProfile? {
        switch profiles {
        case .single(let profile): return profile
        case .array(let profiles): return profiles.first
        case .none: return nil
        }
    }

    func toHangerSpace() -> HangerSpace {
        HangerSpace(
            id: id, hostId: hostId, title: title, description: description,
            status: status, livekitRoomName: livekitRoomName,
            startedAt: startedAt, endedAt: endedAt, scheduledAt: scheduledAt,
            listenerCount: listenerCount, speakerCount: speakerCount,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }

    func toSpaceWithHost() -> HangerSpaceWithHost {
        let profile = profileData
        return HangerSpaceWithHost(
            id: id,
            space: toHangerSpace(),
            hostCallSign: profile?.callSign,
            hostProfilePictureUrl: profile?.profilePictureUrl,
            hostFullName: profile?.callSign ?? "Pilot"
        )
    }
}

// MARK: - Hanger Space Participant

struct HangerSpaceParticipant: Codable, Identifiable {
    let id: UUID
    let spaceId: UUID
    let userId: UUID
    let role: HangerSpaceRole
    let joinedAt: Date
    let leftAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case spaceId = "space_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
        case leftAt = "left_at"
    }
}

// MARK: - Hanger Space Participant with Profile (for room display)

struct HangerSpaceParticipantWithProfile: Identifiable {
    let id: UUID
    let userId: UUID
    let role: HangerSpaceRole
    let callSign: String?
    let profilePictureUrl: String?
    let fullName: String
    var isMuted: Bool = false
}

// MARK: - Supabase Participant Join Response

struct HangerSpaceParticipantResponse: Codable {
    let id: UUID
    let spaceId: UUID
    let userId: UUID
    let role: HangerSpaceRole
    let joinedAt: Date
    let leftAt: Date?
    let profiles: HangerAuthorProfileOrArray?

    enum CodingKeys: String, CodingKey {
        case id
        case spaceId = "space_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
        case leftAt = "left_at"
        case profiles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        spaceId = try container.decode(UUID.self, forKey: .spaceId)
        userId = try container.decode(UUID.self, forKey: .userId)
        role = try container.decode(HangerSpaceRole.self, forKey: .role)
        joinedAt = try container.decode(Date.self, forKey: .joinedAt)
        leftAt = try container.decodeIfPresent(Date.self, forKey: .leftAt)
        profiles = try container.decodeIfPresent(HangerAuthorProfileOrArray.self, forKey: .profiles)
    }

    var profileData: HangerAuthorProfile? {
        switch profiles {
        case .single(let profile): return profile
        case .array(let profiles): return profiles.first
        case .none: return nil
        }
    }

    func toParticipantWithProfile() -> HangerSpaceParticipantWithProfile {
        let profile = profileData
        return HangerSpaceParticipantWithProfile(
            id: id,
            userId: userId,
            role: role,
            callSign: profile?.callSign,
            profilePictureUrl: profile?.profilePictureUrl,
            fullName: profile?.callSign ?? "Pilot"
        )
    }
}

// MARK: - Speaker Request

struct HangerSpaceSpeakerRequest: Codable, Identifiable {
    let id: UUID
    let spaceId: UUID
    let userId: UUID
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case spaceId = "space_id"
        case userId = "user_id"
        case status
        case createdAt = "created_at"
    }
}

// MARK: - LiveKit Token Response

struct LiveKitTokenResponse: Codable {
    let token: String
    let wsUrl: String

    enum CodingKeys: String, CodingKey {
        case token
        case wsUrl = "ws_url"
    }
}
