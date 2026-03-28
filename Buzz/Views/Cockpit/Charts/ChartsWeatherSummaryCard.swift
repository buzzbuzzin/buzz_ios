//
//  ChartsWeatherSummaryCard.swift
//  Buzz
//
//  Created for summarizing active weather overlays on VFR charts.
//

import SwiftUI

struct ChartsWeatherSummaryCard: View {
    let pireps: [PIREP]
    let gairmets: [GAIRMETAdvisory]
    let sigmets: [SIGMETAdvisory]
    let showPIREPOverlay: Bool
    let showGairmetOverlay: Bool
    let showSigmetOverlay: Bool
    @Binding var selectedGairmetForecastHour: Int

    private let forecastOptions = [0, 3, 6, 9, 12]

    var body: some View {
        if hasContent {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "cloud.sun.bolt.fill")
                        .foregroundColor(.blue)
                    Text("Weather Hazards")
                        .font(.headline)
                    Spacer()
                }

                if showGairmetOverlay {
                    Picker("G-AIRMET Forecast", selection: $selectedGairmetForecastHour) {
                        ForEach(forecastOptions, id: \.self) { hour in
                            Text(hour == 0 ? "Now" : "+\(hour)h")
                                .tag(hour)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if showPIREPOverlay {
                    summaryRow(
                        title: "PIREP",
                        items: pirepItems,
                        emptyText: "No recent reports"
                    )
                }

                if showGairmetOverlay {
                    summaryRow(
                        title: "G-AIRMET",
                        items: gairmetItems,
                        emptyText: selectedGairmetForecastHour == 0 ? "No current hazards" : "No hazards at +\(selectedGairmetForecastHour)h"
                    )
                }

                if showSigmetOverlay {
                    summaryRow(
                        title: "SIGMET",
                        items: sigmetItems,
                        emptyText: "No active SIGMETs"
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
        }
    }

    private var hasContent: Bool {
        showPIREPOverlay || showGairmetOverlay || showSigmetOverlay
    }

    private var pirepItems: [SummaryItem] {
        SummaryItem.counts(for: pireps.map(\.dominantHazard.displayName))
    }

    private var gairmetItems: [SummaryItem] {
        SummaryItem.counts(for: gairmets.map(\.displayName))
    }

    private var sigmetItems: [SummaryItem] {
        SummaryItem.counts(for: sigmets.map(\.displayName))
    }

    private func summaryRow(title: String, items: [SummaryItem], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            if items.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(items) { item in
                            Text("\(item.title) \(item.count)")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
}

private struct SummaryItem: Identifiable {
    let id = UUID()
    let title: String
    let count: Int

    static func counts(for titles: [String]) -> [SummaryItem] {
        let grouped = Dictionary(grouping: titles, by: { $0 })
        return grouped
            .map { SummaryItem(title: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.title < $1.title
                }
                return $0.count > $1.count
            }
    }
}
