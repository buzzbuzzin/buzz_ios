//
//  GAIRMETService.swift
//  Buzz
//
//  Created for fetching AviationWeather G-AIRMET advisories for chart overlays.
//

import Foundation
import MapKit
import Combine

@MainActor
final class GAIRMETService: ObservableObject {
    @Published var advisories: [GAIRMETAdvisory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let baseURL = "https://aviationweather.gov/api/data"
    private let cacheValiditySeconds: TimeInterval = 300
    private let cacheThreshold: Double = 0.2

    private var cachedRegion: MKCoordinateRegion?
    private var cachedAt: Date?

    func fetchAdvisories(
        for region: MKCoordinateRegion,
        forceRefresh: Bool = false
    ) async throws -> [GAIRMETAdvisory] {
        if !forceRefresh,
           let cachedRegion,
           let cachedAt,
           Date().timeIntervalSince(cachedAt) < cacheValiditySeconds,
           regionsAreEquivalent(lhs: cachedRegion, rhs: region) {
            return advisories
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let bbox = region.boundingBoxString
            var components = URLComponents(string: "\(baseURL)/gairmet")
            components?.queryItems = [
                URLQueryItem(name: "bbox", value: bbox),
                URLQueryItem(name: "format", value: "json")
            ]

            guard let url = components?.url else {
                throw GAIRMETServiceError.invalidURL
            }

            var request = URLRequest(url: url)
            request.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 15

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GAIRMETServiceError.invalidResponse
            }

            if httpResponse.statusCode == 204 {
                advisories = []
                cachedRegion = region
                cachedAt = Date()
                return []
            }

            guard httpResponse.statusCode == 200 else {
                throw GAIRMETServiceError.httpError(statusCode: httpResponse.statusCode)
            }

            let parsedAdvisories = try parseAdvisories(data: data)
            let visibleAdvisories = parsedAdvisories.filter { advisory in
                region.intersectsBoundingBox(of: advisory.coordinates)
            }
            advisories = visibleAdvisories
            cachedRegion = region
            cachedAt = Date()
            return visibleAdvisories
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func clearCache(keepDisplayedAdvisories: Bool = true) {
        cachedRegion = nil
        cachedAt = nil
        errorMessage = nil
        if !keepDisplayedAdvisories {
            advisories = []
        }
    }

    private func parseAdvisories(data: Data) throws -> [GAIRMETAdvisory] {
        let decoder = JSONDecoder()
        let responses: [GAIRMETAPIResponse]

        do {
            responses = try decoder.decode([GAIRMETAPIResponse].self, from: data)
        } catch {
            print("G-AIRMET parsing error: \(error)")
            throw GAIRMETServiceError.parsingError
        }

        return responses.compactMap { response in
            guard let tag = response.tag,
                  let validTime = Self.parseDate(response.validTime),
                  let forecastHour = response.forecastHour else {
                return nil
            }

            let coordinates = (response.coordinates ?? []).compactMap { coordinate -> CLLocationCoordinate2D? in
                guard let latitude = Double(coordinate.latitude ?? ""),
                      let longitude = Double(coordinate.longitude ?? "") else {
                    return nil
                }
                return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }

            guard coordinates.count >= 2 else {
                return nil
            }

            let geometryType = ChartsWeatherGeometryType(rawValue: response.geometryType)
            let hazard = GAIRMETHazard(rawValue: response.hazard)
            let issueTime = response.issueTime.map { Date(timeIntervalSince1970: TimeInterval($0)) }
            let expireTime = response.expireTime.map { Date(timeIntervalSince1970: TimeInterval($0)) }

            return GAIRMETAdvisory(
                id: "\(tag)-\(forecastHour)-\(hazard.rawValue)-\(validTime.timeIntervalSince1970)-\(geometryType.rawValue)",
                tag: tag,
                forecastHour: forecastHour,
                validTime: validTime,
                issueTime: issueTime,
                expireTime: expireTime,
                hazard: hazard,
                geometryType: geometryType,
                dueTo: response.dueTo?.nilIfBlank,
                level: response.level?.nilIfBlank,
                product: response.product ?? "G-AIRMET",
                coordinates: coordinates
            )
        }
    }

    private func regionsAreEquivalent(lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        abs(lhs.center.latitude - rhs.center.latitude) < cacheThreshold &&
        abs(lhs.center.longitude - rhs.center.longitude) < cacheThreshold &&
        abs(lhs.span.latitudeDelta - rhs.span.latitudeDelta) < cacheThreshold &&
        abs(lhs.span.longitudeDelta - rhs.span.longitudeDelta) < cacheThreshold
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

private struct GAIRMETAPIResponse: Decodable {
    let tag: String?
    let forecastHour: Int?
    let validTime: String?
    let hazard: String?
    let geometryType: String?
    let dueTo: String?
    let level: String?
    let issueTime: Int?
    let expireTime: Int?
    let product: String?
    let coordinates: [GAIRMETCoordinateResponse]?

    enum CodingKeys: String, CodingKey {
        case tag
        case forecastHour
        case validTime
        case hazard
        case geometryType
        case dueTo = "due_to"
        case level
        case issueTime
        case expireTime
        case product
        case coordinates = "coords"
    }
}

private struct GAIRMETCoordinateResponse: Decodable {
    let latitude: String?
    let longitude: String?

    enum CodingKeys: String, CodingKey {
        case latitude = "lat"
        case longitude = "lon"
    }
}

private enum GAIRMETServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case parsingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Unable to build the G-AIRMET request."
        case .invalidResponse:
            return "The G-AIRMET service returned an invalid response."
        case .httpError(let statusCode):
            return "The G-AIRMET service returned HTTP \(statusCode)."
        case .parsingError:
            return "Unable to parse the G-AIRMET response."
        }
    }
}
