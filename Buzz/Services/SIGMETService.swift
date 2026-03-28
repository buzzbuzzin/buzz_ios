//
//  SIGMETService.swift
//  Buzz
//
//  Created for fetching AviationWeather SIGMET advisories for chart overlays.
//

import Foundation
import MapKit
import Combine

@MainActor
final class SIGMETService: ObservableObject {
    @Published var advisories: [SIGMETAdvisory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let baseURL = "https://aviationweather.gov/api/data"
    private let cacheValiditySeconds: TimeInterval = 180
    private let cacheThreshold: Double = 0.2

    private var cachedRegion: MKCoordinateRegion?
    private var cachedAt: Date?

    func fetchAdvisories(
        for region: MKCoordinateRegion,
        forceRefresh: Bool = false
    ) async throws -> [SIGMETAdvisory] {
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
            var components = URLComponents(string: "\(baseURL)/airsigmet")
            components?.queryItems = [
                URLQueryItem(name: "bbox", value: region.boundingBoxString),
                URLQueryItem(name: "format", value: "json")
            ]

            guard let url = components?.url else {
                throw SIGMETServiceError.invalidURL
            }

            var request = URLRequest(url: url)
            request.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 15

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SIGMETServiceError.invalidResponse
            }

            if httpResponse.statusCode == 204 {
                advisories = []
                cachedRegion = region
                cachedAt = Date()
                return []
            }

            guard httpResponse.statusCode == 200 else {
                throw SIGMETServiceError.httpError(statusCode: httpResponse.statusCode)
            }

            let parsed = try parseAdvisories(data: data)
            let visibleAdvisories = parsed.filter { advisory in
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

    private func parseAdvisories(data: Data) throws -> [SIGMETAdvisory] {
        let decoder = JSONDecoder()
        let responses: [SIGMETAPIResponse]

        do {
            responses = try decoder.decode([SIGMETAPIResponse].self, from: data)
        } catch {
            print("SIGMET parsing error: \(error)")
            throw SIGMETServiceError.parsingError
        }

        return responses.compactMap { response in
            guard let issuingOffice = response.issuingOffice,
                  let seriesId = response.seriesId,
                  let alphaChar = response.alphaChar,
                  let validFrom = response.validTimeFrom.map({ Date(timeIntervalSince1970: TimeInterval($0)) }),
                  let validTo = response.validTimeTo.map({ Date(timeIntervalSince1970: TimeInterval($0)) }),
                  let rawText = response.rawAirSigmet else {
                return nil
            }

            let coordinates = (response.coordinates ?? []).compactMap { coordinate -> CLLocationCoordinate2D? in
                guard let latitude = coordinate.latitude,
                      let longitude = coordinate.longitude else {
                    return nil
                }
                return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }

            guard coordinates.count >= 3 else {
                return nil
            }

            let creationTime = Self.parseDate(response.creationTime)
            let hazard = SIGMETHazard(rawValue: response.hazard)
            let altitudeLow = [response.altitudeLow1, response.altitudeLow2].compactMap { $0 }.min()
            let altitudeHigh = [response.altitudeHigh1, response.altitudeHigh2].compactMap { $0 }.max()

            return SIGMETAdvisory(
                id: "\(issuingOffice)-\(seriesId)-\(alphaChar)-\(validFrom.timeIntervalSince1970)-\(hazard.rawValue)",
                issuingOffice: issuingOffice,
                seriesId: seriesId,
                alphaChar: alphaChar,
                validFrom: validFrom,
                validTo: validTo,
                creationTime: creationTime,
                hazard: hazard,
                type: response.airSigmetType ?? "SIGMET",
                severity: response.severity,
                movementDirection: response.movementDirection,
                movementSpeed: response.movementSpeed,
                altitudeLow: altitudeLow,
                altitudeHigh: altitudeHigh,
                rawText: rawText,
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

private struct SIGMETAPIResponse: Decodable {
    let issuingOffice: String?
    let alphaChar: String?
    let seriesId: String?
    let creationTime: String?
    let validTimeFrom: Int?
    let validTimeTo: Int?
    let airSigmetType: String?
    let hazard: String?
    let altitudeHigh1: Int?
    let altitudeHigh2: Int?
    let altitudeLow1: Int?
    let altitudeLow2: Int?
    let movementDirection: Int?
    let movementSpeed: Int?
    let rawAirSigmet: String?
    let severity: Int?
    let coordinates: [SIGMETCoordinateResponse]?

    enum CodingKeys: String, CodingKey {
        case issuingOffice = "icaoId"
        case alphaChar
        case seriesId
        case creationTime
        case validTimeFrom
        case validTimeTo
        case airSigmetType
        case hazard
        case altitudeHigh1 = "altitudeHi1"
        case altitudeHigh2 = "altitudeHi2"
        case altitudeLow1 = "altitudeLow1"
        case altitudeLow2 = "altitudeLow2"
        case movementDirection = "movementDir"
        case movementSpeed = "movementSpd"
        case rawAirSigmet
        case severity
        case coordinates = "coords"
    }
}

private struct SIGMETCoordinateResponse: Decodable {
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case latitude = "lat"
        case longitude = "lon"
    }
}

private enum SIGMETServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case parsingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Unable to build the SIGMET request."
        case .invalidResponse:
            return "The SIGMET service returned an invalid response."
        case .httpError(let statusCode):
            return "The SIGMET service returned HTTP \(statusCode)."
        case .parsingError:
            return "Unable to parse the SIGMET response."
        }
    }
}
