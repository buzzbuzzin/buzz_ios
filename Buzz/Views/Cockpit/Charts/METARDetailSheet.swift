//
//  METARDetailSheet.swift
//  Buzz
//
//  SwiftUI sheet showing decoded METAR/TAF for a tapped station
//

import SwiftUI

struct METARDetailSheet: View {
    let metar: METAR
    let taf: TAF?
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Station header
                    stationHeader

                    Divider()

                    // Decoded METAR
                    metarSection

                    // Weather phenomena
                    if let wx = metar.weatherPhenomena, !wx.isEmpty {
                        weatherSection(wx)
                    }

                    Divider()

                    // Raw METAR
                    rawTextSection(title: "Raw METAR", text: metar.rawText)

                    // TAF section
                    if let taf = taf {
                        Divider()
                        tafSection(taf)
                    }
                }
                .padding()
            }
            .navigationTitle(metar.stationId)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                }
            }
        }
    }

    // MARK: - Station Header

    private var stationHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(metar.stationId)
                    .font(.title2)
                    .fontWeight(.bold)

                if let name = metar.stationName {
                    Text(name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            flightCategoryBadge
        }
    }

    private var flightCategoryBadge: some View {
        Text(metar.flightCategory.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(flightCategoryColor)
            .clipShape(Capsule())
    }

    private var flightCategoryColor: Color {
        switch metar.flightCategory {
        case .vfr: return .green
        case .mvfr: return .blue
        case .ifr: return .red
        case .lifr: return .purple
        case .unknown: return .gray
        }
    }

    // MARK: - METAR Section

    private var metarSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            metarMetric(label: "Wind", value: windString)
            metarMetric(label: "Visibility", value: visibilityString)
            metarMetric(label: "Ceiling", value: ceilingString)
            metarMetric(label: "Temperature", value: temperatureString)
            metarMetric(label: "Dewpoint", value: dewpointString)
            metarMetric(label: "Altimeter", value: altimeterString)
        }
    }

    private func metarMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private var windString: String {
        guard let speed = metar.windSpeed else { return "Calm" }
        if speed == 0 { return "Calm" }
        let dir = metar.windDirection.map { "\($0)\u{00B0}" } ?? "VRB"
        let gust = metar.windGust.map { " G\($0) kt" } ?? ""
        return "\(dir) at \(speed) kt\(gust)"
    }

    private var visibilityString: String {
        guard let vis = metar.visibility else { return "N/A" }
        return vis >= 10 ? "10+ SM" : String(format: "%.1f SM", vis)
    }

    private var ceilingString: String {
        let ceilingLayers = metar.clouds.filter { $0.cover == .bkn || $0.cover == .ovc || $0.cover == .vv }
        if let lowest = ceilingLayers.min(by: { ($0.base ?? Int.max) < ($1.base ?? Int.max) }),
           let base = lowest.base {
            return "\(lowest.cover.rawValue) \(base) ft"
        }
        if metar.clouds.isEmpty || metar.clouds.allSatisfy({ $0.cover == .skc || $0.cover == .clr }) {
            return "Clear"
        }
        return metar.clouds.first?.description ?? "N/A"
    }

    private var temperatureString: String {
        guard let temp = metar.temperature else { return "N/A" }
        return String(format: "%.0f\u{00B0}C", temp)
    }

    private var dewpointString: String {
        guard let dewp = metar.dewpoint else { return "N/A" }
        return String(format: "%.0f\u{00B0}C", dewp)
    }

    private var altimeterString: String {
        guard let alt = metar.altimeter else { return "N/A" }
        return String(format: "%.2f inHg", alt)
    }

    // MARK: - Weather Section

    private func weatherSection(_ wx: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "cloud.rain.fill")
                .foregroundColor(.blue)
            Text("Weather: \(wx)")
                .font(.subheadline)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    // MARK: - Raw Text Section

    private func rawTextSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
        }
    }

    // MARK: - TAF Section

    private func tafSection(_ taf: TAF) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TAF")
                    .font(.headline)

                Spacer()

                if let period = taf.forecastPeriods.first {
                    let cat = period.derivedFlightCategory
                    Text(cat.displayName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(tafCategoryColor(cat))
                        .clipShape(Capsule())
                }
            }

            rawTextSection(title: "Raw TAF", text: taf.rawTAF)
        }
    }

    private func tafCategoryColor(_ category: FlightCategory) -> Color {
        switch category {
        case .vfr: return .green
        case .mvfr: return .blue
        case .ifr: return .red
        case .lifr: return .purple
        case .unknown: return .gray
        }
    }
}
