//
//  HourlyForecastTableView.swift
//  Buzz
//
//  Created by Claude on 1/30/26.
//

import SwiftUI

// MARK: - Table Column Definition

enum ForecastTableColumn: String, CaseIterable {
    case time = "Time"
    case status = "Fly?"
    case wind = "Wind"
    case gusts = "Gusts"
    case temp = "Temp"
    case humidity = "Humidity"
    case precip = "Precip"
    case cloudCover = "Cloud"
    case visibility = "Vis"
    case kpIndex = "Kp"

    var width: CGFloat {
        switch self {
        case .time: return 70
        case .status: return 45
        case .wind: return 70
        case .gusts: return 70
        case .temp: return 50
        case .humidity: return 55
        case .precip: return 50
        case .cloudCover: return 50
        case .visibility: return 55
        case .kpIndex: return 45
        }
    }
    
    /// Column header with units where applicable
    var headerWithUnit: String {
        switch self {
        case .time: return "Time"
        case .status: return "Fly?"
        case .wind: return "Wind\n(mph)"
        case .gusts: return "Gusts\n(mph)"
        case .temp: return "Temp\n(°F)"
        case .humidity: return "Hum\n(%)"
        case .precip: return "Precip\n(%)"
        case .cloudCover: return "Cloud\n(%)"
        case .visibility: return "Vis\n(mi)"
        case .kpIndex: return "Kp"
        }
    }
}

// MARK: - Main Table View

struct HourlyForecastTableView: View {
    let dayGroups: [SafeFlyDayGroup]
    let thresholds: FlyingThresholds

    private var totalTableWidth: CGFloat {
        ForecastTableColumn.allCases.reduce(0) { $0 + $1.width }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detailed Forecast")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    // Table Header
                    ForecastTableHeaderRow()

                    // Day sections with hours
                    ForEach(dayGroups) { dayGroup in
                        DaySectionView(dayGroup: dayGroup, thresholds: thresholds)
                    }
                }
                .frame(minWidth: totalTableWidth)
            }
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Table Header Row

struct ForecastTableHeaderRow: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ForecastTableColumn.allCases, id: \.self) { column in
                Text(column.headerWithUnit)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: column.width)
                    .padding(.vertical, 8)
            }
        }
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - Day Section View

struct DaySectionView: View {
    let dayGroup: SafeFlyDayGroup
    let thresholds: FlyingThresholds

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day header with sunrise/sunset
            DaySectionHeaderView(dayGroup: dayGroup)

            // Hourly rows
            ForEach(Array(dayGroup.hours.enumerated()), id: \.element.id) { index, hour in
                ForecastTableRow(hour: hour, thresholds: thresholds, isAlternate: index % 2 == 1)

                if index < dayGroup.hours.count - 1 {
                    Divider()
                        .padding(.horizontal, 4)
                }
            }
        }
    }
}

// MARK: - Day Section Header

struct DaySectionHeaderView: View {
    let dayGroup: SafeFlyDayGroup

    private func timeString(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(dayGroup.shortDateString)
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            // Sunrise
            HStack(spacing: 3) {
                Image(systemName: "sunrise.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
                Text(timeString(dayGroup.sunrise))
                    .font(.caption2)
                    .monospacedDigit()
            }

            // Solar noon
            HStack(spacing: 3) {
                Image(systemName: "sun.max.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                Text(timeString(dayGroup.solarNoon))
                    .font(.caption2)
                    .monospacedDigit()
            }

            // Sunset
            HStack(spacing: 3) {
                Image(systemName: "sunset.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
                Text(timeString(dayGroup.sunset))
                    .font(.caption2)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
    }
}

// MARK: - Cell Status for Threshold Comparison

enum CellThresholdStatus {
    case safe       // Within threshold - green
    case caution    // Close to threshold (80-100%) - orange
    case exceeded   // Exceeds threshold - red
    case neutral    // No threshold applies or no data
    
    var backgroundColor: Color {
        switch self {
        case .safe: return Color.green.opacity(0.15)
        case .caution: return Color.orange.opacity(0.20)
        case .exceeded: return Color.red.opacity(0.20)
        case .neutral: return Color.clear
        }
    }
}

// MARK: - Hourly Data Row

struct ForecastTableRow: View {
    let hour: SafeFlyHour
    let thresholds: FlyingThresholds
    let isAlternate: Bool

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: hour.time)
    }

    private var isDaytime: Bool {
        let hourComponent = Calendar.current.component(.hour, from: hour.time)
        return hourComponent >= 6 && hourComponent < 20
    }
    
    // MARK: - Threshold Status Calculations
    
    /// Wind speed: exceeded if > max, caution if > 80% of max
    private var windStatus: CellThresholdStatus {
        let value = hour.forecast.windSpeed
        let max = thresholds.maxWindSpeed
        if value > max { return .exceeded }
        if value > max * 0.8 { return .caution }
        return .safe
    }
    
    /// Wind gusts: exceeded if > max, caution if > 80% of max
    private var gustStatus: CellThresholdStatus {
        guard let gust = hour.forecast.windGust else { return .neutral }
        let max = thresholds.maxWindGust
        if gust > max { return .exceeded }
        if gust > max * 0.8 { return .caution }
        return .safe
    }
    
    /// Temperature: exceeded if < min or > max, caution if within 5°F of limits
    private var tempStatus: CellThresholdStatus {
        let temp = hour.forecast.temperature
        let min = thresholds.minTemperature
        let max = thresholds.maxTemperature
        if temp < min || temp > max { return .exceeded }
        if temp < min + 5 || temp > max - 5 { return .caution }
        return .safe
    }
    
    /// Precipitation: exceeded if > max, caution if > 80% of max
    private var precipStatus: CellThresholdStatus {
        let value = hour.forecast.precipitation
        let max = thresholds.maxPrecipitation
        if value > max { return .exceeded }
        if value > Int(Double(max) * 0.8) { return .caution }
        return .safe
    }
    
    /// Visibility: exceeded if < min, caution if < 150% of min
    private var visibilityStatus: CellThresholdStatus {
        guard let vis = hour.visibility else { return .neutral }
        let min = thresholds.minVisibility
        if vis < min { return .exceeded }
        if vis < min * 1.5 { return .caution }
        return .safe
    }
    
    /// KP Index: exceeded if > max, caution if > 80% of max
    private var kpStatus: CellThresholdStatus {
        guard let kp = hour.kpIndex else { return .neutral }
        let max = thresholds.maxKPIndex
        if kp > max { return .exceeded }
        if kp > max * 0.8 { return .caution }
        return .safe
    }
    
    /// Cloud cover: exceeded if > max, caution if > 80% of max
    private var cloudStatus: CellThresholdStatus {
        guard let cloud = hour.forecast.cloudCover else { return .neutral }
        let max = thresholds.maxCloudCover
        if cloud > max { return .exceeded }
        if cloud > Int(Double(max) * 0.8) { return .caution }
        return .safe
    }

    var body: some View {
        HStack(spacing: 0) {
            // Time column with day/night icon (no threshold)
            HStack(spacing: 2) {
                Text(timeString)
                    .font(.caption)
                    .monospacedDigit()
                Image(systemName: isDaytime ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 8))
                    .foregroundColor(isDaytime ? .orange : .indigo)
            }
            .frame(width: ForecastTableColumn.time.width, height: 32)

            // Status column
            SafetyStatusCell(status: hour.safetyStatus)
                .frame(width: ForecastTableColumn.status.width, height: 32)

            // Wind column with threshold background
            WindCell(speed: hour.forecast.windSpeed, direction: hour.forecast.windDirection)
                .frame(width: ForecastTableColumn.wind.width, height: 32)
                .background(windStatus.backgroundColor)

            // Gusts column with threshold background
            GustCell(gust: hour.forecast.windGust, direction: hour.forecast.windDirection)
                .frame(width: ForecastTableColumn.gusts.width, height: 32)
                .background(gustStatus.backgroundColor)

            // Temperature column with threshold background
            Text("\(Int(hour.forecast.temperature))°")
                .font(.caption)
                .monospacedDigit()
                .frame(width: ForecastTableColumn.temp.width, height: 32)
                .background(tempStatus.backgroundColor)

            // Humidity column (no threshold in settings, so neutral)
            Text(hour.forecast.humidity.map { "\($0)" } ?? "-")
                .font(.caption)
                .monospacedDigit()
                .frame(width: ForecastTableColumn.humidity.width, height: 32)

            // Precipitation column with threshold background
            Text(hour.forecast.precipitation > 0 ? "\(hour.forecast.precipitation)" : "-")
                .font(.caption)
                .monospacedDigit()
                .frame(width: ForecastTableColumn.precip.width, height: 32)
                .background(precipStatus.backgroundColor)

            // Cloud Cover column with threshold background
            Text(hour.forecast.cloudCover.map { "\($0)" } ?? "-")
                .font(.caption)
                .monospacedDigit()
                .frame(width: ForecastTableColumn.cloudCover.width, height: 32)
                .background(cloudStatus.backgroundColor)

            // Visibility column with threshold background
            Text(hour.visibility.map { String(format: "%.0f", $0) } ?? "-")
                .font(.caption)
                .monospacedDigit()
                .frame(width: ForecastTableColumn.visibility.width, height: 32)
                .background(visibilityStatus.backgroundColor)

            // KP Index column with threshold background
            Text(hour.kpIndex.map { String(format: "%.1f", $0) } ?? "-")
                .font(.caption)
                .monospacedDigit()
                .frame(width: ForecastTableColumn.kpIndex.width, height: 32)
                .background(kpStatus.backgroundColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Wind Cell

struct WindCell: View {
    let speed: Double
    let direction: String

    private var directionArrow: String {
        getDirectionArrow(for: direction)
    }

    var body: some View {
        HStack(spacing: 2) {
            Text("\(Int(speed))")
                .font(.caption)
                .monospacedDigit()
            Image(systemName: directionArrow)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Gust Cell

struct GustCell: View {
    let gust: Double?
    let direction: String

    private var directionArrow: String {
        getDirectionArrow(for: direction)
    }

    var body: some View {
        if let gustValue = gust {
            HStack(spacing: 2) {
                Text("\(Int(gustValue))")
                    .font(.caption)
                    .monospacedDigit()
                Image(systemName: directionArrow)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        } else {
            Text("-")
                .font(.caption)
                .monospacedDigit()
        }
    }
}

// MARK: - Direction Arrow Helper

/// Get SF Symbol arrow name for wind direction
/// Wind direction indicates where wind is coming FROM
/// Arrow should point in the direction wind is blowing TO
private func getDirectionArrow(for direction: String) -> String {
    switch direction.uppercased() {
    case "N": return "arrow.down"
    case "S": return "arrow.up"
    case "E": return "arrow.left"
    case "W": return "arrow.right"
    case "NE": return "arrow.down.left"
    case "NW": return "arrow.down.right"
    case "SE": return "arrow.up.left"
    case "SW": return "arrow.up.right"
    case "NNE", "ENE": return "arrow.down.left"
    case "NNW", "WNW": return "arrow.down.right"
    case "SSE", "ESE": return "arrow.up.left"
    case "SSW", "WSW": return "arrow.up.right"
    default: return "arrow.down"
    }
}

// MARK: - Safety Status Cell

struct SafetyStatusCell: View {
    let status: FlyingSafetyStatus

    private var statusColor: Color {
        switch status {
        case .good: return .green
        case .marginal: return .orange
        case .poor: return .red
        case .unknown: return .gray
        }
    }

    private var statusText: String {
        switch status {
        case .good: return "yes"
        case .marginal: return "?"
        case .poor: return "no"
        case .unknown: return "-"
        }
    }

    var body: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(statusColor)
    }
}

// MARK: - Preview

#Preview {
    let sampleHour = SafeFlyHour(
        time: Date(),
        forecast: HourlyForecast(
            time: Date(),
            temperature: 65,
            windSpeed: 12,
            windGust: 18,
            windDirection: "NW",
            windDirectionDegrees: 315,
            precipitation: 10,
            cloudCover: 45,
            humidity: 55,
            shortForecast: "Partly Cloudy",
            visibility: 10
        ),
        kpIndex: 2.3,
        visibility: 10,
        safetyStatus: .good,
        violations: []
    )

    let sampleDayGroup = SafeFlyDayGroup(
        date: Date(),
        sunrise: Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: Date()),
        sunset: Calendar.current.date(bySettingHour: 17, minute: 45, second: 0, of: Date()),
        solarNoon: Calendar.current.date(bySettingHour: 12, minute: 8, second: 0, of: Date()),
        hours: [sampleHour]
    )

    return ScrollView {
        HourlyForecastTableView(
            dayGroups: [sampleDayGroup],
            thresholds: .default
        )
        .padding()
    }
}
