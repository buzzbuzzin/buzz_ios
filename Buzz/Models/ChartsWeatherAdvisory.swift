//
//  ChartsWeatherAdvisory.swift
//  Buzz
//
//  Created for G-AIRMET and SIGMET chart overlays.
//

import Foundation
import CoreLocation

struct GAIRMETAdvisory: Identifiable {
    let id: String
    let tag: String
    let forecastHour: Int
    let validTime: Date
    let issueTime: Date?
    let expireTime: Date?
    let hazard: GAIRMETHazard
    let geometryType: ChartsWeatherGeometryType
    let dueTo: String?
    let level: String?
    let product: String
    let coordinates: [CLLocationCoordinate2D]

    var displayName: String {
        hazard.displayName
    }
}

struct SIGMETAdvisory: Identifiable {
    let id: String
    let issuingOffice: String
    let seriesId: String
    let alphaChar: String
    let validFrom: Date
    let validTo: Date
    let creationTime: Date?
    let hazard: SIGMETHazard
    let type: String
    let severity: Int?
    let movementDirection: Int?
    let movementSpeed: Int?
    let altitudeLow: Int?
    let altitudeHigh: Int?
    let rawText: String
    let coordinates: [CLLocationCoordinate2D]

    var displayName: String {
        hazard.displayName
    }
}

enum ChartsWeatherGeometryType: String {
    case area = "AREA"
    case line = "LINE"
    case point = "POINT"
    case unknown

    init(rawValue: String?) {
        switch rawValue?.uppercased() {
        case Self.area.rawValue:
            self = .area
        case Self.line.rawValue:
            self = .line
        case Self.point.rawValue:
            self = .point
        default:
            self = .unknown
        }
    }
}

enum GAIRMETHazard: String {
    case ifr = "IFR"
    case mountainObscuration = "MT_OBSC"
    case icing = "ICE"
    case turbulenceLow = "TURB-LO"
    case turbulenceHigh = "TURB-HI"
    case freezingLevel = "FZLVL"
    case multipleFreezingLevels = "M_FZLVL"
    case lowLevelWindShear = "LLWS"
    case surfaceWind = "SFC_WND"
    case unknown

    init(rawValue: String?) {
        switch rawValue?.uppercased() {
        case Self.ifr.rawValue:
            self = .ifr
        case Self.mountainObscuration.rawValue:
            self = .mountainObscuration
        case Self.icing.rawValue:
            self = .icing
        case Self.turbulenceLow.rawValue:
            self = .turbulenceLow
        case Self.turbulenceHigh.rawValue:
            self = .turbulenceHigh
        case Self.freezingLevel.rawValue:
            self = .freezingLevel
        case Self.multipleFreezingLevels.rawValue:
            self = .multipleFreezingLevels
        case Self.lowLevelWindShear.rawValue:
            self = .lowLevelWindShear
        case Self.surfaceWind.rawValue:
            self = .surfaceWind
        default:
            self = .unknown
        }
    }

    var displayName: String {
        switch self {
        case .ifr:
            return "IFR"
        case .mountainObscuration:
            return "Mountain Obscuration"
        case .icing:
            return "Icing"
        case .turbulenceLow:
            return "Low Turbulence"
        case .turbulenceHigh:
            return "High Turbulence"
        case .freezingLevel:
            return "Freezing Level"
        case .multipleFreezingLevels:
            return "Multi Freezing Level"
        case .lowLevelWindShear:
            return "LLWS"
        case .surfaceWind:
            return "Surface Wind"
        case .unknown:
            return "G-AIRMET"
        }
    }
}

enum SIGMETHazard: String {
    case convective = "CONVECTIVE"
    case icing = "ICE"
    case turbulence = "TURB"
    case volcanicAsh = "VA"
    case dustStorm = "DS"
    case sandStorm = "SS"
    case tropicalCyclone = "TC"
    case severeMountainWave = "MTW"
    case unknown

    init(rawValue: String?) {
        switch rawValue?.uppercased() {
        case Self.convective.rawValue:
            self = .convective
        case Self.icing.rawValue:
            self = .icing
        case Self.turbulence.rawValue:
            self = .turbulence
        case Self.volcanicAsh.rawValue:
            self = .volcanicAsh
        case Self.dustStorm.rawValue:
            self = .dustStorm
        case Self.sandStorm.rawValue:
            self = .sandStorm
        case Self.tropicalCyclone.rawValue:
            self = .tropicalCyclone
        case Self.severeMountainWave.rawValue:
            self = .severeMountainWave
        default:
            self = .unknown
        }
    }

    var displayName: String {
        switch self {
        case .convective:
            return "Convective"
        case .icing:
            return "Severe Icing"
        case .turbulence:
            return "Severe Turbulence"
        case .volcanicAsh:
            return "Volcanic Ash"
        case .dustStorm:
            return "Dust Storm"
        case .sandStorm:
            return "Sand Storm"
        case .tropicalCyclone:
            return "Tropical Cyclone"
        case .severeMountainWave:
            return "Mountain Wave"
        case .unknown:
            return "SIGMET"
        }
    }
}
