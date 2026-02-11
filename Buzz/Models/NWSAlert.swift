//
//  NWSAlert.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/11/26.
//

import Foundation

/// Root response from GET https://api.weather.gov/alerts/active?point={lat},{lon}
struct NWSAlertResponse: Codable {
    let features: [NWSAlertFeature]
}

struct NWSAlertFeature: Codable, Identifiable {
    let id: String
    let properties: NWSAlertProperties
}

struct NWSAlertProperties: Codable {
    let event: String
    let severity: String
    let urgency: String
    let headline: String?
    let description: String?
    let instruction: String?
    let onset: String?
    let expires: String?
    let areaDesc: String?
}
