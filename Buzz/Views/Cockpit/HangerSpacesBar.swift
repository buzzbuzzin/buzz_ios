//
//  HangerSpacesBar.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/22/26.
//

import SwiftUI

struct HangerSpacesBar: View {
    let spaces: [HangerSpaceWithHost]
    let onSpaceTap: (HangerSpaceWithHost) -> Void
    let onCreateTap: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "Start a Space" button
                createSpaceButton

                // Live spaces
                ForEach(spaces) { spaceWithHost in
                    SpacePill(spaceWithHost: spaceWithHost)
                        .onTapGesture { onSpaceTap(spaceWithHost) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var createSpaceButton: some View {
        Button(action: onCreateTap) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.purple, style: StrokeStyle(lineWidth: 2, dash: [4]))
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.purple)
                }
                Text("Start")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Space Pill

struct SpacePill: View {
    let spaceWithHost: HangerSpaceWithHost

    var body: some View {
        VStack(spacing: 6) {
            // Host avatar with animated LIVE ring
            ZStack {
                // Animated purple ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 60, height: 60)

                // Host avatar
                if let urlString = spaceWithHost.hostProfilePictureUrl,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                }
            }

            // Space title (truncated)
            Text(spaceWithHost.space.title)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 64)

            // Listener count
            HStack(spacing: 2) {
                Image(systemName: "headphones")
                    .font(.system(size: 8))
                Text("\(spaceWithHost.space.listenerCount)")
                    .font(.system(size: 9))
            }
            .foregroundColor(.secondary)
        }
    }
}
