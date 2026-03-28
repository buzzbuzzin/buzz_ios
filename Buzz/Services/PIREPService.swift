//
//  PIREPService.swift
//  Buzz
//
//  Created for fetching AviationWeather PIREPs for chart overlays.
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class PIREPService: ObservableObject {
    @Published var nearbyPIREPs: [PIREP] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let baseURL = "https://aviationweather.gov/api/data"
    private let cacheValiditySeconds: TimeInterval = 180

    private var lastFetchTime: Date?
    private var lastFetchCoordinate: CLLocationCoordinate2D?
    private var lastFetchRadiusDegrees: Double?
    private var lastFetchMaxResults: Int?

    func fetchPIREPsNearLocation(
        coordinate: CLLocationCoordinate2D,
        radiusDegrees: Double = 0.5,
        maxResults: Int = 25,
        forceRefresh: Bool = false
    ) async throws -> [PIREP] {
        if !forceRefresh,
           let lastFetchTime,
           let lastFetchCoordinate,
           let lastFetchRadiusDegrees,
           let lastFetchMaxResults,
           Date().timeIntervalSince(lastFetchTime) < cacheValiditySeconds {
            let latDiff = abs(lastFetchCoordinate.latitude - coordinate.latitude)
            let lonDiff = abs(lastFetchCoordinate.longitude - coordinate.longitude)
            let radiusDiff = abs(lastFetchRadiusDegrees - radiusDegrees)
            if latDiff < 0.01 &&
                lonDiff < 0.01 &&
                radiusDiff < 0.001 &&
                lastFetchMaxResults == maxResults &&
                !nearbyPIREPs.isEmpty {
                return nearbyPIREPs
            }
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let minLat = coordinate.latitude - radiusDegrees
            let maxLat = coordinate.latitude + radiusDegrees
            let minLon = coordinate.longitude - radiusDegrees
            let maxLon = coordinate.longitude + radiusDegrees

            var components = URLComponents(string: "\(baseURL)/pirep")
            components?.queryItems = [
                URLQueryItem(name: "bbox", value: "\(minLat),\(minLon),\(maxLat),\(maxLon)"),
                URLQueryItem(name: "format", value: "json")
            ]

            guard let url = components?.url else {
                throw PIREPServiceError.invalidURL
            }

            var request = URLRequest(url: url)
            request.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 15

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PIREPServiceError.invalidResponse
            }

            if httpResponse.statusCode == 204 {
                nearbyPIREPs = []
                lastFetchTime = Date()
                lastFetchCoordinate = coordinate
                lastFetchRadiusDegrees = radiusDegrees
                lastFetchMaxResults = maxResults
                return []
            }

            guard httpResponse.statusCode == 200 else {
                throw PIREPServiceError.httpError(statusCode: httpResponse.statusCode)
            }

            let reports = try parsePIREPResponse(data: data, userCoordinate: coordinate)
            nearbyPIREPs = Array(
                reports
                    .sorted { $0.distance(from: coordinate) < $1.distance(from: coordinate) }
                    .prefix(maxResults)
            )
            lastFetchTime = Date()
            lastFetchCoordinate = coordinate
            lastFetchRadiusDegrees = radiusDegrees
            lastFetchMaxResults = maxResults
            return nearbyPIREPs
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return nearbyPIREPs
            }

            errorMessage = error.localizedDescription
            throw error
        }
    }

    func clearCache(keepDisplayedPIREPs: Bool = true) {
        lastFetchTime = nil
        lastFetchCoordinate = nil
        lastFetchRadiusDegrees = nil
        lastFetchMaxResults = nil
        errorMessage = nil
        if !keepDisplayedPIREPs {
            nearbyPIREPs = []
        }
    }

    private func parsePIREPResponse(
        data: Data,
        userCoordinate: CLLocationCoordinate2D
    ) throws -> [PIREP] {
        let decoder = JSONDecoder()
        let responses: [PIREPAPIResponse]

        do {
            responses = try decoder.decode([PIREPAPIResponse].self, from: data)
        } catch {
            print("PIREP parsing error: \(error)")
            throw PIREPServiceError.parsingError
        }

        return responses.compactMap { response in
            guard let rawText = response.rawObservation else {
                return nil
            }

            let observationTime = response.obsTime.map {
                Date(timeIntervalSince1970: TimeInterval($0))
            } ?? parseISO8601Date(response.receiptTime) ?? Date()

            let receiptTime = parseISO8601Date(response.receiptTime)
            let latitude = response.latitude ?? userCoordinate.latitude
            let longitude = response.longitude ?? userCoordinate.longitude
            let icingLayers = buildIcingLayers(from: response)
            let turbulenceLayers = buildTurbulenceLayers(from: response)
            let identifier = rawText
                .replacingOccurrences(of: " ", with: "_")
                .prefix(80)

            return PIREP(
                id: "\(identifier)-\(observationTime.timeIntervalSince1970)",
                stationId: response.stationId,
                rawText: rawText,
                observationTime: observationTime,
                receiptTime: receiptTime,
                latitude: latitude,
                longitude: longitude,
                aircraftType: response.aircraftType,
                flightLevel: response.flightLevel,
                flightLevelType: response.flightLevelType,
                weatherPhenomena: response.weatherPhenomena?.nilIfBlank,
                visibility: response.visibility,
                temperature: response.temperature,
                turbulenceLayers: turbulenceLayers,
                icingLayers: icingLayers,
                reportType: PIREPReportType(rawValue: response.reportType)
            )
        }
    }

    private func buildIcingLayers(from response: PIREPAPIResponse) -> [PIREPIcingLayer] {
        [
            PIREPIcingLayer(
                intensity: response.icingIntensity1 ?? "",
                type: response.icingType1 ?? "",
                base: response.icingBase1,
                top: response.icingTop1
            ),
            PIREPIcingLayer(
                intensity: response.icingIntensity2 ?? "",
                type: response.icingType2 ?? "",
                base: response.icingBase2,
                top: response.icingTop2
            )
        ]
        .filter { $0.hasHazardSignal }
    }

    private func buildTurbulenceLayers(from response: PIREPAPIResponse) -> [PIREPTurbulenceLayer] {
        [
            PIREPTurbulenceLayer(
                intensity: response.turbulenceIntensity1 ?? "",
                type: response.turbulenceType1 ?? "",
                frequency: response.turbulenceFrequency1 ?? "",
                base: response.turbulenceBase1,
                top: response.turbulenceTop1
            ),
            PIREPTurbulenceLayer(
                intensity: response.turbulenceIntensity2 ?? "",
                type: response.turbulenceType2 ?? "",
                frequency: response.turbulenceFrequency2 ?? "",
                base: response.turbulenceBase2,
                top: response.turbulenceTop2
            )
        ]
        .filter { $0.hasHazardSignal }
    }

    private func parseISO8601Date(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

private struct PIREPAPIResponse: Decodable {
    let receiptTime: String?
    let obsTime: Int?
    let stationId: String?
    let aircraftType: String?
    let latitude: Double?
    let longitude: Double?
    let flightLevel: Int?
    let flightLevelType: String?
    let visibility: Double?
    let weatherPhenomena: String?
    let temperature: Int?
    let icingBase1: Int?
    let icingTop1: Int?
    let icingIntensity1: String?
    let icingType1: String?
    let icingBase2: Int?
    let icingTop2: Int?
    let icingIntensity2: String?
    let icingType2: String?
    let turbulenceBase1: Int?
    let turbulenceTop1: Int?
    let turbulenceIntensity1: String?
    let turbulenceType1: String?
    let turbulenceFrequency1: String?
    let turbulenceBase2: Int?
    let turbulenceTop2: Int?
    let turbulenceIntensity2: String?
    let turbulenceType2: String?
    let turbulenceFrequency2: String?
    let reportType: String?
    let rawObservation: String?

    enum CodingKeys: String, CodingKey {
        case receiptTime
        case obsTime
        case stationId = "icaoId"
        case aircraftType = "acType"
        case latitude = "lat"
        case longitude = "lon"
        case flightLevel = "fltLvl"
        case flightLevelType = "fltLvlType"
        case visibility = "visib"
        case weatherPhenomena = "wxString"
        case temperature = "temp"
        case icingBase1 = "icgBas1"
        case icingTop1 = "icgTop1"
        case icingIntensity1 = "icgInt1"
        case icingType1 = "icgType1"
        case icingBase2 = "icgBas2"
        case icingTop2 = "icgTop2"
        case icingIntensity2 = "icgInt2"
        case icingType2 = "icgType2"
        case turbulenceBase1 = "tbBas1"
        case turbulenceTop1 = "tbTop1"
        case turbulenceIntensity1 = "tbInt1"
        case turbulenceType1 = "tbType1"
        case turbulenceFrequency1 = "tbFreq1"
        case turbulenceBase2 = "tbBas2"
        case turbulenceTop2 = "tbTop2"
        case turbulenceIntensity2 = "tbInt2"
        case turbulenceType2 = "tbType2"
        case turbulenceFrequency2 = "tbFreq2"
        case reportType = "pirepType"
        case rawObservation = "rawOb"
    }
}

private enum PIREPServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case parsingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Unable to build the PIREP request."
        case .invalidResponse:
            return "The PIREP service returned an invalid response."
        case .httpError(let statusCode):
            return "The PIREP service returned HTTP \(statusCode)."
        case .parsingError:
            return "Unable to parse the PIREP response."
        }
    }
}
