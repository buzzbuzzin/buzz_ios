//
//  ArcGISAirspaceService.swift
//  Buzz
//
//  Service for querying FAA airspace classification and LAANC grid data
//

import Foundation
import CoreLocation
import Combine

// MARK: - ArcGIS Response Models

struct AirspaceQuerySnapshot: Equatable {
    let airspaceClass: AirspaceClass
    let laancGridCeiling: Int?
    let hasLAANCCoverage: Bool

    static let unavailable = AirspaceQuerySnapshot(
        airspaceClass: .unknown,
        laancGridCeiling: nil,
        hasLAANCCoverage: false
    )
}

struct ArcGISQueryResponse: Codable {
    let features: [ArcGISFeature]
}

struct ArcGISFeature: Codable {
    let attributes: [String: ArcGISAttributeValue]
}

enum ArcGISAttributeValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
            return
        }
        if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
            return
        }
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let value): return value
        default: return nil
        }
    }

    var intValue: Int? {
        switch self {
        case .int(let value): return value
        case .double(let value): return Int(value)
        default: return nil
        }
    }
}

// MARK: - ArcGIS Airspace Service

@MainActor
class ArcGISAirspaceService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var airspaceClass: AirspaceClass = .unknown
    @Published var laancGridCeiling: Int?
    @Published var hasLAANCCoverage: Bool = false  // NEW: Indicates if UASFM grid exists at location
    @Published var authorizationStatus: LAANCAuthorizationStatus = .pending

    // ArcGIS Feature Server endpoints
    private let classAirspaceBaseURL = "https://services6.arcgis.com/ssFJjBXIUyZDrSYZ/ArcGIS/rest/services/Class_Airspace/FeatureServer/0/query"
    private let laancGridBaseURL = "https://services6.arcgis.com/ssFJjBXIUyZDrSYZ/ArcGIS/rest/services/FAA_UAS_FacilityMap_Data/FeatureServer/0/query"

    // Cache
    private var lastFetchCoordinate: CLLocationCoordinate2D?
    private var lastFetchTime: Date?
    private var cachedSnapshot: AirspaceQuerySnapshot?
    private let cacheValiditySeconds: TimeInterval = 300 // 5 minutes

    // MARK: - Public Methods

    /// Fetch airspace data using two-step sequential logic:
    /// Step 1: Query UASFM (LAANC grid) first for ceiling
    /// Step 2: If no UASFM data, query Class Airspace to determine if manual auth needed
    func fetchAirspaceData(coordinate: CLLocationCoordinate2D) async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await fetchAirspaceSnapshot(coordinate: coordinate, persistResult: true)
            apply(snapshot: snapshot)
            isLoading = false
        } catch {
            apply(snapshot: .unavailable)
            authorizationStatus = .pending
            isLoading = false
            errorMessage = error.localizedDescription
            print("ArcGIS fetch error: \(error.localizedDescription)")
        }
    }

    func fetchAirspaceSnapshot(
        coordinate: CLLocationCoordinate2D,
        persistResult: Bool = false
    ) async throws -> AirspaceQuerySnapshot {
        if let cachedSnapshot, isCacheValid(for: coordinate) {
            return cachedSnapshot
        }

        let fetchedCeiling = try await fetchLAANCGridCeiling(coordinate: coordinate)
        let fetchedAirspaceClass = try await fetchAirspaceClass(coordinate: coordinate)
        let snapshot = AirspaceQuerySnapshot(
            airspaceClass: fetchedAirspaceClass,
            laancGridCeiling: fetchedCeiling,
            hasLAANCCoverage: fetchedCeiling != nil
        )

        if persistResult {
            cache(snapshot: snapshot, coordinate: coordinate)
        }

        return snapshot
    }

    /// Fetch airspace class for given coordinates
    func fetchAirspaceClass(coordinate: CLLocationCoordinate2D) async throws -> AirspaceClass {
        let geometry = "{\"x\":\(coordinate.longitude),\"y\":\(coordinate.latitude),\"spatialReference\":{\"wkid\":4326}}"

        var components = URLComponents(string: classAirspaceBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "geometry", value: geometry),
            URLQueryItem(name: "geometryType", value: "esriGeometryPoint"),
            URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
            URLQueryItem(name: "outFields", value: "CLASS,LOWER_VAL,UPPER_VAL"),
            URLQueryItem(name: "returnGeometry", value: "false"),
            URLQueryItem(name: "f", value: "json")
        ]

        guard let url = components.url else {
            throw ArcGISError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ArcGISError.invalidResponse
        }

        let queryResponse = try JSONDecoder().decode(ArcGISQueryResponse.self, from: data)

        // Find the most restrictive airspace class (B > C > D > E > G)
        var mostRestrictive: AirspaceClass = .classG

        for feature in queryResponse.features {
            if let classValue = feature.attributes["CLASS"]?.stringValue {
                let airspace = parseAirspaceClass(classValue)
                if airspaceRestrictiveness(airspace) > airspaceRestrictiveness(mostRestrictive) {
                    mostRestrictive = airspace
                }
            }
        }

        return mostRestrictive
    }

    /// Fetch LAANC grid ceiling for given coordinates
    func fetchLAANCGridCeiling(coordinate: CLLocationCoordinate2D) async throws -> Int? {
        let geometry = "{\"x\":\(coordinate.longitude),\"y\":\(coordinate.latitude),\"spatialReference\":{\"wkid\":4326}}"

        var components = URLComponents(string: laancGridBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "geometry", value: geometry),
            URLQueryItem(name: "geometryType", value: "esriGeometryPoint"),
            URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
            URLQueryItem(name: "outFields", value: "CEILING"),
            URLQueryItem(name: "returnGeometry", value: "false"),
            URLQueryItem(name: "f", value: "json")
        ]

        guard let url = components.url else {
            throw ArcGISError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ArcGISError.invalidResponse
        }

        let queryResponse = try JSONDecoder().decode(ArcGISQueryResponse.self, from: data)

        // Get the LAANC ceiling value
        for feature in queryResponse.features {
            if let ceiling = feature.attributes["CEILING"]?.intValue {
                return ceiling
            }
        }

        return nil // Not in LAANC grid
    }

    /// Calculate LAANC authorization status based on altitude, airspace, and LAANC coverage
    /// Uses the two-step logic:
    /// - Step 1: If LAANC coverage exists, use ceiling for auto-approval threshold
    /// - Step 2: If no LAANC coverage, check if in controlled airspace (requires manual auth)
    func calculateAuthorizationStatus(
        requestedAltitude: Int,
        laancCeiling: Int?,
        airspaceClass: AirspaceClass,
        hasLAANCCoverage: Bool
    ) -> LAANCAuthorizationStatus {
        // Rule 1: Above 400 ft AGL is never permitted under Part 107
        if requestedAltitude > 400 {
            return .notPermitted
        }

        // Rule 2: Class G (uncontrolled) airspace - no authorization needed
        if airspaceClass == .classG || airspaceClass == .unknown {
            return .notApplicable  // Safe to fly under Part 107 rules
        }

        // Rule 3: Controlled airspace (B, C, D, E)
        // Check if LAANC coverage exists at this location
        if !hasLAANCCoverage || laancCeiling == nil {
            // Controlled airspace WITHOUT LAANC auto-approval available
            // Pilot must use manual FAA DroneZone authorization
            return .noLAANCCoverage
        }

        // Rule 4: LAANC coverage exists - check against ceiling
        guard let ceiling = laancCeiling else {
            return .noLAANCCoverage
        }

        // Zero ceiling = no automatic authorization at this grid cell
        if ceiling == 0 {
            return .noLAANCCoverage
        }

        if requestedAltitude <= ceiling {
            // Within LAANC auto-approval ceiling
            return .autoApproved
        } else {
            // Above LAANC ceiling but ≤ 400 ft
            // Manual review required for this altitude
            return .manualReviewRequired
        }
    }

    /// Legacy method for backwards compatibility - uses instance hasLAANCCoverage
    func calculateAuthorizationStatus(
        requestedAltitude: Int,
        laancCeiling: Int?,
        airspaceClass: AirspaceClass
    ) -> LAANCAuthorizationStatus {
        return calculateAuthorizationStatus(
            requestedAltitude: requestedAltitude,
            laancCeiling: laancCeiling,
            airspaceClass: airspaceClass,
            hasLAANCCoverage: self.hasLAANCCoverage
        )
    }

    /// Update authorization status with current values
    func updateAuthorizationStatus(requestedAltitude: Int) {
        authorizationStatus = calculateAuthorizationStatus(
            requestedAltitude: requestedAltitude,
            laancCeiling: laancGridCeiling,
            airspaceClass: airspaceClass,
            hasLAANCCoverage: hasLAANCCoverage
        )
    }

    // MARK: - Private Helpers

    private func isCacheValid(for coordinate: CLLocationCoordinate2D) -> Bool {
        guard let lastCoord = lastFetchCoordinate,
              let lastTime = lastFetchTime,
              let cachedSnapshot else {
            return false
        }

        let isFresh = Date().timeIntervalSince(lastTime) < cacheValiditySeconds
        let isSameCoordinate =
            abs(lastCoord.latitude - coordinate.latitude) < 0.0001 &&
            abs(lastCoord.longitude - coordinate.longitude) < 0.0001

        return isFresh && isSameCoordinate && cachedSnapshot != .unavailable
    }

    private func cache(snapshot: AirspaceQuerySnapshot, coordinate: CLLocationCoordinate2D) {
        cachedSnapshot = snapshot
        lastFetchCoordinate = coordinate
        lastFetchTime = Date()
    }

    private func apply(snapshot: AirspaceQuerySnapshot) {
        airspaceClass = snapshot.airspaceClass
        laancGridCeiling = snapshot.laancGridCeiling
        hasLAANCCoverage = snapshot.hasLAANCCoverage
    }

    private func parseAirspaceClass(_ value: String) -> AirspaceClass {
        let uppercased = value.uppercased()
        if uppercased.contains("B") { return .classB }
        if uppercased.contains("C") { return .classC }
        if uppercased.contains("D") { return .classD }
        if uppercased.contains("E") { return .classE }
        if uppercased.contains("G") { return .classG }
        return .unknown
    }

    private func airspaceRestrictiveness(_ airspace: AirspaceClass) -> Int {
        switch airspace {
        case .classB: return 5
        case .classC: return 4
        case .classD: return 3
        case .classE: return 2
        case .classG: return 1
        case .unknown: return 0
        }
    }
}

// MARK: - Errors

enum ArcGISError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid ArcGIS URL"
        case .invalidResponse:
            return "Invalid response from ArcGIS server"
        case .decodingError:
            return "Failed to decode ArcGIS response"
        }
    }
}
