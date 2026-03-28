//
//  AviationWeatherServiceSupport.swift
//  Buzz
//
//  Shared helpers for AviationWeather chart services.
//

import Foundation
import MapKit

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension MKCoordinateRegion {
    var boundingBoxString: String {
        "\(coordinateBounds.minLatitude),\(coordinateBounds.minLongitude),\(coordinateBounds.maxLatitude),\(coordinateBounds.maxLongitude)"
    }

    var coordinateBounds: CoordinateBounds {
        CoordinateBounds(
            minLatitude: center.latitude - span.latitudeDelta / 2,
            maxLatitude: center.latitude + span.latitudeDelta / 2,
            minLongitude: center.longitude - span.longitudeDelta / 2,
            maxLongitude: center.longitude + span.longitudeDelta / 2
        )
    }

    func intersectsBoundingBox(of coordinates: [CLLocationCoordinate2D]) -> Bool {
        guard let overlayBounds = CoordinateBounds(coordinates: coordinates) else {
            return false
        }

        return coordinateBounds.intersects(overlayBounds)
    }
}

struct CoordinateBounds {
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double

    init(
        minLatitude: Double,
        maxLatitude: Double,
        minLongitude: Double,
        maxLongitude: Double
    ) {
        self.minLatitude = minLatitude
        self.maxLatitude = maxLatitude
        self.minLongitude = minLongitude
        self.maxLongitude = maxLongitude
    }

    init?(coordinates: [CLLocationCoordinate2D]) {
        let validCoordinates = coordinates.filter { coordinate in
            CLLocationCoordinate2DIsValid(coordinate)
        }
        guard let firstCoordinate = validCoordinates.first else {
            return nil
        }

        var minLatitude = firstCoordinate.latitude
        var maxLatitude = firstCoordinate.latitude
        var minLongitude = firstCoordinate.longitude
        var maxLongitude = firstCoordinate.longitude

        for coordinate in validCoordinates.dropFirst() {
            minLatitude = min(minLatitude, coordinate.latitude)
            maxLatitude = max(maxLatitude, coordinate.latitude)
            minLongitude = min(minLongitude, coordinate.longitude)
            maxLongitude = max(maxLongitude, coordinate.longitude)
        }

        self.init(
            minLatitude: minLatitude,
            maxLatitude: maxLatitude,
            minLongitude: minLongitude,
            maxLongitude: maxLongitude
        )
    }

    func intersects(_ other: CoordinateBounds) -> Bool {
        !(other.minLatitude > maxLatitude ||
          other.maxLatitude < minLatitude ||
          other.minLongitude > maxLongitude ||
          other.maxLongitude < minLongitude)
    }
}
