//
//  FlightRadar24Service.swift
//  Buzz
//
//  Service for querying FlightRadar24 API for live commercial/GA flight data
//

import Foundation
import MapKit
import Combine

// MARK: - Error Types

enum FR24Error: LocalizedError {
    case invalidURL
    case invalidResponse(statusCode: Int)
    case unauthorized
    case rateLimited
    case creditsExhausted
    case decodingError(String)
    case zoomInRequired

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse(let code):
            return "Server returned status \(code)"
        case .unauthorized:
            return "Invalid API token. Check Config.fr24APIToken."
        case .rateLimited:
            return "Rate limited. Please wait before retrying."
        case .creditsExhausted:
            return "FR24 API credits exhausted."
        case .decodingError(let detail):
            return "Failed to decode response: \(detail)"
        case .zoomInRequired:
            return "Zoom in to see flights"
        }
    }
}

// MARK: - FlightRadar24 Service

@MainActor
class FlightRadar24Service: ObservableObject {
    @Published var flights: [FR24FlightPosition] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let baseURL = "https://fr24api.flightradar24.com"

    // Caching
    private var lastFetchRegion: MKCoordinateRegion?
    private var lastFetchTime: Date?
    private let cacheValiditySeconds: TimeInterval = 8

    // Limits
    private let maxDisplayFlights = 200
    private let maxMapSpan: Double = 10.0 // degrees latitude

    // MARK: - Fetch Live Flights (Light endpoint for map refresh — cheaper)

    func fetchFlights(region: MKCoordinateRegion, force: Bool = false) async {
        // Demo mode
        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 300_000_000)
            self.flights = Self.sampleFlights()
            self.isLoading = false
            self.errorMessage = nil
            return
        }

        // Check if too zoomed out
        if region.span.latitudeDelta > maxMapSpan {
            self.flights = []
            self.isLoading = false
            self.errorMessage = "Zoom in to see flights"
            return
        }

        // Check cache
        if !force,
           let lastRegion = lastFetchRegion,
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheValiditySeconds,
           !regionShiftedSignificantly(from: lastRegion, to: region) {
            return // Use cached data
        }

        isLoading = true
        errorMessage = nil

        do {
            let boundsString = buildBoundsString(region: region)

            // Use /light endpoint for periodic map refresh (cheaper)
            var components = URLComponents(string: "\(baseURL)/api/live/flight-positions/light")!
            components.queryItems = [
                URLQueryItem(name: "bounds", value: boundsString),
                URLQueryItem(name: "limit", value: "\(maxDisplayFlights)")
            ]

            let apiResponse: FR24FlightPositionsResponse = try await performRequest(components: components)

            self.flights = apiResponse.data
            self.lastFetchRegion = region
            self.lastFetchTime = Date()
            self.isLoading = false
            self.errorMessage = nil

        } catch let error as FR24Error {
            self.isLoading = false
            self.errorMessage = error.errorDescription
            print("FR24 API error: \(error.errorDescription ?? "Unknown")")
        } catch let decodingError as DecodingError {
            self.isLoading = false
            self.errorMessage = "Failed to parse flight data"
            print("FR24 decoding error: \(decodingError)")
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            print("FR24 fetch error: \(error.localizedDescription)")
        }
    }

    // MARK: - Fetch Flight Details (Full endpoint — on tap only)

    func fetchFlightDetails(fr24Id: String) async -> FR24FlightPosition? {
        if DemoModeManager.shared.isDemoModeEnabled {
            return flights.first { $0.fr24Id == fr24Id }
        }

        do {
            var components = URLComponents(string: "\(baseURL)/api/live/flight-positions/full")!
            components.queryItems = [
                URLQueryItem(name: "flights", value: fr24Id)
            ]

            let apiResponse: FR24FlightPositionsResponse = try await performRequest(components: components)
            return apiResponse.data.first
        } catch {
            print("FR24 detail fetch error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Shared Request Logic

    private func performRequest<T: Decodable>(components: URLComponents) async throws -> T {
        guard let url = components.url else {
            throw FR24Error.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(Config.fr24APIToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FR24Error.invalidResponse(statusCode: 0)
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw FR24Error.unauthorized
        case 402:
            throw FR24Error.creditsExhausted
        case 429:
            throw FR24Error.rateLimited
        default:
            throw FR24Error.invalidResponse(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Helpers

    private func buildBoundsString(region: MKCoordinateRegion) -> String {
        let north = region.center.latitude + region.span.latitudeDelta / 2
        let south = region.center.latitude - region.span.latitudeDelta / 2
        let west = region.center.longitude - region.span.longitudeDelta / 2
        let east = region.center.longitude + region.span.longitudeDelta / 2
        return "\(north),\(south),\(west),\(east)"
    }

    private func regionShiftedSignificantly(from oldRegion: MKCoordinateRegion, to newRegion: MKCoordinateRegion) -> Bool {
        let latShift = abs(newRegion.center.latitude - oldRegion.center.latitude)
        let lonShift = abs(newRegion.center.longitude - oldRegion.center.longitude)
        let latThreshold = oldRegion.span.latitudeDelta * 0.2
        let lonThreshold = oldRegion.span.longitudeDelta * 0.2
        let latSpanShift = abs(newRegion.span.latitudeDelta - oldRegion.span.latitudeDelta)
        let lonSpanShift = abs(newRegion.span.longitudeDelta - oldRegion.span.longitudeDelta)
        let latSpanThreshold = max(oldRegion.span.latitudeDelta * 0.15, 0.05)
        let lonSpanThreshold = max(oldRegion.span.longitudeDelta * 0.15, 0.05)

        return latShift > latThreshold ||
            lonShift > lonThreshold ||
            latSpanShift > latSpanThreshold ||
            lonSpanShift > lonSpanThreshold
    }

    // MARK: - Demo Mode Sample Data

    private static func sampleFlights() -> [FR24FlightPosition] {
        [
            FR24FlightPosition(
                fr24Id: "3a1b2c3d", lat: 37.78, lon: -122.42, track: 270, alt: 35000, gspeed: 450, vspeed: 0,
                squawk: "1200", timestamp: "2025-01-01T12:00:00Z", source: "ADSB", hex: "A1B2C3",
                callsign: "AAL100", flight: "AA100", type: "B738", reg: "N12345",
                paintedAs: "AAL", operatingAs: "AAL",
                origIata: "JFK", origIcao: "KJFK", destIata: "SFO", destIcao: "KSFO", eta: nil
            ),
            FR24FlightPosition(
                fr24Id: "4d5e6f7g", lat: 37.62, lon: -122.38, track: 180, alt: 28000, gspeed: 420, vspeed: -1200,
                squawk: "2345", timestamp: "2025-01-01T12:00:00Z", source: "ADSB", hex: "D4E5F6",
                callsign: "UAL456", flight: "UA456", type: "A320", reg: "N67890",
                paintedAs: "UAL", operatingAs: "UAL",
                origIata: "LAX", origIcao: "KLAX", destIata: "SFO", destIcao: "KSFO", eta: nil
            ),
            FR24FlightPosition(
                fr24Id: "7h8i9j0k", lat: 37.85, lon: -122.25, track: 45, alt: 38000, gspeed: 480, vspeed: 500,
                squawk: "3456", timestamp: "2025-01-01T12:00:00Z", source: "ADSB", hex: "G7H8I9",
                callsign: "DAL789", flight: "DL789", type: "B772", reg: "N33456",
                paintedAs: "DAL", operatingAs: "DAL",
                origIata: "ATL", origIcao: "KATL", destIata: "SEA", destIcao: "KSEA", eta: nil
            ),
            FR24FlightPosition(
                fr24Id: "1l2m3n4o", lat: 37.55, lon: -122.10, track: 315, alt: 12000, gspeed: 280, vspeed: -800,
                squawk: "4567", timestamp: "2025-01-01T12:00:00Z", source: "ADSB", hex: "J0K1L2",
                callsign: "SWA321", flight: "WN321", type: "B737", reg: "N44567",
                paintedAs: "SWA", operatingAs: "SWA",
                origIata: "PHX", origIcao: "KPHX", destIata: "OAK", destIcao: "KOAK", eta: nil
            ),
            FR24FlightPosition(
                fr24Id: "5p6q7r8s", lat: 37.70, lon: -122.50, track: 90, alt: 41000, gspeed: 510, vspeed: 0,
                squawk: "5678", timestamp: "2025-01-01T12:00:00Z", source: "ADSB", hex: "M3N4O5",
                callsign: "BAW287", flight: "BA287", type: "B789", reg: "G-ZBKM",
                paintedAs: "BAW", operatingAs: "BAW",
                origIata: "LHR", origIcao: "EGLL", destIata: "SFO", destIcao: "KSFO", eta: nil
            )
        ]
    }
}
