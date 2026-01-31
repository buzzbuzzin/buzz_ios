//
//  FlightPlan.swift
//  Buzz
//
//  Created for flight plan and site survey form
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

    // Site Survey Section
    let operationBoundaries: String
    let airspaceAndRequirements: String
    let altitudesAndRoutes: String
    let proximityMannedAircraft: String
    let proximityAerodromes: String
    let obstacleLocationsHeights: String
    let weatherConditions: String
    let horizontalDistanceBystanders: String
    let notes: String?

    // Metadata
    let generatedAt: Date
}
