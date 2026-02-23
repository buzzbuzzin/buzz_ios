//
//  HangerSpaceRoomView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/22/26.
//

import SwiftUI

struct HangerSpaceRoomView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject var spaceService: HangerSpaceService
    let space: HangerSpace
    @Environment(\.dismiss) var dismiss

    @State private var showEndConfirmation = false
    @State private var showError = false
    @State private var actionErrorMessage = ""

    private var isHost: Bool {
        space.hostId == authService.activeUserId
    }

    private var isSpeaker: Bool {
        guard let userId = authService.activeUserId else { return false }
        return spaceService.participants.contains { $0.userId == userId && ($0.role == .speaker || $0.role == .host) }
    }

    private var speakers: [HangerSpaceParticipantWithProfile] {
        spaceService.participants.filter { $0.role == .host || $0.role == .speaker }
    }

    private var listeners: [HangerSpaceParticipantWithProfile] {
        spaceService.participants.filter { $0.role == .listener }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                spaceHeader

                Divider()

                ScrollView {
                    VStack(spacing: 24) {
                        // Speakers section
                        speakersSection

                        if !listeners.isEmpty {
                            Divider()
                                .padding(.horizontal)

                            // Listeners section
                            listenersSection
                        }

                        // Speaker requests (host only)
                        if isHost && !spaceService.speakerRequests.isEmpty {
                            Divider()
                                .padding(.horizontal)
                            speakerRequestsSection
                        }
                    }
                    .padding()
                }

                Divider()

                // Bottom bar
                bottomBar
            }
            .navigationBarHidden(true)
            .task {
                await spaceService.subscribeToSpaceUpdates(spaceId: space.id)
                await spaceService.refreshParticipants(spaceId: space.id)
                if isHost {
                    await spaceService.refreshSpeakerRequests(spaceId: space.id)
                }
            }
            .alert("End Space", isPresented: $showEndConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("End Space", role: .destructive) {
                    Task {
                        do {
                            try await spaceService.endSpace(spaceId: space.id)
                            dismiss()
                        } catch {
                            actionErrorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
            } message: {
                Text("This will end the Space for all participants.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(actionErrorMessage)
            }
            .onChange(of: spaceService.currentSpace?.status) { newStatus in
                if newStatus == .ended {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Header

    private var spaceHeader: some View {
        HStack {
            Button {
                if isHost {
                    showEndConfirmation = true
                } else {
                    Task {
                        guard let userId = authService.activeUserId else { return }
                        do {
                            try await spaceService.leaveSpace(spaceId: space.id, userId: userId)
                            dismiss()
                        } catch {
                            actionErrorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.body)
                    .foregroundColor(.primary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(space.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "headphones")
                        .font(.system(size: 10))
                    Text("\(spaceService.currentSpace?.listenerCount ?? space.listenerCount)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            // Placeholder for symmetry
            Color.clear
                .frame(width: 24, height: 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Speakers Section

    private var speakersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Speakers")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80), spacing: 16)
            ], spacing: 16) {
                ForEach(speakers) { participant in
                    SpeakerBubble(participant: participant, isHost: participant.role == .host)
                        .contextMenu {
                            if isHost && participant.role == .speaker {
                                Button(role: .destructive) {
                                    Task {
                                        try? await spaceService.removeSpeaker(spaceId: space.id, userId: participant.userId)
                                    }
                                } label: {
                                    Label("Remove from Speakers", systemImage: "mic.slash")
                                }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Listeners Section

    private var listenersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Listeners")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 60), spacing: 12)
            ], spacing: 12) {
                ForEach(listeners) { participant in
                    ListenerBubble(participant: participant)
                }
            }
        }
    }

    // MARK: - Speaker Requests Section

    private var speakerRequestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Requests to Speak")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.orange)

            ForEach(spaceService.speakerRequests) { request in
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.orange)
                    Text("Request from participant")
                        .font(.subheadline)
                    Spacer()
                    Button("Approve") {
                        Task {
                            try? await spaceService.approveSpeaker(
                                requestId: request.id,
                                spaceId: space.id,
                                userId: request.userId
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.small)

                    Button("Decline") {
                        Task {
                            try? await spaceService.declineSpeaker(requestId: request.id)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 20) {
            if isHost {
                Button {
                    showEndConfirmation = true
                } label: {
                    Text("End")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .cornerRadius(20)
                }
            } else {
                Button {
                    Task {
                        guard let userId = authService.activeUserId else { return }
                        do {
                            try await spaceService.leaveSpace(spaceId: space.id, userId: userId)
                            dismiss()
                        } catch {
                            actionErrorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                } label: {
                    Text("Leave")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .cornerRadius(20)
                }
            }

            Spacer()

            if isSpeaker {
                // Mic toggle
                Button {
                    Task { await spaceService.toggleMicrophone() }
                } label: {
                    Image(systemName: spaceService.isMicrophoneEnabled ? "mic.fill" : "mic.slash.fill")
                        .font(.title2)
                        .foregroundColor(spaceService.isMicrophoneEnabled ? .primary : .red)
                        .frame(width: 48, height: 48)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            } else {
                // Hand raise (request to speak)
                Button {
                    guard let userId = authService.activeUserId else { return }
                    Task {
                        try? await spaceService.requestToSpeak(spaceId: space.id, userId: userId)
                    }
                } label: {
                    Image(systemName: "hand.raised.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                        .frame(width: 48, height: 48)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).shadow(radius: 2))
    }
}

// MARK: - Speaker Bubble

struct SpeakerBubble: View {
    let participant: HangerSpaceParticipantWithProfile
    var isHost: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Speaking indicator ring
                Circle()
                    .stroke(participant.isMuted ? Color.gray : Color.purple, lineWidth: 3)
                    .frame(width: 64, height: 64)

                // Avatar
                if let urlString = participant.profilePictureUrl,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.secondary)
                }

                // Muted indicator
                if participant.isMuted {
                    Image(systemName: "mic.slash.fill")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 20, y: 20)
                }
            }

            Text(participant.callSign ?? participant.fullName)
                .font(.caption2)
                .lineLimit(1)

            if isHost {
                Text("Host")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.purple)
            }
        }
    }
}

// MARK: - Listener Bubble

struct ListenerBubble: View {
    let participant: HangerSpaceParticipantWithProfile

    var body: some View {
        VStack(spacing: 4) {
            if let urlString = participant.profilePictureUrl,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
            }

            Text(participant.callSign ?? participant.fullName)
                .font(.system(size: 9))
                .lineLimit(1)
                .foregroundColor(.secondary)
        }
    }
}
