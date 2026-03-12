//
//  MissionDistanceSettingsView.swift
//  Buzz
//

import SwiftUI

struct MissionDistanceSettingsView: View {
    @AppStorage(MissionDistancePreference.storageKey)
    private var missionDistanceMiles: Double = MissionDistancePreference.defaultMiles

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mission Distance")
                        .font(.headline)

                    Text("Choose how far you are prepared to travel for missions. The Missions tab uses this distance to filter the list around your current location.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
            }

            Section("Distance") {
                HStack {
                    Text("Current Distance")
                    Spacer()
                    Text(String(format: "%.0f mi", missionDistanceMiles))
                        .foregroundColor(.secondary)
                }

                Slider(value: $missionDistanceMiles, in: 1...MissionDistancePreference.maxMiles, step: 1)
                    .tint(.blue)

                HStack(spacing: 8) {
                    ForEach(MissionDistancePreference.quickOptions, id: \.self) { distance in
                        Button {
                            missionDistanceMiles = distance
                        } label: {
                            Text("\(Int(distance))")
                                .font(.caption)
                                .fontWeight(missionDistanceMiles == distance ? .bold : .regular)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(missionDistanceMiles == distance ? Color.blue : Color(.systemGray5))
                                .foregroundColor(missionDistanceMiles == distance ? .white : .primary)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Mission Distance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
