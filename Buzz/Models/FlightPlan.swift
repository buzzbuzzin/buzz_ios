//
//  FlightPlan.swift
//  Buzz
//
//  Created for flight plan form data
//

import Foundation

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
    let locationCoordinates: String?

    // Metadata
    let generatedAt: Date
}
