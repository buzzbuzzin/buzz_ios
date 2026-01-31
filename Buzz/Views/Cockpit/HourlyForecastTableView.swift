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
    case precip = "Precip"
    case visibility = "Vis"
    case kpIndex = "Kp"

    /// Relative weight for proportional column sizing
    var weight: CGFloat {
        switch self {
        case .time: return 1.4      // Needs space for time + icon
        case .status: return 0.9    // Yes/No
        case .wind: return 1.1      // Number + arrow
        case .gusts: return 1.1     // Number + arrow
        case .temp: return 0.9      // Temperature
        case .precip: return 0.9    // Percentage
        case .visibility: return 0.9 // Miles
        case .kpIndex: return 0.8   // KP value
        }
    }

    /// Calculate actual width based on available space
    func width(for totalWidth: CGFloat) -> CGFloat {
        let totalWeight = ForecastTableColumn.allCases.reduce(0) { $0 + $1.weight }
        return (totalWidth / totalWeight) * weight
    }

    /// Column header with units where applicable
    var headerWithUnit: String {
        switch self {
        case .time: return "Time"
        case .status: return "Fly?"
        case .wind: return "Wind\n(mph)"
        case .gusts: return "Gusts\n(mph)"
        case .temp: return "Temp\n(°F)"
        case .precip: return "Precip\n(%)"
        case .visibility: return "Vis\n(mi)"
        case .kpIndex: return "Kp"
        }
    }
}

// MARK: - Main Table View

struct HourlyForecastTableView: View {
    let dayGroups: [SafeFlyDayGroup]
    let thresholds: FlyingThresholds

    @State private var showLegend = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Detailed Forecast")
                    .font(.headline)

                Button {
                    showLegend = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .sheet(isPresented: $showLegend) {
                    ThresholdLegendView(thresholds: thresholds)
                }

                Spacer()
            }
            .padding(.horizontal)

            // Table content without internal scroll - uses page scroll
            GeometryReader { geometry in
                let tableWidth = geometry.size.width
                VStack(alignment: .leading, spacing: 0) {
                    // Table Header
                    ForecastTableHeaderRow(tableWidth: tableWidth)

                    // Day sections with hours
                    ForEach(dayGroups) { dayGroup in
                        DaySectionView(dayGroup: dayGroup, thresholds: thresholds, tableWidth: tableWidth)
                    }
                }
            }
            // Calculate height based on content
            .frame(height: calculateTableHeight())
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    /// Calculate the total height needed for the table content
    private func calculateTableHeight() -> CGFloat {
        let headerHeight: CGFloat = 44 // Header row height
        let daySectionHeaderHeight: CGFloat = 40 // Day header height
        let rowHeight: CGFloat = 40 // Each hour row height (32 + 8 padding)

        var totalHeight = headerHeight

        for dayGroup in dayGroups {
            totalHeight += daySectionHeaderHeight
            totalHeight += CGFloat(dayGroup.hours.count) * rowHeight
        }

        return max(totalHeight, 300) // Minimum height
    }
}

// MARK: - Table Header Row

struct ForecastTableHeaderRow: View {
    let tableWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ForecastTableColumn.allCases, id: \.self) { column in
                Text(column.headerWithUnit)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: column.width(for: tableWidth))
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
    let tableWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day header with sunrise/sunset
            DaySectionHeaderView(dayGroup: dayGroup)

            // Hourly rows
            ForEach(Array(dayGroup.hours.enumerated()), id: \.element.id) { index, hour in
                ForecastTableRow(
                    hour: hour,
                    thresholds: thresholds,
                    isAlternate: index % 2 == 1,
                    tableWidth: tableWidth,
                    sunrise: dayGroup.sunrise,
                    sunset: dayGroup.sunset
                )

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
    let tableWidth: CGFloat
    let sunrise: Date?
    let sunset: Date?

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: hour.time)
    }

    /// Determines if the hour is during daytime based on actual sunrise/sunset times
    private var isDaytime: Bool {
        // Use actual sunrise/sunset if available
        if let sunrise = sunrise, let sunset = sunset {
            return hour.time >= sunrise && hour.time < sunset
        }
        // Fallback to default 6:00-20:00 if sun times unavailable
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
    
    /// Returns true if ALL thresholds are within safe limits (no exceeded status)
    var isSafeToFly: Bool {
        let statuses = [windStatus, gustStatus, tempStatus, precipStatus, visibilityStatus, kpStatus, cloudStatus]
        return !statuses.contains(.exceeded)
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
            .frame(width: ForecastTableColumn.time.width(for: tableWidth), height: 32)

            // Status column - Yes if all within threshold, No if any exceeded
            SafetyStatusCell(isSafeToFly: isSafeToFly)
                .frame(width: ForecastTableColumn.status.width(for: tableWidth), height: 32)

            // Wind column with threshold background
            WindCell(speed: hour.forecast.windSpeed, direction: hour.forecast.windDirection)
                .frame(width: ForecastTableColumn.wind.width(for: tableWidth), height: 32)
                .background(windStatus.backgroundColor)

            // Gusts column with threshold background
            GustCell(gust: hour.forecast.windGust, direction: hour.forecast.windDirection)
                .frame(width: ForecastTableColumn.gusts.width(for: tableWidth), height: 32)
                .background(gustStatus.backgroundColor)

            // Temperature column with threshold background
            Text("\(Int(hour.forecast.temperature))°")
                .font(.caption)
                .monospacedDigit()
                .frame(width: ForecastTableColumn.temp.width(for: tableWidth), height: 32)
                .background(tempStatus.backgroundColor)

            // Precipitation column with threshold background
            Text(hour.forecast.precipitation > 0 ? "\(hour.forecast.precipitation)" : "-")
                .font(.caption)
                .monospacedDigit()
                .frame(width: ForecastTableColumn.precip.width(for: tableWidth), height: 32)
                .background(precipStatus.backgroundColor)

            // Visibility column with threshold background
            Text(hour.visibility.map { String(format: "%.0f", $0) } ?? "-")
                .font(.caption)
                .monospacedDigit()
                .frame(width: ForecastTableColumn.visibility.width(for: tableWidth), height: 32)
                .background(visibilityStatus.backgroundColor)

            // KP Index column with threshold background
            Text(hour.kpIndex.map { String(format: "%.1f", $0) } ?? "-")
                .font(.caption)
                .monospacedDigit()
                .frame(width: ForecastTableColumn.kpIndex.width(for: tableWidth), height: 32)
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
    let isSafeToFly: Bool

    var body: some View {
        Text(isSafeToFly ? "Yes" : "No")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(isSafeToFly ? .green : .red)
    }
}

// MARK: - Threshold Legend View

struct ThresholdLegendView: View {
    let thresholds: FlyingThresholds
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Color Legend Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color Legend")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            ColorLegendItem(color: .green.opacity(0.15), label: "Safe", description: "Within threshold")
                            ColorLegendItem(color: .orange.opacity(0.20), label: "Caution", description: "Approaching threshold")
                            ColorLegendItem(color: .red.opacity(0.20), label: "Exceeded", description: "Above threshold")
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Fly? Column Explanation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fly? Column")
                            .font(.headline)
                        
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Text("Yes")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                Text("- All values within thresholds")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Text("No")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                                Text("- One or more values exceed thresholds")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Threshold Details Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Thresholds")
                            .font(.headline)
                        
                        ThresholdDetailRow(
                            column: "Wind",
                            threshold: "\(Int(thresholds.maxWindSpeed)) mph max",
                            cautionRange: ">\(Int(thresholds.maxWindSpeed * 0.8)) mph"
                        )
                        
                        ThresholdDetailRow(
                            column: "Gusts",
                            threshold: "\(Int(thresholds.maxWindGust)) mph max",
                            cautionRange: ">\(Int(thresholds.maxWindGust * 0.8)) mph"
                        )
                        
                        ThresholdDetailRow(
                            column: "Temp",
                            threshold: "\(Int(thresholds.minTemperature))°F - \(Int(thresholds.maxTemperature))°F",
                            cautionRange: "Within 5°F of limits"
                        )
                        
                        ThresholdDetailRow(
                            column: "Precip",
                            threshold: "\(thresholds.maxPrecipitation)% max",
                            cautionRange: ">\(Int(Double(thresholds.maxPrecipitation) * 0.8))%"
                        )

                        ThresholdDetailRow(
                            column: "Visibility",
                            threshold: "\(String(format: "%.1f", thresholds.minVisibility)) mi min",
                            cautionRange: "<\(String(format: "%.1f", thresholds.minVisibility * 1.5)) mi"
                        )
                        
                        ThresholdDetailRow(
                            column: "KP Index",
                            threshold: "\(String(format: "%.1f", thresholds.maxKPIndex)) max",
                            cautionRange: ">\(String(format: "%.1f", thresholds.maxKPIndex * 0.8))"
                        )
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Forecast Legend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Color Legend Item

struct ColorLegendItem: View {
    let color: Color
    let label: String
    let description: String
    
    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .frame(width: 50, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Threshold Detail Row

struct ThresholdDetailRow: View {
    let column: String
    let threshold: String
    let cautionRange: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(column)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Threshold: \(threshold)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Caution: \(cautionRange)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
        
        Divider()
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
