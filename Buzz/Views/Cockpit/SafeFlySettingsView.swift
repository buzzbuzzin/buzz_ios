//
//  SafeFlySettingsView.swift
//  Buzz
//
//  Created by Claude on 1/30/26.
//

import SwiftUI

struct SafeFlySettingsView: View {
    @ObservedObject var safeFlyService: SafeFlyService
    let measurementSystem: MeasurementSystem
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Wind Limits")) {
                    ThresholdRow(
                        label: "Max Wind Speed",
                        value: windBinding(for: \.maxWindSpeed),
                        unit: measurementSystem.windSpeedUnit,
                        range: windRange(10...50)
                    )
                    ThresholdRow(
                        label: "Max Wind Gusts",
                        value: windBinding(for: \.maxWindGust),
                        unit: measurementSystem.windSpeedUnit,
                        range: windRange(15...60)
                    )
                }

                Section(header: Text("Visibility")) {
                    ThresholdRowDecimal(
                        label: "Min Visibility",
                        value: distanceBinding(for: \.minVisibility),
                        unit: measurementSystem.visibilityUnit,
                        range: distanceRange(0.5...10),
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
                        value: temperatureBinding(for: \.minTemperature),
                        unit: measurementSystem.temperatureUnit,
                        range: temperatureRange(0...50)
                    )
                    ThresholdRow(
                        label: "Max Temperature",
                        value: temperatureBinding(for: \.maxTemperature),
                        unit: measurementSystem.temperatureUnit,
                        range: temperatureRange(80...120)
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

    private func windBinding(for keyPath: WritableKeyPath<FlyingThresholds, Double>) -> Binding<Double> {
        Binding(
            get: {
                MeasurementFormatter.windSpeedValue(
                    fromMilesPerHour: safeFlyService.thresholds[keyPath: keyPath],
                    system: measurementSystem
                )
            },
            set: { newValue in
                safeFlyService.thresholds[keyPath: keyPath] = MeasurementFormatter.milesPerHourValue(
                    fromWindSpeed: newValue,
                    system: measurementSystem
                )
            }
        )
    }

    private func temperatureBinding(for keyPath: WritableKeyPath<FlyingThresholds, Double>) -> Binding<Double> {
        Binding(
            get: {
                MeasurementFormatter.temperatureValue(
                    fromFahrenheit: safeFlyService.thresholds[keyPath: keyPath],
                    system: measurementSystem
                )
            },
            set: { newValue in
                safeFlyService.thresholds[keyPath: keyPath] = MeasurementFormatter.fahrenheitValue(
                    fromTemperature: newValue,
                    system: measurementSystem
                )
            }
        )
    }

    private func distanceBinding(for keyPath: WritableKeyPath<FlyingThresholds, Double>) -> Binding<Double> {
        Binding(
            get: {
                MeasurementFormatter.distanceValue(
                    fromMiles: safeFlyService.thresholds[keyPath: keyPath],
                    system: measurementSystem
                )
            },
            set: { newValue in
                safeFlyService.thresholds[keyPath: keyPath] = MeasurementFormatter.milesValue(
                    fromDistance: newValue,
                    system: measurementSystem
                )
            }
        )
    }

    private func windRange(_ imperialRange: ClosedRange<Double>) -> ClosedRange<Double> {
        let lower = MeasurementFormatter.windSpeedValue(fromMilesPerHour: imperialRange.lowerBound, system: measurementSystem)
        let upper = MeasurementFormatter.windSpeedValue(fromMilesPerHour: imperialRange.upperBound, system: measurementSystem)
        return lower...upper
    }

    private func temperatureRange(_ imperialRange: ClosedRange<Double>) -> ClosedRange<Double> {
        let lower = MeasurementFormatter.temperatureValue(fromFahrenheit: imperialRange.lowerBound, system: measurementSystem)
        let upper = MeasurementFormatter.temperatureValue(fromFahrenheit: imperialRange.upperBound, system: measurementSystem)
        return lower...upper
    }

    private func distanceRange(_ imperialRange: ClosedRange<Double>) -> ClosedRange<Double> {
        let lower = MeasurementFormatter.distanceValue(fromMiles: imperialRange.lowerBound, system: measurementSystem)
        let upper = MeasurementFormatter.distanceValue(fromMiles: imperialRange.upperBound, system: measurementSystem)
        return lower...upper
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
    SafeFlySettingsView(safeFlyService: SafeFlyService(), measurementSystem: .imperial)
}
