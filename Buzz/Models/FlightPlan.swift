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

/// LAANC authorization status based on airspace and altitude
enum LAANCAuthorizationStatus: String, Codable {
    case autoApproved = "Auto-Approved"
    case manualReviewRequired = "Manual FAA Review Required"
    case notPermitted = "Not Permitted Under Part 107"
    case pending = "Pending"
    case notApplicable = "N/A"
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
    let signatureImage: UIImage?
    let signatureDate: Date?

    // Metadata
    let generatedAt: Date
}
