//
//  TAFService.swift
//  Buzz
//
//  Created by Xinyu Fang on 3/26/26.
//

import Foundation
import CoreLocation
import Combine

@MainActor
class TAFService: ObservableObject {
    @Published var nearbyTAFs: [TAF] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let baseURL = "https://aviationweather.gov/api/data"

    // Cache to avoid excessive API calls
    private var lastFetchTime: Date?
    private var lastFetchCoordinate: CLLocationCoordinate2D?
    private let cacheValiditySeconds: TimeInterval = 300 // 5 minutes

    // MARK: - Fetch TAFs Near Location

    /// Fetches TAF reports for airports near the given coordinate
    /// - Parameters:
    ///   - coordinate: The center point for the search
    ///   - radiusDegrees: The search radius in degrees (default 0.5 = ~55km)
    /// - Returns: Array of TAF reports sorted by distance
    func fetchTAFsNearLocation(
        coordinate: CLLocationCoordinate2D,
        radiusDegrees: Double = 0.5
    ) async throws -> [TAF] {
        // Check cache validity
        if let lastTime = lastFetchTime,
           let lastCoord = lastFetchCoordinate,
           Date().timeIntervalSince(lastTime) < cacheValiditySeconds {
            let latDiff = abs(lastCoord.latitude - coordinate.latitude)
            let lonDiff = abs(lastCoord.longitude - coordinate.longitude)
            if latDiff < 0.01 && lonDiff < 0.01 && !nearbyTAFs.isEmpty {
                return nearbyTAFs
            }
        }

        isLoading = true
        errorMessage = nil

        do {
            // Calculate bounding box
            let minLat = coordinate.latitude - radiusDegrees
            let maxLat = coordinate.latitude + radiusDegrees
            let minLon = coordinate.longitude - radiusDegrees
            let maxLon = coordinate.longitude + radiusDegrees

            // Build URL with bbox parameter
            let urlString = "\(baseURL)/taf?bbox=\(minLat),\(minLon),\(maxLat),\(maxLon)&format=json&hours=24"

            guard let url = URL(string: urlString) else {
                throw TAFError.invalidURL
            }

            var request = URLRequest(url: url)
            request.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 15

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TAFError.invalidResponse
            }

            // Handle 204 No Content - valid but no data available
            if httpResponse.statusCode == 204 {
                isLoading = false
                nearbyTAFs = []
                return []
            }

            guard httpResponse.statusCode == 200 else {
                throw TAFError.httpError(statusCode: httpResponse.statusCode)
            }

            // Parse the JSON response
            let tafs = try parseTAFResponse(data: data, userCoordinate: coordinate)

            // Sort by distance and limit to closest 5
            let sortedTAFs = tafs
                .sorted { $0.distance(from: coordinate) < $1.distance(from: coordinate) }
                .prefix(5)

            nearbyTAFs = Array(sortedTAFs)
            lastFetchTime = Date()
            lastFetchCoordinate = coordinate
            isLoading = false

            return nearbyTAFs

        } catch {
            isLoading = false

            // Handle cancellation gracefully
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return nearbyTAFs
            }

            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Parse TAF Response

    private func parseTAFResponse(data: Data, userCoordinate: CLLocationCoordinate2D) throws -> [TAF] {
        let decoder = JSONDecoder()

        let tafResponses: [TAFAPIResponse]
        do {
            tafResponses = try decoder.decode([TAFAPIResponse].self, from: data)
        } catch {
            print("TAF parsing error: \(error)")
            throw TAFError.parsingError
        }

        return tafResponses.compactMap { response -> TAF? in
            guard let stationId = response.icaoId,
                  let rawTAF = response.rawTAF else {
                return nil
            }

            // Parse issue time
            let issueTime: Date
            if let issueTimeStr = response.issueTime {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                issueTime = formatter.date(from: issueTimeStr) ?? Date()
            } else {
                issueTime = Date()
            }

            // Convert Unix timestamps to Date
            let validFrom = response.validTimeFrom.map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? Date()
            let validTo = response.validTimeTo.map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? Date()

            // Parse forecast periods
            let forecastPeriods = parseForecastPeriods(from: response.fcsts)

            return TAF(
                id: "\(stationId)-\(validFrom.timeIntervalSince1970)",
                stationId: stationId,
                stationName: response.name,
                rawTAF: rawTAF,
                issueTime: issueTime,
                validFrom: validFrom,
                validTo: validTo,
                latitude: response.lat ?? userCoordinate.latitude,
                longitude: response.lon ?? userCoordinate.longitude,
                elevation: response.elev,
                forecastPeriods: forecastPeriods
            )
        }
    }

    private func parseForecastPeriods(from forecasts: [TAFForecastAPIResponse]?) -> [TAFForecastPeriod] {
        guard let forecasts = forecasts else { return [] }

        return forecasts.compactMap { fcst -> TAFForecastPeriod? in
            guard let timeFromUnix = fcst.timeFrom,
                  let timeToUnix = fcst.timeTo else {
                return nil
            }

            let timeFrom = Date(timeIntervalSince1970: TimeInterval(timeFromUnix))
            let timeTo = Date(timeIntervalSince1970: TimeInterval(timeToUnix))

            // Parse change type
            let changeType: TAFChangeType?
            if let change = fcst.fcstChange {
                changeType = TAFChangeType(rawValue: change)
            } else {
                changeType = nil
            }

            // Parse clouds
            let clouds = parseClouds(from: fcst.clouds)

            return TAFForecastPeriod(
                timeFrom: timeFrom,
                timeTo: timeTo,
                changeType: changeType,
                probability: fcst.probability,
                windDirection: fcst.wdir?.value,
                windSpeed: fcst.wspd,
                windGust: fcst.wgst,
                visibility: fcst.visib?.value,
                weatherPhenomena: fcst.wxString,
                clouds: clouds,
                verticalVisibility: fcst.vertVis
            )
        }
    }

    private func parseClouds(from cloudArray: [METARCloudResponse]?) -> [CloudLayer] {
        guard let clouds = cloudArray else { return [] }

        return clouds.compactMap { cloud -> CloudLayer? in
            guard let coverString = cloud.cover else { return nil }

            let cover: CloudCover
            switch coverString.uppercased() {
            case "SKC": cover = .skc
            case "CLR": cover = .clr
            case "FEW": cover = .few
            case "SCT": cover = .sct
            case "BKN": cover = .bkn
            case "OVC": cover = .ovc
            case "VV": cover = .vv
            default: return nil
            }

            return CloudLayer(cover: cover, base: cloud.base)
        }
    }

    /// Clear the cache to force a fresh fetch
    func clearCache() {
        lastFetchTime = nil
        lastFetchCoordinate = nil
        nearbyTAFs = []
    }
}

// MARK: - TAF Error

enum TAFError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case parsingError
    case noDataAvailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for TAF request"
        case .invalidResponse:
            return "Invalid response from aviation weather service"
        case .httpError(let statusCode):
            return "HTTP error \(statusCode) from aviation weather service"
        case .parsingError:
            return "Error parsing TAF data"
        case .noDataAvailable:
            return "No TAF data available for this location"
        }
    }
}

// MARK: - API Response Models

struct TAFAPIResponse: Codable {
    let icaoId: String?
    let name: String?
    let rawTAF: String?
    let issueTime: String?
    let validTimeFrom: Int?
    let validTimeTo: Int?
    let lat: Double?
    let lon: Double?
    let elev: Int?
    let mostRecent: Int?
    let remarks: String?
    let fcsts: [TAFForecastAPIResponse]?
}

struct TAFForecastAPIResponse: Codable {
    let timeFrom: Int?
    let timeTo: Int?
    let fcstChange: String?
    let probability: Int?
    let wdir: FlexibleInt?
    let wspd: Int?
    let wgst: Int?
    let visib: FlexibleDouble?
    let wxString: String?
    let vertVis: Int?
    let clouds: [METARCloudResponse]?
    let icgTurb: [TAFIcgTurbResponse]?
    let temp: [TAFTempResponse]?
}

struct TAFIcgTurbResponse: Codable {}

struct TAFTempResponse: Codable {}
