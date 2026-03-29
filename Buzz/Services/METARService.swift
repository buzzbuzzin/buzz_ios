//
//  METARService.swift
//  Buzz
//
//  Created by Xinyu Fang on 1/27/26.
//

import Foundation
import CoreLocation
import Combine

@MainActor
class METARService: ObservableObject {
    @Published var nearbyMETARs: [METAR] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let baseURL = "https://aviationweather.gov/api/data"
    
    // Cache to avoid excessive API calls
    private var lastFetchTime: Date?
    private var lastFetchCoordinate: CLLocationCoordinate2D?
    private var lastFetchRadiusDegrees: Double?
    private var lastFetchMaxResults: Int?
    private var inFlightCoordinate: CLLocationCoordinate2D?
    private var inFlightRadiusDegrees: Double?
    private var inFlightMaxResults: Int?
    private let cacheValiditySeconds: TimeInterval = 300 // 5 minutes
    
    // MARK: - Fetch METARs Near Location
    
    /// Fetches METAR reports for airports near the given coordinate
    /// - Parameters:
    ///   - coordinate: The center point for the search
    ///   - radiusDegrees: The search radius in degrees (default 0.5 = ~55km)
    /// - Returns: Array of METAR reports sorted by distance
    func fetchMETARsNearLocation(
        coordinate: CLLocationCoordinate2D,
        radiusDegrees: Double = 0.5,
        maxResults: Int = 5,
        forceRefresh: Bool = false
    ) async throws -> [METAR] {
        // Check cache validity
        if !forceRefresh,
           let lastTime = lastFetchTime,
           let lastCoord = lastFetchCoordinate,
           let lastRadius = lastFetchRadiusDegrees,
           let lastMaxResults = lastFetchMaxResults,
           Date().timeIntervalSince(lastTime) < cacheValiditySeconds {
            let latDiff = abs(lastCoord.latitude - coordinate.latitude)
            let lonDiff = abs(lastCoord.longitude - coordinate.longitude)
            let radiusDiff = abs(lastRadius - radiusDegrees)
            if latDiff < 0.01 &&
                lonDiff < 0.01 &&
                radiusDiff < 0.001 &&
                lastMaxResults == maxResults &&
                !nearbyMETARs.isEmpty {
                return nearbyMETARs
            }
        }

        // Prevent duplicate concurrent requests for the same location
        if isLoading,
           let requestedCoord = inFlightCoordinate,
           let requestedRadius = inFlightRadiusDegrees,
           let requestedMaxResults = inFlightMaxResults {
            let latDiff = abs(requestedCoord.latitude - coordinate.latitude)
            let lonDiff = abs(requestedCoord.longitude - coordinate.longitude)
            let radiusDiff = abs(requestedRadius - radiusDegrees)
            if latDiff < 0.01 &&
                lonDiff < 0.01 &&
                radiusDiff < 0.001 &&
                requestedMaxResults == maxResults {
                return nearbyMETARs
            }
        }

        isLoading = true
        inFlightCoordinate = coordinate
        inFlightRadiusDegrees = radiusDegrees
        inFlightMaxResults = maxResults
        errorMessage = nil
        defer {
            isLoading = false
            inFlightCoordinate = nil
            inFlightRadiusDegrees = nil
            inFlightMaxResults = nil
        }

        do {
            // Calculate bounding box
            let minLat = coordinate.latitude - radiusDegrees
            let maxLat = coordinate.latitude + radiusDegrees
            let minLon = coordinate.longitude - radiusDegrees
            let maxLon = coordinate.longitude + radiusDegrees
            
            // Build URL with bbox parameter
            let urlString = "\(baseURL)/metar?bbox=\(minLat),\(minLon),\(maxLat),\(maxLon)&format=json&hours=2"
            
            guard let url = URL(string: urlString) else {
                throw METARError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 15
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw METARError.invalidResponse
            }
            
            // Handle 204 No Content - valid but no data available
            if httpResponse.statusCode == 204 {
                nearbyMETARs = []
                lastFetchTime = Date()
                lastFetchCoordinate = coordinate
                lastFetchRadiusDegrees = radiusDegrees
                lastFetchMaxResults = maxResults
                return []
            }
            
            guard httpResponse.statusCode == 200 else {
                throw METARError.httpError(statusCode: httpResponse.statusCode)
            }
            
            // Parse the JSON response
            let metars = try parseMETARResponse(data: data, userCoordinate: coordinate)
            
            // Sort by distance and limit to closest results
            let sortedMETARs = metars
                .sorted { $0.distance(from: coordinate) < $1.distance(from: coordinate) }
                .prefix(maxResults)
            
            nearbyMETARs = Array(sortedMETARs)
            lastFetchTime = Date()
            lastFetchCoordinate = coordinate
            lastFetchRadiusDegrees = radiusDegrees
            lastFetchMaxResults = maxResults

            return nearbyMETARs

        } catch {
            // Handle cancellation gracefully
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return nearbyMETARs
            }
            
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Parse METAR Response
    
    private func parseMETARResponse(data: Data, userCoordinate: CLLocationCoordinate2D) throws -> [METAR] {
        let decoder = JSONDecoder()
        
        // The API returns an array of METAR objects
        let metarResponses: [METARAPIResponse]
        do {
            metarResponses = try decoder.decode([METARAPIResponse].self, from: data)
        } catch {
            print("METAR parsing error: \(error)")
            throw METARError.parsingError
        }
        
        // Convert API responses to METAR models
        return Self.selectFreshestResponses(metarResponses).compactMap { response -> METAR? in
            guard let stationId = response.icaoId,
                  let rawText = response.rawOb else {
                return nil
            }
            
            // Parse observation time
            let observationTime: Date
            if let reportTime = response.reportTime {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                observationTime = formatter.date(from: reportTime) ?? Date()
            } else {
                observationTime = Date()
            }
            
            // Parse clouds
            let clouds = parseClouds(from: response.clouds)
            
            // Parse flight category
            let flightCategory: FlightCategory
            if let fltCat = response.fltCat {
                flightCategory = FlightCategory(rawValue: fltCat) ?? .unknown
            } else {
                flightCategory = .unknown
            }
            
            return METAR(
                id: "\(stationId)-\(observationTime.timeIntervalSince1970)",
                stationId: stationId,
                stationName: response.name,
                rawText: rawText,
                observationTime: observationTime,
                latitude: response.lat ?? userCoordinate.latitude,
                longitude: response.lon ?? userCoordinate.longitude,
                temperature: response.temp,
                dewpoint: response.dewp,
                windDirection: response.wdir?.value,
                windSpeed: response.wspd,
                windGust: response.wgst,
                visibility: response.visib?.value,
                altimeter: response.altim,
                flightCategory: flightCategory,
                clouds: clouds,
                weatherPhenomena: response.wxString
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
    
    /// Clear the fetch cache to force a fresh request.
    /// By default this preserves the currently displayed METARs so pull-to-refresh
    /// does not blank the UI before replacement data arrives.
    func clearCache(keepDisplayedMETARs: Bool = true) {
        lastFetchTime = nil
        lastFetchCoordinate = nil
        lastFetchRadiusDegrees = nil
        lastFetchMaxResults = nil
        errorMessage = nil
        if !keepDisplayedMETARs {
            nearbyMETARs = []
        }
    }

    nonisolated static func selectFreshestResponses(_ responses: [METARAPIResponse]) -> [METARAPIResponse] {
        let groupedResponses = Dictionary(grouping: responses) { response in
            response.icaoId ?? UUID().uuidString
        }

        return groupedResponses.values.compactMap { stationResponses in
            stationResponses.max { lhs, rhs in
                parseReportTime(lhs.reportTime) < parseReportTime(rhs.reportTime)
            }
        }
    }

    nonisolated private static func parseReportTime(_ reportTimeString: String?) -> Date {
        guard let reportTimeString, !reportTimeString.isEmpty else { return .distantPast }

        let formatterWithFractionalSeconds = ISO8601DateFormatter()
        formatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsedDate = formatterWithFractionalSeconds.date(from: reportTimeString) {
            return parsedDate
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: reportTimeString) ?? .distantPast
    }
}

// MARK: - METAR Error

enum METARError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case parsingError
    case noDataAvailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for METAR request"
        case .invalidResponse:
            return "Invalid response from aviation weather service"
        case .httpError(let statusCode):
            return "HTTP error \(statusCode) from aviation weather service"
        case .parsingError:
            return "Error parsing METAR data"
        case .noDataAvailable:
            return "No METAR data available for this location"
        }
    }
}

// MARK: - API Response Models

struct METARAPIResponse: Codable {
    let icaoId: String?
    let name: String?
    let rawOb: String?
    let reportTime: String?
    let lat: Double?
    let lon: Double?
    let temp: Double?
    let dewp: Double?
    let wdir: FlexibleInt?
    let wspd: Int?
    let wgst: Int?
    let visib: FlexibleDouble?
    let altim: Double?
    let fltCat: String?
    let clouds: [METARCloudResponse]?
    let wxString: String?
}

struct METARCloudResponse: Codable {
    let cover: String?
    let base: Int?
}

// MARK: - Flexible Decodable Types

/// A type that can decode either a Double or a String representation of a number
struct FlexibleDouble: Codable {
    let value: Double?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let doubleValue = try? container.decode(Double.self) {
            self.value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            // Handle strings like "10+", "P6SM", etc.
            let cleaned = stringValue.replacingOccurrences(of: "+", with: "")
                .replacingOccurrences(of: "SM", with: "")
                .replacingOccurrences(of: "P", with: "")
                .trimmingCharacters(in: .whitespaces)
            self.value = Double(cleaned)
        } else {
            self.value = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

/// A type that can decode either an Int or a String representation (e.g., "VRB" for variable wind)
struct FlexibleInt: Codable {
    let value: Int?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self.value = intValue
        } else if let stringValue = try? container.decode(String.self) {
            // Handle strings like "VRB" for variable wind direction
            self.value = Int(stringValue)
        } else {
            self.value = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
