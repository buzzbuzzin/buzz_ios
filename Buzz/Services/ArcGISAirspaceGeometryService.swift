//
//  ArcGISAirspaceGeometryService.swift
//  Buzz
//
//  Queries ArcGIS Class Airspace endpoint for polygon boundaries
//

import Foundation
import CoreLocation
import MapKit
import Combine

// MARK: - ArcGIS Geometry Response Models

struct ArcGISGeometryQueryResponse: Codable {
    let features: [ArcGISGeometryFeature]?
}

struct ArcGISGeometryFeature: Codable {
    let attributes: [String: ArcGISAttributeValue]
    let geometry: ArcGISPolygonGeometry?
}

struct ArcGISPolygonGeometry: Codable {
    let rings: [[[Double]]]  // rings[i] = array of [lon, lat] points
}

// MARK: - Airspace Overlay Polygon

class AirspaceOverlayPolygon: MKPolygon {
    var airspaceClass: AirspaceClass = .unknown
    var airspaceName: String?
}

// MARK: - ArcGIS Airspace Geometry Service

@MainActor
class ArcGISAirspaceGeometryService: ObservableObject {
    @Published var isLoading = false

    private let baseURL = "https://services6.arcgis.com/ssFJjBXIUyZDrSYZ/ArcGIS/rest/services/Class_Airspace/FeatureServer/0/query"

    // Cache
    private var cachedRegion: MKCoordinateRegion?
    private var cachedPolygons: [AirspaceOverlayPolygon] = []
    private let cacheThreshold: Double = 0.1 // re-fetch if panned > this many degrees

    /// Fetch airspace polygon geometries within the visible map region
    func fetchAirspacePolygons(for region: MKCoordinateRegion) async throws -> [AirspaceOverlayPolygon] {
        // Check cache - skip if region hasn't shifted much
        if let cached = cachedRegion,
           abs(cached.center.latitude - region.center.latitude) < cacheThreshold,
           abs(cached.center.longitude - region.center.longitude) < cacheThreshold,
           abs(cached.span.latitudeDelta - region.span.latitudeDelta) < cacheThreshold,
           !cachedPolygons.isEmpty {
            return cachedPolygons
        }

        isLoading = true
        defer { isLoading = false }

        // Build bounding box envelope
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2

        let envelope = """
        {"xmin":\(minLon),"ymin":\(minLat),"xmax":\(maxLon),"ymax":\(maxLat),"spatialReference":{"wkid":4326}}
        """

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "geometry", value: envelope),
            URLQueryItem(name: "geometryType", value: "esriGeometryEnvelope"),
            URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
            URLQueryItem(name: "outFields", value: "CLASS,LOWER_VAL,UPPER_VAL,LOCAL_TYPE,NAME"),
            URLQueryItem(name: "where", value: "CLASS IN ('B','C','D','E')"),
            URLQueryItem(name: "returnGeometry", value: "true"),
            URLQueryItem(name: "outSR", value: "4326"),
            URLQueryItem(name: "resultRecordCount", value: "200"),
            URLQueryItem(name: "f", value: "json")
        ]

        guard let url = components.url else {
            throw ArcGISError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ArcGISError.invalidResponse
        }

        let queryResponse = try JSONDecoder().decode(ArcGISGeometryQueryResponse.self, from: data)

        guard let features = queryResponse.features else {
            cachedRegion = region
            cachedPolygons = []
            return []
        }

        // Convert features to MKPolygon overlays
        var polygons: [AirspaceOverlayPolygon] = []

        for feature in features {
            guard let geometry = feature.geometry else { continue }

            // Parse airspace class
            let classString = feature.attributes["CLASS"]?.stringValue ?? ""
            let airspaceClass = parseAirspaceClass(classString)
            let name = feature.attributes["NAME"]?.stringValue

            // Process each ring set
            for ring in geometry.rings {
                guard ring.count >= 3 else { continue }

                // ArcGIS returns [lon, lat] pairs
                var coordinates = ring.compactMap { point -> CLLocationCoordinate2D? in
                    guard point.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: point[1], longitude: point[0])
                }

                guard coordinates.count >= 3 else { continue }

                // Create MKPolygon
                let polygon = AirspaceOverlayPolygon(coordinates: &coordinates, count: coordinates.count)
                polygon.airspaceClass = airspaceClass
                polygon.airspaceName = name
                polygons.append(polygon)
            }
        }

        cachedRegion = region
        cachedPolygons = polygons
        return polygons
    }

    /// Clear cached data
    func clearCache() {
        cachedRegion = nil
        cachedPolygons = []
    }

    // MARK: - Private

    private func parseAirspaceClass(_ value: String) -> AirspaceClass {
        // Exact match against known codes; substring matching misclassifies "CLASS_B" as C, etc.
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch normalized {
        case "B", "BRAVO", "CLASS B", "CLASS_B": return .classB
        case "C", "CHARLIE", "CLASS C", "CLASS_C": return .classC
        case "D", "DELTA", "CLASS D", "CLASS_D": return .classD
        case "E", "ECHO", "CLASS E", "CLASS_E": return .classE
        case "G", "GOLF", "CLASS G", "CLASS_G": return .classG
        default: return .unknown
        }
    }
}
