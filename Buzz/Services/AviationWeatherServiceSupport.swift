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

    var normalizedICAOCode: String {
        let filteredScalars = uppercased().unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar)
        }
        return String(String.UnicodeScalarView(filteredScalars).prefix(4))
    }
}

struct AviationWeatherAirportInfo: Codable, Equatable {
    let icaoId: String
    let iataId: String?
    let faaId: String?
    let name: String?
    let state: String?
    let country: String?
    let lat: Double?
    let lon: Double?
    let elev: Int?

    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lon else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }

    var displayName: String {
        var components: [String] = []
        if let name = name?.nilIfBlank {
            components.append(name)
        }
        if let state = state?.nilIfBlank {
            components.append(state)
        } else if let country = country?.nilIfBlank {
            components.append(country)
        }

        return components.isEmpty ? icaoId : components.joined(separator: ", ")
    }
}

enum AviationWeatherAirportLookupError: LocalizedError {
    case invalidICAOCode
    case invalidURL
    case invalidResponse
    case airportNotFound(String)
    case missingCoordinates(String)
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidICAOCode:
            return "Enter a 4-letter ICAO code."
        case .invalidURL:
            return "Invalid airport lookup URL."
        case .invalidResponse:
            return "Invalid response from aviation weather service."
        case .airportNotFound(let code):
            return "No airport found for \(code)."
        case .missingCoordinates(let code):
            return "Airport \(code) is missing location data."
        case .httpError(let statusCode):
            return "Airport lookup failed with HTTP \(statusCode)."
        }
    }
}

final class AviationWeatherAirportLookupService {
    private let baseURL = "https://aviationweather.gov/api/data"
    private let cacheValiditySeconds: TimeInterval = 3600
    private var cachedAirports: [String: (airport: AviationWeatherAirportInfo, fetchedAt: Date)] = [:]

    func fetchAirport(
        icaoCode: String,
        forceRefresh: Bool = false
    ) async throws -> AviationWeatherAirportInfo {
        let normalizedCode = icaoCode.normalizedICAOCode
        guard normalizedCode.count == 4 else {
            throw AviationWeatherAirportLookupError.invalidICAOCode
        }

        if !forceRefresh,
           let cachedEntry = cachedAirports[normalizedCode],
           Date().timeIntervalSince(cachedEntry.fetchedAt) < cacheValiditySeconds {
            return cachedEntry.airport
        }

        let urlString = "\(baseURL)/airport?ids=\(normalizedCode)&format=json"
        guard let url = URL(string: urlString) else {
            throw AviationWeatherAirportLookupError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AviationWeatherAirportLookupError.invalidResponse
        }

        if httpResponse.statusCode == 204 {
            throw AviationWeatherAirportLookupError.airportNotFound(normalizedCode)
        }

        guard httpResponse.statusCode == 200 else {
            throw AviationWeatherAirportLookupError.httpError(httpResponse.statusCode)
        }

        let airports = try JSONDecoder().decode([AviationWeatherAirportInfo].self, from: data)
        guard let airport = airports.first else {
            throw AviationWeatherAirportLookupError.airportNotFound(normalizedCode)
        }
        guard airport.coordinate != nil else {
            throw AviationWeatherAirportLookupError.missingCoordinates(normalizedCode)
        }

        cachedAirports[normalizedCode] = (airport, Date())
        return airport
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

        var longitudes: [Double] = [firstCoordinate.longitude]

        for coordinate in validCoordinates.dropFirst() {
            minLatitude = min(minLatitude, coordinate.latitude)
            maxLatitude = max(maxLatitude, coordinate.latitude)
            longitudes.append(coordinate.longitude)
        }

        // Detect antimeridian wrap: sort longitudes, find the largest gap between
        // consecutive points (treating the list as circular across ±180°). The bounds
        // span the complement of the largest gap — if that gap is > 180°, the original
        // longitude range naturally wraps, and we express it as minLongitude > maxLongitude.
        let sorted = longitudes.sorted()
        var minLongitude = sorted.first!
        var maxLongitude = sorted.last!
        if sorted.count > 1 {
            var largestGap = (sorted.first! + 360.0) - sorted.last! // wrap-around gap
            var gapStartIndex = sorted.count - 1                   // last → first
            for i in 0..<(sorted.count - 1) {
                let gap = sorted[i + 1] - sorted[i]
                if gap > largestGap {
                    largestGap = gap
                    gapStartIndex = i
                }
            }
            // If the largest gap crosses the antimeridian, the bounds wrap.
            if gapStartIndex == sorted.count - 1 {
                // Largest gap is sorted.last → sorted.first (crosses ±180°).
                // This means the longitudes are contiguous from sorted.first to sorted.last
                // and DON'T wrap — keep min/max as-is.
                minLongitude = sorted.first!
                maxLongitude = sorted.last!
            } else {
                // Largest gap is an internal gap — the longitudes wrap through the antimeridian.
                // The actual range goes from sorted[gapStartIndex+1] up to 180°,
                // then from -180° up to sorted[gapStartIndex].
                minLongitude = sorted[gapStartIndex + 1]
                maxLongitude = sorted[gapStartIndex]
            }
        }

        self.init(
            minLatitude: minLatitude,
            maxLatitude: maxLatitude,
            minLongitude: minLongitude,
            maxLongitude: maxLongitude
        )
    }

    /// Returns true if this box overlaps `other`. Handles antimeridian wrap where
    /// `minLongitude > maxLongitude` represents a range that crosses ±180°.
    func intersects(_ other: CoordinateBounds) -> Bool {
        // Latitudes never wrap.
        if other.minLatitude > maxLatitude || other.maxLatitude < minLatitude {
            return false
        }
        let selfWraps = minLongitude > maxLongitude
        let otherWraps = other.minLongitude > other.maxLongitude
        switch (selfWraps, otherWraps) {
        case (false, false):
            return !(other.minLongitude > maxLongitude || other.maxLongitude < minLongitude)
        case (true, false):
            // self covers [minLon..180] ∪ [-180..maxLon]
            return other.maxLongitude >= minLongitude || other.minLongitude <= maxLongitude
        case (false, true):
            return maxLongitude >= other.minLongitude || minLongitude <= other.maxLongitude
        case (true, true):
            // Two wrapping ranges always overlap on some side of the antimeridian.
            return true
        }
    }
}
