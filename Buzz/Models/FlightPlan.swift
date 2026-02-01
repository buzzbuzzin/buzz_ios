//
//  FlightPlan.swift
//  Buzz
//
//  Created for flight plan form data
//

import Foundation
import UIKit

// MARK: - Regulatory Enums

/// Regulatory authority selection
enum RegulatoryAuthority: String, Codable {
    case faa = "FAA"
    case transportCanada = "TC"
}

/// Certification regulation for pilot certification statement
enum CertificationRegulation: String, Codable, CaseIterable {
    // USA regulations
    case part107 = "14 CFR Part 107"
    case part108 = "14 CFR Part 108"
    // Canada regulations
    case tp15263 = "Part IX TP 15263"
    case tp15530 = "Part IX TP 15530"

    /// Display name for the regulation
    var displayName: String {
        return self.rawValue
    }

    /// Country/region for this regulation
    var country: String {
        switch self {
        case .part107, .part108:
            return "USA"
        case .tp15263, .tp15530:
            return "Canada"
        }
    }

    /// USA regulations
    static var usaRegulations: [CertificationRegulation] {
        return [.part107, .part108]
    }

    /// Canada regulations
    static var canadaRegulations: [CertificationRegulation] {
        return [.tp15263, .tp15530]
    }
}

/// LAANC authorization status based on airspace and altitude
enum LAANCAuthorizationStatus: String, Codable {
    case autoApproved = "Auto-Approved"
    case manualReviewRequired = "Manual FAA Review Required"
    case noLAANCCoverage = "No LAANC - Manual Auth Required"  // Controlled airspace without LAANC grid
    case notPermitted = "Not Permitted Under Part 107"
    case pending = "Pending"
    case notApplicable = "N/A"  // Class G or non-US
}

/// Visual line of sight type
enum VLOSType: String, Codable {
    case vlos = "VLOS"
    case bvlos = "BVLOS"
}

/// Airspace classification
enum AirspaceClass: String, Codable {
    case classB = "B"
    case classC = "C"
    case classD = "D"
    case classE = "E"
    case classG = "G"
    case unknown = "Unknown"
}

// MARK: - Flight Plan Form Data

/// Data structure for flight plan form data (used for PDF generation)
struct FlightPlanFormData {
    // Flight Plan Section
    let pilotName: String
    let pilotLicenseNumber: String?  // Part 107 Certificate Number (US) or RPA Pilot Certificate Number (Canada)
    let callSign: String
    let droneManufacturer: String?
    let droneModel: String?
    let droneSerialNumber: String?
    let droneRegistrationNumber: String?
    let takeoffDateTime: Date
    let location: String
    let latitude: String?
    let longitude: String?

    // Regulatory Section
    let regulatoryAuthority: RegulatoryAuthority
    let maxAltitudeFeet: Int
    let airspaceClass: AirspaceClass
    let laancGridCeiling: Int?
    let laancAuthorizationStatus: LAANCAuthorizationStatus

    // Flight Operations Section
    let flightOverPeople: Bool
    let flightOverPeopleExplanation: String?
    let vlosType: VLOSType

    // Part 107 Compliance Section
    let part107Compliant: Bool
    let part107NonComplianceExplanation: String?

    // Waiver Section
    let requiresWaiver: Bool
    let waiverSafetyMitigations: String?
    let waiverOperationalProcedures: String?
    let waiverRiskAnalysis: String?

    // Certification Section
    let certificationRegulation: CertificationRegulation
    let signatureImage: UIImage?
    let signatureDate: Date?

    // Metadata
    let generatedAt: Date
}
