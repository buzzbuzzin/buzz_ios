//
//  LocationQuerySheet.swift
//  Buzz
//
//  Bottom card for long-press location query results on VFR charts
//

import SwiftUI
import CoreLocation

// MARK: - Location Query Result

struct LocationQueryResult: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let formattedCoordinate: String
    let airspaceClass: AirspaceClass
    let laancCeiling: Int?
    let hasLAANCCoverage: Bool
    let authorizationStatus: LAANCAuthorizationStatus
    let nearestMETAR: METAR?
    let distanceToNearestMETAR: String?
    let nearestPIREP: PIREP?
    let distanceToNearestPIREP: String?

    static func formatDMS(_ coordinate: CLLocationCoordinate2D) -> String {
        let latDeg = Int(abs(coordinate.latitude))
        let latMin = Int((abs(coordinate.latitude) - Double(latDeg)) * 60)
        let latSec = ((abs(coordinate.latitude) - Double(latDeg)) * 60 - Double(latMin)) * 60
        let latDir = coordinate.latitude >= 0 ? "N" : "S"

        let lonDeg = Int(abs(coordinate.longitude))
        let lonMin = Int((abs(coordinate.longitude) - Double(lonDeg)) * 60)
        let lonSec = ((abs(coordinate.longitude) - Double(lonDeg)) * 60 - Double(lonMin)) * 60
        let lonDir = coordinate.longitude >= 0 ? "E" : "W"

        return String(format: "%d\u{00B0}%d'%04.1f\"%@  %d\u{00B0}%d'%04.1f\"%@",
                       latDeg, latMin, latSec, latDir,
                       lonDeg, lonMin, lonSec, lonDir)
    }
}

// MARK: - Location Query Card

struct LocationQueryCard: View {
    let result: LocationQueryResult
    let isLoading: Bool
    let errorMessage: String?
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .font(.title3)
                    .foregroundColor(.orange)

                Text("Location Info")
                    .font(.headline)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }

            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Querying...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                // Coordinates
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(result.formattedCoordinate)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Info grid
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        infoPill(
                            label: "Airspace",
                            value: airspaceDisplayText,
                            color: airspaceColor
                        )

                        infoPill(
                            label: "LAANC",
                            value: laancDisplayText,
                            color: laancColor
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        infoPill(
                            label: "Airspace",
                            value: airspaceDisplayText,
                            color: airspaceColor
                        )

                        infoPill(
                            label: "LAANC",
                            value: laancDisplayText,
                            color: laancColor
                        )
                    }
                }

                // Nearest METAR
                if let metar = result.nearestMETAR {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(metarColor(metar.flightCategory))
                            .frame(width: 10, height: 10)

                        Text(metar.stationId)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(metar.flightCategory.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let dist = result.distanceToNearestMETAR {
                            Text("(\(dist))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if let pirep = result.nearestPIREP {
                    HStack(spacing: 8) {
                        Image(systemName: pirep.dominantHazard.systemImage)
                            .font(.caption)
                            .foregroundColor(Color(ChartsWeatherOverlayHelper.pirepTintColor(for: pirep.dominantHazard)))

                        Text("Nearest PIREP")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(pirep.hazardSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        if let dist = result.distanceToNearestPIREP {
                            Text("(\(dist))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
    }

    // MARK: - Info Pill

    private func infoPill(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Computed Display

    private var airspaceDisplayText: String {
        switch result.airspaceClass {
        case .classB: return "Class B"
        case .classC: return "Class C"
        case .classD: return "Class D"
        case .classE: return "Class E"
        case .classG: return "Class G"
        case .unknown: return "Unknown"
        }
    }

    private var airspaceColor: Color {
        switch result.airspaceClass {
        case .classB: return .blue
        case .classC: return .purple
        case .classD: return .blue
        case .classE: return .purple
        case .classG: return .green
        case .unknown: return .gray
        }
    }

    private var laancDisplayText: String {
        switch result.authorizationStatus {
        case .autoApproved:
            if let ceiling = result.laancCeiling {
                return "Auto \(ceiling) ft"
            }
            return "Auto-Approved"
        case .manualReviewRequired: return "Manual Review"
        case .noLAANCCoverage: return "No Coverage"
        case .notPermitted: return "Not Permitted"
        case .notApplicable: return "N/A"
        case .pending: return "Pending"
        }
    }

    private var laancColor: Color {
        switch result.authorizationStatus {
        case .autoApproved: return .green
        case .manualReviewRequired: return .orange
        case .noLAANCCoverage: return .red
        case .notPermitted: return .red
        case .notApplicable: return .gray
        case .pending: return .gray
        }
    }

    private func metarColor(_ category: FlightCategory) -> Color {
        switch category {
        case .vfr: return .green
        case .mvfr: return .blue
        case .ifr: return .red
        case .lifr: return .purple
        case .unknown: return .gray
        }
    }
}
