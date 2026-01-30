//
//  SafeFlySettingsView.swift
//  Buzz
//
//  Created by Claude on 1/30/26.
//

import SwiftUI

struct SafeFlySettingsView: View {
    @ObservedObject var safeFlyService: SafeFlyService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Wind Limits")) {
                    ThresholdRow(
                        label: "Max Wind Speed",
                        value: $safeFlyService.thresholds.maxWindSpeed,
                        unit: "mph",
                        range: 10...50
                    )
                    ThresholdRow(
                        label: "Max Wind Gusts",
                        value: $safeFlyService.thresholds.maxWindGust,
                        unit: "mph",
                        range: 15...60
                    )
                }

                Section(header: Text("Visibility")) {
                    ThresholdRowDecimal(
                        label: "Min Visibility",
                        value: $safeFlyService.thresholds.minVisibility,
                        unit: "mi",
                        range: 0.5...10,
                        step: 0.5
                    )
                }

                Section(header: Text("Precipitation")) {
                    ThresholdRowInt(
                        label: "Max Precipitation",
                        value: $safeFlyService.thresholds.maxPrecipitation,
                        unit: "%",
                        range: 0...100,
                        step: 5
                    )
                }

                Section(header: Text("Temperature")) {
                    ThresholdRow(
                        label: "Min Temperature",
                        value: $safeFlyService.thresholds.minTemperature,
                        unit: "°F",
                        range: 0...50
                    )
                    ThresholdRow(
                        label: "Max Temperature",
                        value: $safeFlyService.thresholds.maxTemperature,
                        unit: "°F",
                        range: 80...120
                    )
                }

                Section(header: Text("GPS / Solar Activity"), footer: Text("KP Index > 5 may affect GPS accuracy during geomagnetic storms.")) {
                    ThresholdRowDecimal(
                        label: "Max KP Index",
                        value: $safeFlyService.thresholds.maxKPIndex,
                        unit: "",
                        range: 1...9,
                        step: 0.5
                    )
                }

                Section {
                    Button(role: .destructive) {
                        safeFlyService.resetThresholds()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset to Defaults")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Flying Thresholds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        safeFlyService.saveThresholds()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Threshold Row (Double displayed as Int)

struct ThresholdRow: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(Int(value)) \(unit)")
                .foregroundColor(.secondary)
                .monospacedDigit()
            Stepper("", value: $value, in: range, step: 1.0)
                .labelsHidden()
        }
    }
}

// MARK: - Threshold Row (Decimal)

struct ThresholdRowDecimal: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            if unit.isEmpty {
                Text(String(format: "%.1f", value))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            } else {
                Text("\(String(format: "%.1f", value)) \(unit)")
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
    }
}

// MARK: - Threshold Row (Int)

struct ThresholdRowInt: View {
    let label: String
    @Binding var value: Int
    let unit: String
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)\(unit)")
                .foregroundColor(.secondary)
                .monospacedDigit()
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
    }
}

#Preview {
    SafeFlySettingsView(safeFlyService: SafeFlyService())
}
