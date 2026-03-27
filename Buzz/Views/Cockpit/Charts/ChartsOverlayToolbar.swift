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
                label: "WX",
                isActive: $showMETAROverlay
            )

            OverlayToggleButton(
                icon: "square.dashed",
                label: "AS",
                isActive: $showAirspaceOverlay
            )
        }
    }
}

// MARK: - Overlay Toggle Button

private struct OverlayToggleButton: View {
    let icon: String
    let label: String
    @Binding var isActive: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isActive.toggle()
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundColor(isActive ? .white : .secondary)
            .frame(width: 36, height: 36)
            .background(isActive ? Color.blue : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 2)
        }
    }
}
