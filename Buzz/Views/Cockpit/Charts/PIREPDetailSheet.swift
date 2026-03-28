//
//  PIREPDetailSheet.swift
//  Buzz
//
//  Created for showing chart PIREP details after a tap.
//

import SwiftUI

struct PIREPDetailSheet: View {
    let pirep: PIREP
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if !pirep.turbulenceLayers.isEmpty {
                        section(title: "Turbulence") {
                            ForEach(Array(pirep.turbulenceLayers.enumerated()), id: \.offset) { _, layer in
                                metricRow(label: "Layer", value: layer.summary)
                            }
                        }
                    }

                    if !pirep.icingLayers.isEmpty {
                        section(title: "Icing") {
                            ForEach(Array(pirep.icingLayers.enumerated()), id: \.offset) { _, layer in
                                metricRow(label: "Layer", value: layer.summary)
                            }
                        }
                    }

                    section(title: "Observation") {
                        metricRow(label: "Report Type", value: pirep.reportType.displayName)
                        metricRow(label: "Observed", value: observationTimeText)
                        metricRow(label: "Aircraft", value: pirep.aircraftType ?? "Unknown")
                        metricRow(label: "Flight Level", value: pirep.flightLevelDisplay)
                        if let weatherPhenomena = pirep.weatherPhenomena {
                            metricRow(label: "Weather", value: weatherPhenomena)
                        }
                    }

                    section(title: "Raw PIREP") {
                        Text(pirep.rawText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("PIREP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: pirep.dominantHazard.systemImage)
                .font(.title2)
                .foregroundColor(Color(ChartsWeatherOverlayHelper.pirepTintColor(for: pirep.dominantHazard)))
                .frame(width: 44, height: 44)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(pirep.dominantHazard.displayName)
                    .font(.title3.weight(.semibold))

                Text(pirep.hazardSummary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var observationTimeText: String {
        pirep.observationTime.formatted(date: .abbreviated, time: .shortened)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            content()
        }
    }

    private func metricRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}
