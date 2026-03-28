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
