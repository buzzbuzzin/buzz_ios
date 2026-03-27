//
//  ChartsOverlayToolbar.swift
//  Buzz
//
//  Toggle buttons for METAR/Airspace overlays on VFR charts
//

import SwiftUI

struct ChartsOverlayToolbar: View {
    @Binding var showMETAROverlay: Bool
    @Binding var showAirspaceOverlay: Bool

    var body: some View {
        VStack(spacing: 6) {
            OverlayToggleButton(
                icon: "cloud.sun.fill",
                title: "Weather",
                accessibilityHint: "Shows nearby METAR weather stations on the chart.",
                isActive: $showMETAROverlay
            )

            OverlayToggleButton(
                icon: "square.dashed",
                title: "Airspace",
                accessibilityHint: "Shows controlled airspace boundaries on the chart.",
                isActive: $showAirspaceOverlay
            )
        }
    }
}

// MARK: - Overlay Toggle Button

private struct OverlayToggleButton: View {
    let icon: String
    let title: String
    let accessibilityHint: String
    @Binding var isActive: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isActive.toggle()
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundColor(isActive ? .white : .secondary)
            .frame(minWidth: 58, minHeight: 46)
            .background(isActive ? Color.blue : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isActive ? "On" : "Off")
        .accessibilityHint(accessibilityHint)
    }
}
