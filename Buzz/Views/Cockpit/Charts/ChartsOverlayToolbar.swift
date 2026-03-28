//
//  ChartsOverlayToolbar.swift
//  Buzz
//
//  Toggle buttons for chart overlays on VFR charts.
//

import SwiftUI

struct ChartsOverlayToolbar: View {
    @Binding var showMETAROverlay: Bool
    @Binding var showPIREPOverlay: Bool
    @Binding var showGairmetOverlay: Bool
    @Binding var showSigmetOverlay: Bool
    @Binding var showAirspaceOverlay: Bool

    var body: some View {
        VStack(spacing: 6) {
            OverlayToggleButton(
                icon: "cloud.sun.fill",
                title: "METAR",
                accessibilityHint: "Shows nearby METAR weather stations on the chart.",
                isActive: $showMETAROverlay
            )

            OverlayToggleButton(
                icon: "wind",
                title: "PIREP",
                accessibilityHint: "Shows recent pilot reports on the chart.",
                isActive: $showPIREPOverlay
            )

            OverlayToggleButton(
                icon: "cloud.fog.fill",
                title: "G-AIRMET",
                accessibilityHint: "Shows G-AIRMET forecast hazards on the chart.",
                isActive: $showGairmetOverlay
            )

            OverlayToggleButton(
                icon: "exclamationmark.triangle.fill",
                title: "SIGMET",
                accessibilityHint: "Shows active SIGMET hazard polygons on the chart.",
                isActive: $showSigmetOverlay
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
                    .font(.system(size: 8, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundColor(isActive ? .white : .secondary)
            .frame(minWidth: 64, minHeight: 46)
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
