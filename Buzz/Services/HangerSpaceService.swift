//
//  HangerSpaceService.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/22/26.
//

import Foundation
import Combine
import Supabase
import Realtime
#if canImport(LiveKitSDK)
import LiveKitSDK
#endif

@MainActor
class HangerSpaceService: ObservableObject {
    // MARK: - Published Properties
    @Published var liveSpaces: [HangerSpaceWithHost] = []
    @Published var currentSpace: HangerSpace?
    @Published var participants: [HangerSpaceParticipantWithProfile] = []
    @Published var speakerRequests: [HangerSpaceSpeakerRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var liveHostIds: Set<UUID> = []

    // LiveKit state
    #if canImport(LiveKitSDK)
    @Published var room: Room?
    @Published var connectionState: ConnectionState = .disconnected
    #endif
    @Published var isMicrophoneEnabled = false

    private let supabase = SupabaseClient.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var feedRealtimeChannel: RealtimeChannelV2?

    // MARK: - Fetch Live Spaces (for horizontal scroll at top of feed)

    func fetchLiveSpaces() async {
        if DemoModeManager.shared.isDemoModeEnabled {
            liveSpaces = []
            return
        }

        do {
            let response: [HangerSpaceResponse] = try await supabase
                .from("hanger_spaces")
                .select("*, profiles(id, call_sign, profile_picture_url, first_name, last_name)")
                .eq("status", value: "live")
                .order("started_at", ascending: false)
                .limit(20)
                .execute()
                .value

            liveSpaces = response.map { $0.toSpaceWithHost() }
        } catch {
            print("Error fetching live spaces: \(error)")
        }
    }

    // MARK: - Fetch Live Host IDs (for LIVE indicator on post cards)

    func fetchLiveHostIds(authorIds: [UUID]) async {
        if DemoModeManager.shared.isDemoModeEnabled {
            liveHostIds = []
            return
        }
        guard !authorIds.isEmpty else {
            liveHostIds = []
            return
        }

        do {
            struct HostIdOnly: Decodable {
                let hostId: UUID
                enum CodingKeys: String, CodingKey { case hostId = "host_id" }
            }
            let results: [HostIdOnly] = try await supabase
                .from("hanger_spaces")
                .select("host_id")
                .eq("status", value: "live")
                .in("host_id", values: authorIds.map { $0.uuidString })
                .execute()
                .value
            liveHostIds = Set(results.map { $0.hostId })
        } catch {
            print("Error fetching live host IDs: \(error)")
        }
    }

    // MARK: - Check if User is Live

    func isUserLive(userId: UUID) async -> Bool {
        if DemoModeManager.shared.isDemoModeEnabled { return false }

        do {
            struct IdOnly: Decodable { let id: UUID }
            let results: [IdOnly] = try await supabase
                .from("hanger_spaces")
                .select("id")
                .eq("host_id", value: userId.uuidString)
                .eq("status", value: "live")
                .limit(1)
                .execute()
                .value
            return !results.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Fetch Space for User (get the space a user is hosting)

    func fetchLiveSpaceForHost(hostId: UUID) async -> HangerSpace? {
        if DemoModeManager.shared.isDemoModeEnabled { return nil }

        do {
            let response: [HangerSpace] = try await supabase
                .from("hanger_spaces")
                .select()
                .eq("host_id", value: hostId.uuidString)
                .eq("status", value: "live")
                .limit(1)
                .execute()
                .value
            return response.first
        } catch {
            return nil
        }
    }

    // MARK: - Create Space (Host)

    func createSpace(hostId: UUID, title: String, description: String?) async throws -> HangerSpace {
        if DemoModeManager.shared.isDemoModeEnabled {
            throw NSError(domain: "HangerSpaceService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Spaces not available in demo mode"])
        }

        let roomName = "space_\(UUID().uuidString.lowercased())"
        let insert = HangerSpaceInsert(
            hostId: hostId,
            title: title,
            description: description,
            status: .live,
            livekitRoomName: roomName,
            startedAt: Date()
        )

        let response: [HangerSpace] = try await supabase
            .from("hanger_spaces")
            .insert(insert)
            .select()
            .execute()
            .value

        guard let space = response.first else {
            throw NSError(domain: "HangerSpaceService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create space"])
        }

        // Insert host as participant
        let participantData: [String: AnyJSON] = [
            "space_id": .string(space.id.uuidString),
            "user_id": .string(hostId.uuidString),
            "role": .string("host")
        ]
        try await supabase
            .from("hanger_space_participants")
            .insert(participantData)
            .execute()

        // Get LiveKit token and connect (host can publish audio)
        let callSign = await fetchCallSign(userId: hostId) ?? "Pilot"
        await connectToLiveKit(roomName: roomName, userName: callSign, canPublish: true)

        // Notify followers
        await notifyFollowersOfNewSpace(hostId: hostId, spaceId: space.id, title: title)

        currentSpace = space
        return space
    }

    // MARK: - Join Space (Listener)

    func joinSpace(spaceId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        // Get the space details first
        let spaces: [HangerSpace] = try await supabase
            .from("hanger_spaces")
            .select()
            .eq("id", value: spaceId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let space = spaces.first else {
            throw NSError(domain: "HangerSpaceService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Space not found"])
        }

        // Insert participant as listener
        let participantData: [String: AnyJSON] = [
            "space_id": .string(spaceId.uuidString),
            "user_id": .string(userId.uuidString),
            "role": .string("listener")
        ]
        try await supabase
            .from("hanger_space_participants")
            .insert(participantData)
            .execute()

        // Get LiveKit token and connect (listener cannot publish)
        let callSign = await fetchCallSign(userId: userId) ?? "Pilot"
        await connectToLiveKit(roomName: space.livekitRoomName, userName: callSign, canPublish: false)

        currentSpace = space

        // Subscribe to realtime updates
        await subscribeToSpaceUpdates(spaceId: spaceId)

        // Fetch current participants
        await refreshParticipants(spaceId: spaceId)
    }

    // MARK: - End Space (Host)

    func endSpace(spaceId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        let update: [String: AnyJSON] = [
            "status": .string("ended"),
            "ended_at": .string(ISO8601DateFormatter().string(from: Date())),
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        try await supabase
            .from("hanger_spaces")
            .update(update)
            .eq("id", value: spaceId.uuidString)
            .execute()

        await disconnectFromLiveKit()
        unsubscribeFromSpaceUpdates()
        currentSpace = nil
        participants = []
        speakerRequests = []
    }

    // MARK: - Leave Space

    func leaveSpace(spaceId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        try await supabase
            .from("hanger_space_participants")
            .delete()
            .eq("space_id", value: spaceId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()

        await disconnectFromLiveKit()
        unsubscribeFromSpaceUpdates()
        currentSpace = nil
        participants = []
        speakerRequests = []
    }

    // MARK: - Request to Speak

    func requestToSpeak(spaceId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        let data: [String: AnyJSON] = [
            "space_id": .string(spaceId.uuidString),
            "user_id": .string(userId.uuidString),
            "status": .string("pending")
        ]
        try await supabase
            .from("hanger_space_speaker_requests")
            .insert(data)
            .execute()
    }

    // MARK: - Approve Speaker (Host)

    func approveSpeaker(requestId: UUID, spaceId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        // Update the request status
        let requestUpdate: [String: AnyJSON] = ["status": .string("approved")]
        try await supabase
            .from("hanger_space_speaker_requests")
            .update(requestUpdate)
            .eq("id", value: requestId.uuidString)
            .execute()

        // Update the participant role to speaker
        let participantUpdate: [String: AnyJSON] = ["role": .string("speaker")]
        try await supabase
            .from("hanger_space_participants")
            .update(participantUpdate)
            .eq("space_id", value: spaceId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()

        await refreshParticipants(spaceId: spaceId)
        await refreshSpeakerRequests(spaceId: spaceId)
    }

    // MARK: - Decline Speaker Request (Host)

    func declineSpeaker(requestId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        let requestUpdate: [String: AnyJSON] = ["status": .string("declined")]
        try await supabase
            .from("hanger_space_speaker_requests")
            .update(requestUpdate)
            .eq("id", value: requestId.uuidString)
            .execute()

        if let spaceId = currentSpace?.id {
            await refreshSpeakerRequests(spaceId: spaceId)
        }
    }

    // MARK: - Remove Speaker (Host demotes back to listener)

    func removeSpeaker(spaceId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        let participantUpdate: [String: AnyJSON] = ["role": .string("listener")]
        try await supabase
            .from("hanger_space_participants")
            .update(participantUpdate)
            .eq("space_id", value: spaceId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()

        await refreshParticipants(spaceId: spaceId)
    }

    // MARK: - LiveKit Connection

    #if canImport(LiveKitSDK)
    private func connectToLiveKit(roomName: String, userName: String, canPublish: Bool) async {
        do {
            struct TokenRequest: Codable {
                let room_name: String
                let user_name: String
                let can_publish: Bool
            }

            let tokenRequest = TokenRequest(
                room_name: roomName,
                user_name: userName,
                can_publish: canPublish
            )

            let response: LiveKitTokenResponse = try await supabase.functions.invoke(
                "generate-livekit-token",
                options: FunctionInvokeOptions(body: tokenRequest)
            ).value

            let livekitRoom = Room()
            try await livekitRoom.connect(url: response.wsUrl, token: response.token)

            room = livekitRoom
            connectionState = .connected

            // Enable microphone for hosts/speakers
            if canPublish {
                try await livekitRoom.localParticipant.setMicrophone(enabled: true)
                isMicrophoneEnabled = true
            }
        } catch {
            print("Error connecting to LiveKit: \(error)")
            errorMessage = "Failed to connect to audio room"
        }
    }

    private func disconnectFromLiveKit() async {
        await room?.disconnect()
        room = nil
        connectionState = .disconnected
        isMicrophoneEnabled = false
    }

    func toggleMicrophone() async {
        guard let room = room else { return }

        do {
            let newState = !isMicrophoneEnabled
            try await room.localParticipant.setMicrophone(enabled: newState)
            isMicrophoneEnabled = newState
        } catch {
            print("Error toggling microphone: \(error)")
        }
    }
    #else
    private func connectToLiveKit(roomName: String, userName: String, canPublish: Bool) async {
        print("LiveKit SDK not available — audio room connection skipped")
        if canPublish {
            isMicrophoneEnabled = true
        }
    }

    private func disconnectFromLiveKit() async {
        isMicrophoneEnabled = false
    }

    func toggleMicrophone() async {
        isMicrophoneEnabled.toggle()
    }
    #endif

    // MARK: - Refresh Participants

    func refreshParticipants(spaceId: UUID) async {
        do {
            let response: [HangerSpaceParticipantResponse] = try await supabase
                .from("hanger_space_participants")
                .select("*, profiles(id, call_sign, profile_picture_url, first_name, last_name)")
                .eq("space_id", value: spaceId.uuidString)
                .is("left_at", value: nil)
                .execute()
                .value

            participants = response.map { $0.toParticipantWithProfile() }
        } catch {
            print("Error refreshing participants: \(error)")
        }
    }

    // MARK: - Refresh Speaker Requests

    func refreshSpeakerRequests(spaceId: UUID) async {
        do {
            let response: [HangerSpaceSpeakerRequest] = try await supabase
                .from("hanger_space_speaker_requests")
                .select()
                .eq("space_id", value: spaceId.uuidString)
                .eq("status", value: "pending")
                .order("created_at", ascending: true)
                .execute()
                .value

            speakerRequests = response
        } catch {
            print("Error refreshing speaker requests: \(error)")
        }
    }

    // MARK: - Supabase Realtime Subscriptions

    func subscribeToSpaceUpdates(spaceId: UUID) async {
        let channel = supabase.realtimeV2.channel("space_\(spaceId.uuidString)")

        let participantChanges = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "hanger_space_participants",
            filter: .eq("space_id", value: spaceId.uuidString)
        )

        let spaceChanges = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "hanger_spaces",
            filter: .eq("id", value: spaceId.uuidString)
        )

        let requestChanges = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "hanger_space_speaker_requests",
            filter: .eq("space_id", value: spaceId.uuidString)
        )

        await channel.subscribe()

        Task {
            for await _ in participantChanges {
                await refreshParticipants(spaceId: spaceId)
            }
        }
        Task {
            for await _ in spaceChanges {
                // Refresh the space status - check if ended
                await refreshSpaceStatus(spaceId: spaceId)
            }
        }
        Task {
            for await _ in requestChanges {
                await refreshSpeakerRequests(spaceId: spaceId)
            }
        }

        self.realtimeChannel = channel
    }

    func subscribeToLiveSpacesFeed() async {
        let channel = supabase.realtimeV2.channel("live_spaces_feed")

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "hanger_spaces"
        )

        await channel.subscribe()

        Task {
            for await _ in changes {
                await fetchLiveSpaces()
            }
        }

        self.feedRealtimeChannel = channel
    }

    func unsubscribeFromSpaceUpdates() {
        Task {
            if let channel = realtimeChannel {
                await channel.unsubscribe()
            }
            realtimeChannel = nil
        }
    }

    func unsubscribeFromFeedUpdates() {
        Task {
            if let channel = feedRealtimeChannel {
                await channel.unsubscribe()
            }
            feedRealtimeChannel = nil
        }
    }

    // MARK: - Refresh Space Status

    private func refreshSpaceStatus(spaceId: UUID) async {
        do {
            let spaces: [HangerSpace] = try await supabase
                .from("hanger_spaces")
                .select()
                .eq("id", value: spaceId.uuidString)
                .limit(1)
                .execute()
                .value

            if let space = spaces.first {
                currentSpace = space
                if space.status == .ended {
                    await disconnectFromLiveKit()
                    unsubscribeFromSpaceUpdates()
                }
            }
        } catch {
            print("Error refreshing space status: \(error)")
        }
    }

    // MARK: - Notification Helper

    private func notifyFollowersOfNewSpace(hostId: UUID, spaceId: UUID, title: String) async {
        guard let hostCallSign = await fetchCallSign(userId: hostId) else { return }

        let followers: [UserFollow] = (try? await supabase
            .from("user_follows")
            .select()
            .eq("following_id", value: hostId.uuidString)
            .execute()
            .value) ?? []

        for follower in followers {
            await NotificationManager.shared.notifyHangerTalkSpaceLive(
                spaceId: spaceId,
                followerUserId: follower.followerId,
                hostCallSign: hostCallSign,
                spaceTitle: title
            )
            await insertSpaceNotification(
                recipientId: follower.followerId,
                actorId: hostId,
                type: .spaceLive,
                postId: nil
            )
        }
    }

    private func insertSpaceNotification(recipientId: UUID, actorId: UUID, type: HangerTalkNotificationType, postId: UUID?) async {
        if DemoModeManager.shared.isDemoModeEnabled { return }
        guard recipientId != actorId else { return }

        let insert = HangerTalkNotificationInsert(
            recipientId: recipientId,
            actorId: actorId,
            type: type,
            postId: postId
        )

        do {
            try await supabase
                .from("hanger_talk_notifications")
                .insert(insert)
                .execute()
        } catch {
            print("Error inserting space notification: \(error)")
        }
    }

    // MARK: - Helpers

    private func fetchCallSign(userId: UUID) async -> String? {
        do {
            let profiles: [HangerAuthorProfile] = try await supabase
                .from("profiles")
                .select("id, call_sign, profile_picture_url, first_name, last_name")
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            return profiles.first?.callSign
        } catch {
            print("Error fetching call sign: \(error)")
            return nil
        }
    }
}
