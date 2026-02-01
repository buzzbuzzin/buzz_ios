//
//  SiteSurvey.swift
//  Buzz
//
//  Created for site survey form data
//

import Foundation

/// Data structure for site survey form data (used for PDF generation)
struct SiteSurveyFormData {
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

    // Optional location info for weather fetching
    let location: String?
    let locationCoordinates: String?

    // Metadata
    let pilotName: String
    let generatedAt: Date
}
