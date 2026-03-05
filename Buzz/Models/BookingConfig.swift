//
//  BookingConfig.swift
//  Buzz
//
//  Backend-managed booking configuration for specialization locking and service area
//

import Foundation
import CoreLocation

struct ServiceArea: Codable {
    let name: String
    let lat: Double
    let lng: Double
    let radiusMiles: Double

    enum CodingKeys: String, CodingKey {
        case name, lat, lng
        case radiusMiles = "radius_miles"
    }

    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let centerLocation = CLLocation(latitude: lat, longitude: lng)
        let point = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distanceInMiles = centerLocation.distance(from: point) / 1609.34
        return distanceInMiles <= radiusMiles
    }
}

struct BookingConfig: Codable {
    let id: String
    let supportedSpecializationsCreate: [String]
    let supportedSpecializationsEdit: [String]
    let comingSoonMessage: String
    let serviceAreas: [ServiceArea]
    let locationOutOfRangeMessage: String
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case supportedSpecializationsCreate = "supported_specializations_create"
        case supportedSpecializationsEdit = "supported_specializations_edit"
        case comingSoonMessage = "coming_soon_message"
        case serviceAreas = "service_areas"
        case locationOutOfRangeMessage = "location_out_of_range_message"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static let defaultConfig = BookingConfig(
        id: "default",
        supportedSpecializationsCreate: ["automotive", "real_estate", "search_rescue"],
        supportedSpecializationsEdit: ["automotive", "real_estate"],
        comingSoonMessage: "Launching in 2026! We are currently only supporting:\n\n• Automotive\n• Real Estate\n• Search & Rescue",
        serviceAreas: [
            ServiceArea(name: "Ithaca, NY", lat: 42.4434, lng: -76.5017, radiusMiles: 100.0),
            ServiceArea(name: "Ontario, Canada", lat: 44.0, lng: -79.5, radiusMiles: 250.0),
            ServiceArea(name: "British Columbia, Canada", lat: 53.7267, lng: -127.6476, radiusMiles: 500.0)
        ],
        locationOutOfRangeMessage: "As a first to market app, we currently do not service your area. Please continue to check the app as we are growing and rolling out in many more locations in 2026",
        createdAt: nil,
        updatedAt: nil
    )

    var enabledCreateSpecializations: [BookingSpecialization] {
        supportedSpecializationsCreate.compactMap { BookingSpecialization(rawValue: $0) }
    }

    var enabledEditSpecializations: [BookingSpecialization] {
        supportedSpecializationsEdit.compactMap { BookingSpecialization(rawValue: $0) }
    }

    func isSpecializationEnabled(_ specialization: BookingSpecialization, forEditing: Bool) -> Bool {
        let list = forEditing ? supportedSpecializationsEdit : supportedSpecializationsCreate
        return list.contains(specialization.rawValue)
    }

    func isLocationInServiceArea(_ coordinate: CLLocationCoordinate2D) -> Bool {
        serviceAreas.contains { $0.contains(coordinate) }
    }
}
