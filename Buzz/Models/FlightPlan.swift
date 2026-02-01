//
//  FlightPlan.swift
//  Buzz
//
//  Created for flight plan form data
//

import Foundation
import UIKit

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

    // Certification Section
    let signatureImage: UIImage?
    let signatureDate: Date?

    // Metadata
    let generatedAt: Date
}
