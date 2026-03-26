//
//  TAFView.swift
//  Buzz
//
//  Created by Xinyu Fang on 3/26/26.
//

import SwiftUI
import CoreLocation
import Auth

struct TAFView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var tafService = TAFService()
    @StateObject private var locationManager = WeatherLocationManager()

    private var locationObservationKey: String? {
        guard let location = locationManager.currentLocation else { return nil }
        return String(format: "%.6f,%.6f", location.latitude, location.longitude)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                TAFSectionView(tafService: tafService, userCoordinate: locationManager.currentLocation)
            }
            .padding()
        }
        .navigationTitle("TAF")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadTAFData()
        }
        .refreshable {
            tafService.clearCache()
            await loadTAFData()
        }
        .onChange(of: locationObservationKey) { _, newKey in
            if newKey != nil {
                Task {
                    await loadNearbyTAFs()
                }
            }
        }
    }

    private func loadTAFData() async {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestPermission()
        }

        if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startLocationUpdates()
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        await loadNearbyTAFs()
    }

    private func loadNearbyTAFs() async {
        guard let userProfile = authService.userProfile,
              userProfile.userType == .pilot else { return }

        var deviceLocation: CLLocationCoordinate2D? = locationManager.currentLocation
        if deviceLocation == nil {
            for _ in 0..<6 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                deviceLocation = locationManager.currentLocation
                if deviceLocation != nil {
                    break
                }
            }
        }

        guard let location = deviceLocation else {
            tafService.errorMessage = "Location unavailable. Enable location access to load nearby TAFs."
            print("Unable to get device location for TAF")
            return
        }

        do {
            _ = try await tafService.fetchTAFsNearLocation(coordinate: location)
        } catch {
            print("Error fetching nearby TAFs: \(error.localizedDescription)")
        }
    }
}

// MARK: - TAF Section View

struct TAFSectionView: View {
    @ObservedObject var tafService: TAFService
    let userCoordinate: CLLocationCoordinate2D?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "text.document.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                Text("Nearby TAF Forecasts")
                    .font(.headline)
                Spacer()
            }

            if tafService.nearbyTAFs.isEmpty {
                if tafService.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Text("Loading TAF data...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("No nearby TAF forecasts found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if let error = tafService.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                if tafService.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Refreshing TAF data...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }

                ForEach(tafService.nearbyTAFs) { taf in
                    TAFCard(taf: taf, userCoordinate: userCoordinate)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - TAF Card

struct TAFCard: View {
    let taf: TAF
    let userCoordinate: CLLocationCoordinate2D?

    @State private var showRawTAF = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with station ID and distance
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(taf.stationId)
                        .font(.headline)
                        .fontWeight(.bold)

                    if let name = taf.stationName {
                        Text(name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let coordinate = userCoordinate {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(taf.formattedDistance(from: coordinate))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("away")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Valid period
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Valid: \(formatUTCTime(taf.validFrom)) - \(formatUTCTime(taf.validTo))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("Issued: \(formatUTCTime(taf.issueTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Forecast periods
            if taf.forecastPeriods.isEmpty {
                Text("No forecast periods available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(taf.forecastPeriods) { period in
                    TAFForecastPeriodRow(period: period)
                }
            }

            // Raw TAF toggle
            HStack {
                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showRawTAF.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showRawTAF ? "Hide" : "Raw TAF")
                            .font(.caption)
                        Image(systemName: showRawTAF ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }

            // Raw TAF text (collapsible)
            if showRawTAF {
                Text(taf.rawTAF)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func formatUTCTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}

// MARK: - TAF Forecast Period Row

struct TAFForecastPeriodRow: View {
    let period: TAFForecastPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Time range and badges
            HStack(spacing: 6) {
                // Time range
                Text("\(formatUTCTime(period.timeFrom)) - \(formatUTCTime(period.timeTo))")
                    .font(.caption)
                    .fontWeight(.medium)

                // Change type badge
                if let changeType = period.changeType {
                    TAFChangeTypeBadge(
                        changeType: changeType,
                        probability: period.probability
                    )
                }

                Spacer()

                // Flight category badge
                FlightCategoryBadge(category: period.derivedFlightCategory)
            }

            // Metrics grid
            LazyVGrid(columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading)
            ], spacing: 8) {
                // Wind
                METARMetric(
                    icon: "wind",
                    label: "Wind",
                    value: formatWind()
                )

                // Visibility
                METARMetric(
                    icon: "eye.fill",
                    label: "Visibility",
                    value: formatVisibility()
                )

                // Ceiling
                METARMetric(
                    icon: "cloud.fill",
                    label: "Ceiling",
                    value: formatCeiling()
                )
            }

            // Weather phenomena
            if let wx = period.weatherPhenomena, !wx.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "cloud.rain.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text(wx)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(categoryBackgroundColor)
        .cornerRadius(8)
    }

    private var categoryBackgroundColor: Color {
        switch period.derivedFlightCategory {
        case .vfr: return Color.green.opacity(0.05)
        case .mvfr: return Color.blue.opacity(0.05)
        case .ifr: return Color.red.opacity(0.05)
        case .lifr: return Color.purple.opacity(0.05)
        case .unknown: return Color.clear
        }
    }

    private func formatWind() -> String {
        guard let speed = period.windSpeed else { return "Calm" }
        if speed == 0 { return "Calm" }

        var result = ""
        if let dir = period.windDirection {
            result = String(format: "%03d°", dir)
        } else {
            result = "VRB"
        }
        result += "/\(speed)"

        if let gust = period.windGust, gust > speed {
            result += "G\(gust)"
        }
        result += "kt"

        return result
    }

    private func formatVisibility() -> String {
        guard let vis = period.visibility else { return "N/A" }
        if vis >= 6 {
            return "6+ SM"
        } else if vis == floor(vis) {
            return String(format: "%.0f SM", vis)
        } else {
            return String(format: "%.1f SM", vis)
        }
    }

    private func formatCeiling() -> String {
        let ceilingLayers = period.clouds.filter {
            $0.cover == .bkn || $0.cover == .ovc || $0.cover == .vv
        }

        if let lowestCeiling = ceilingLayers.compactMap({ $0.base }).min() {
            if lowestCeiling >= 10000 {
                return "\(lowestCeiling/1000)k ft"
            }
            return "\(lowestCeiling) ft"
        }

        if let vv = period.verticalVisibility {
            return "VV \(vv) ft"
        }

        if period.clouds.isEmpty || period.clouds.allSatisfy({ $0.cover == .skc || $0.cover == .clr }) {
            return "Clear"
        }

        return "N/A"
    }

    private func formatUTCTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}

// MARK: - TAF Change Type Badge

struct TAFChangeTypeBadge: View {
    let changeType: TAFChangeType
    let probability: Int?

    var badgeColor: Color {
        switch changeType {
        case .fm: return .blue
        case .tempo: return .orange
        case .becmg: return .yellow
        case .prob: return .purple
        }
    }

    var body: some View {
        Text(badgeText)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor)
            .cornerRadius(4)
    }

    private var badgeText: String {
        if let prob = probability {
            return "PROB\(prob)"
        }
        return changeType.rawValue
    }
}
