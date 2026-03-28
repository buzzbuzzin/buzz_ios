//
//  PIREP.swift
//  Buzz
//
//  Created for pilot weather reports shown on VFR charts.
//

import Foundation
import CoreLocation

struct PIREP: Identifiable {
    let id: String
    let stationId: String?
    let rawText: String
    let observationTime: Date
    let receiptTime: Date?
    let latitude: Double
    let longitude: Double
    let aircraftType: String?
    let flightLevel: Int?
    let flightLevelType: String?
    let weatherPhenomena: String?
    let visibility: Double?
    let temperature: Int?
    let turbulenceLayers: [PIREPTurbulenceLayer]
    let icingLayers: [PIREPIcingLayer]
    let reportType: PIREPReportType

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var dominantHazard: PIREPHazard {
        if primaryIcingLayer != nil {
            return .icing
        }
        if primaryTurbulenceLayer != nil {
            return .turbulence
        }
        if let weatherPhenomena, !weatherPhenomena.isEmpty {
            return .weather
        }
        return .general
    }

    var hazardSummary: String {
        if let primaryIcingLayer {
            return primaryIcingLayer.summary
        }
        if let primaryTurbulenceLayer {
            return primaryTurbulenceLayer.summary
        }
        if let weatherPhenomena, !weatherPhenomena.isEmpty {
            return weatherPhenomena
        }
        return reportType.displayName
    }

    private var primaryIcingLayer: PIREPIcingLayer? {
        icingLayers.first { $0.hasHazardSignal }
    }

    private var primaryTurbulenceLayer: PIREPTurbulenceLayer? {
        turbulenceLayers.first { $0.hasHazardSignal }
    }
}

struct PIREPTurbulenceLayer {
    let intensity: String
    let type: String
    let frequency: String
    let base: Int?
    let top: Int?

    var hasHazardSignal: Bool {
        hasContent && !isNegativeReport
    }

    var summary: String {
        let components = [frequency, intensity, type]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let detail = components.joined(separator: " ")
        let altitude = altitudeBand
        if altitude.isEmpty {
            return detail.isEmpty ? "Turbulence" : detail
        }
        return detail.isEmpty ? altitude : "\(detail) \(altitude)"
    }

    private var hasContent: Bool {
        !normalizedTokens.isEmpty || base != nil || top != nil
    }

    private var isNegativeReport: Bool {
        normalizedTokens.contains { token in
            ["NEG", "NEGATIVE", "SMTH", "SMOOTH"].contains(token)
        }
    }

    private var normalizedTokens: [String] {
        [frequency, intensity, type]
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()
                    .replacingOccurrences(of: " ", with: "")
            }
            .filter { !$0.isEmpty }
    }

    private var altitudeBand: String {
        switch (base, top) {
        case let (base?, top?):
            return "\(base)-\(top)"
        case let (base?, nil):
            return "from \(base)"
        case let (nil, top?):
            return "to \(top)"
        default:
            return ""
        }
    }
}

struct PIREPIcingLayer {
    let intensity: String
    let type: String
    let base: Int?
    let top: Int?

    var hasHazardSignal: Bool {
        hasContent && !isNegativeReport
    }

    var summary: String {
        let components = [intensity, type]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let detail = components.joined(separator: " ")
        let altitude = altitudeBand
        if altitude.isEmpty {
            return detail.isEmpty ? "Icing" : detail
        }
        return detail.isEmpty ? altitude : "\(detail) \(altitude)"
    }

    private var hasContent: Bool {
        !normalizedTokens.isEmpty || base != nil || top != nil
    }

    private var isNegativeReport: Bool {
        normalizedTokens.contains { token in
            ["NEG", "NEGATIVE", "NONE"].contains(token)
        }
    }

    private var normalizedTokens: [String] {
        [intensity, type]
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()
                    .replacingOccurrences(of: " ", with: "")
            }
            .filter { !$0.isEmpty }
    }

    private var altitudeBand: String {
        switch (base, top) {
        case let (base?, top?):
            return "\(base)-\(top)"
        case let (base?, nil):
            return "above \(base)"
        case let (nil, top?):
            return "below \(top)"
        default:
            return ""
        }
    }
}

extension PIREP {
    var flightLevelDisplay: String {
        guard let flightLevel, flightLevel > 0 else {
            return "Unknown"
        }

        switch flightLevelType?.uppercased() {
        case "MSL":
            return "\(flightLevel * 100) ft MSL"
        default:
            return "FL\(flightLevel)"
        }
    }

    func distance(from coordinate: CLLocationCoordinate2D) -> Double {
        let reportLocation = CLLocation(latitude: latitude, longitude: longitude)
        let fromLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return reportLocation.distance(from: fromLocation)
    }

    func formattedDistance(from coordinate: CLLocationCoordinate2D) -> String {
        let miles = distance(from: coordinate) / 1609.34
        if miles < 1 {
            return String(format: "%.1f mi", miles)
        }
        return String(format: "%.0f mi", miles)
    }
}

enum PIREPReportType: String {
    case pirep = "PIREP"
    case urgent = "UUA"
    case unknown

    init(rawValue: String?) {
        switch rawValue?.uppercased() {
        case Self.pirep.rawValue:
            self = .pirep
        case Self.urgent.rawValue:
            self = .urgent
        default:
            self = .unknown
        }
    }

    var displayName: String {
        switch self {
        case .pirep:
            return "Routine PIREP"
        case .urgent:
            return "Urgent PIREP"
        case .unknown:
            return "PIREP"
        }
    }
}

enum PIREPHazard: String, CaseIterable {
    case turbulence
    case icing
    case weather
    case general

    var displayName: String {
        switch self {
        case .turbulence:
            return "Turbulence"
        case .icing:
            return "Icing"
        case .weather:
            return "Weather"
        case .general:
            return "General"
        }
    }

    var systemImage: String {
        switch self {
        case .turbulence:
            return "wind"
        case .icing:
            return "snowflake"
        case .weather:
            return "cloud.rain"
        case .general:
            return "airplane"
        }
    }
}
