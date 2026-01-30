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
    case wind = "Wind"
    case gusts = "Gusts"
    case temp = "Temp"
    case humidity = "Humidity"
    case precip = "Precip"
    case cloudCover = "Cloud"
    case visibility = "Vis"
    case kpIndex = "Kp"
    case status = "Fly?"

    var width: CGFloat {
        switch self {
        case .time: return 70
        case .wind: return 70
        case .gusts: return 60
        case .temp: return 50
        case .humidity: return 55
        case .precip: return 50
        case .cloudCover: return 50
        case .visibility: return 55
        case .kpIndex: return 45
        case .status: return 45
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
                        DaySectionView(dayGroup: dayGroup)
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
                Text(column.rawValue)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day header with sunrise/sunset
            DaySectionHeaderView(dayGroup: dayGroup)

            // Hourly rows
            ForEach(Array(dayGroup.hours.enumerated()), id: \.element.id) { index, hour in
                ForecastTableRow(hour: hour, isAlternate: index % 2 == 1)

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

// MARK: - Hourly Data Row

struct ForecastTableRow: View {
    let hour: SafeFlyHour
    let isAlternate: Bool

    private var rowBackgroundColor: Color {
        switch hour.safetyStatus {
        case .good: return Color.green.opacity(0.12)
        case .marginal: return Color.yellow.opacity(0.18)
        case .poor: return Color.red.opacity(0.12)
        case .unknown: return Color.gray.opacity(0.08)
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: hour.time)
    }

    private var isDaytime: Bool {
        let hourComponent = Calendar.current.component(.hour, from: hour.time)
        return hourComponent >= 6 && hourComponent < 20
    }

    var body: some View {
        HStack(spacing: 0) {
            // Time column with day/night icon
            HStack(spacing: 2) {
                Text(timeString)
                    .font(.caption)
                    .monospacedDigit()
                Image(systemName: isDaytime ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 8))
                    .foregroundColor(isDaytime ? .orange : .indigo)
            }
            .frame(width: ForecastTableColumn.time.width)

            // Wind column
            WindCell(speed: hour.forecast.windSpeed, direction: hour.forecast.windDirection)
                .frame(width: ForecastTableColumn.wind.width)

            // Gusts column
            Text(hour.forecast.windGust.map { "\(Int($0))" } ?? "-")
                .font(.caption)
                .monospacedDigit()
                .frame(width: ForecastTableColumn.gusts.width)

            // Temperature column
            Text("\(Int(hour.forecast.temperature))°")
                .font(.caption)
                .monospacedDigit()
                .frame(width: ForecastTableColumn.temp.width)

            // Humidity column
            Text(hour.forecast.humidity.map { "\($0)%" } ?? "-")
                .font(.caption)
                .monospacedDigit()
                .frame(width: ForecastTableColumn.humidity.width)

            // Precipitation column
            Text(hour.forecast.precipitation > 0 ? "\(hour.forecast.precipitation)%" : "-")
                .font(.caption)
                .monospacedDigit()
                .foregroundColor(hour.forecast.precipitation > 20 ? .blue : .primary)
                .frame(width: ForecastTableColumn.precip.width)

            // Cloud Cover column
            Text(hour.forecast.cloudCover.map { "\($0)%" } ?? "-")
                .font(.caption)
                .monospacedDigit()
                .frame(width: ForecastTableColumn.cloudCover.width)

            // Visibility column
            Text(hour.visibility.map { String(format: "%.0f", $0) } ?? "-")
                .font(.caption)
                .monospacedDigit()
                .frame(width: ForecastTableColumn.visibility.width)

            // KP Index column
            Text(hour.kpIndex.map { String(format: "%.1f", $0) } ?? "-")
                .font(.caption)
                .monospacedDigit()
                .frame(width: ForecastTableColumn.kpIndex.width)

            // Status column
            SafetyStatusCell(status: hour.safetyStatus)
                .frame(width: ForecastTableColumn.status.width)
        }
        .padding(.vertical, 8)
        .background(rowBackgroundColor)
    }
}

// MARK: - Wind Cell

struct WindCell: View {
    let speed: Double
    let direction: String

    private var directionArrow: String {
        // Wind direction indicates where wind is coming FROM
        // Arrow should point in the direction wind is blowing TO
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
