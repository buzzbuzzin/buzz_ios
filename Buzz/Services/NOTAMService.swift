//
//  NOTAMService.swift
//  Buzz
//
//  Created for NOTAM feature implementation
//

import Foundation
import CoreLocation
import Combine
import Supabase

@MainActor
class NOTAMService: ObservableObject {
    @Published var nearbyNOTAMs: [NOTAM] = []
    @Published var nearbyAirports: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    
    // Cache to avoid excessive API calls
    private var lastFetchTime: Date?
    private var lastFetchCoordinate: CLLocationCoordinate2D?
    private let cacheValiditySeconds: TimeInterval = 300 // 5 minutes
    
    // MARK: - Fetch NOTAMs Near Location
    
    /// Fetches NOTAMs for airports near the given coordinate
    /// - Parameters:
    ///   - coordinate: The center point for the search
    ///   - radiusDegrees: The search radius in degrees (default 0.5 = ~55km)
    /// - Returns: Array of NOTAM reports
    func fetchNOTAMsNearLocation(
        coordinate: CLLocationCoordinate2D,
        radiusDegrees: Double = 0.5
    ) async throws -> [NOTAM] {
        // Check cache validity
        if let lastTime = lastFetchTime,
           let lastCoord = lastFetchCoordinate,
           Date().timeIntervalSince(lastTime) < cacheValiditySeconds {
            // Check if coordinate is roughly the same (within 0.01 degrees)
            let latDiff = abs(lastCoord.latitude - coordinate.latitude)
            let lonDiff = abs(lastCoord.longitude - coordinate.longitude)
            if latDiff < 0.01 && lonDiff < 0.01 && !nearbyNOTAMs.isEmpty {
                return nearbyNOTAMs
            }
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            struct NOTAMRequest: Codable {
                let latitude: Double
                let longitude: Double
                let radiusDegrees: Double
            }
            
            let request = NOTAMRequest(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radiusDegrees: radiusDegrees
            )
            
            let response: NOTAMResponse = try await supabase.functions
                .invoke("get-notams", options: FunctionInvokeOptions(
                    body: request
                ))
            
            // Check for error in response
            if let error = response.error {
                throw NOTAMError.apiError(message: error)
            }
            
            // Sort NOTAMs: active first, then by category importance
            let sortedNOTAMs = response.notams.sorted { lhs, rhs in
                // Active NOTAMs first
                if lhs.isActive != rhs.isActive {
                    return lhs.isActive
                }
                // Then by category priority (runway/airspace are more critical)
                let lhsPriority = categoryPriority(lhs.category)
                let rhsPriority = categoryPriority(rhs.category)
                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                }
                // Then by end date (expiring soon first)
                return lhs.endsAt < rhs.endsAt
            }
            
            nearbyNOTAMs = sortedNOTAMs
            nearbyAirports = response.airports
            lastFetchTime = Date()
            lastFetchCoordinate = coordinate
            isLoading = false
            
            return nearbyNOTAMs
            
        } catch let error as DecodingError {
            isLoading = false
            let message = "Failed to parse NOTAM data: \(error.localizedDescription)"
            errorMessage = message
            print("NOTAM decoding error: \(error)")
            throw NOTAMError.parsingError
        } catch {
            isLoading = false
            
            // Handle cancellation gracefully
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return nearbyNOTAMs
            }
            
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Returns NOTAMs grouped by airport ICAO code
    func notamsGroupedByAirport() -> [String: [NOTAM]] {
        Dictionary(grouping: nearbyNOTAMs) { $0.icaoCode }
    }
    
    /// Returns NOTAMs grouped by category
    func notamsGroupedByCategory() -> [NOTAMCategory: [NOTAM]] {
        Dictionary(grouping: nearbyNOTAMs) { $0.category }
    }
    
    /// Returns only active NOTAMs
    var activeNOTAMs: [NOTAM] {
        nearbyNOTAMs.filter { $0.isActive }
    }
    
    /// Returns only critical NOTAMs (runway, airspace, obstacle)
    var criticalNOTAMs: [NOTAM] {
        nearbyNOTAMs.filter { notam in
            [.runway, .airspace, .obstacle].contains(notam.category)
        }
    }
    
    /// Clear the cache to force a fresh fetch
    func clearCache() {
        lastFetchTime = nil
        lastFetchCoordinate = nil
        nearbyNOTAMs = []
        nearbyAirports = []
    }
    
    // MARK: - Private Helpers
    
    private func categoryPriority(_ category: NOTAMCategory) -> Int {
        switch category {
        case .runway: return 0
        case .airspace: return 1
        case .obstacle: return 2
        case .navigation: return 3
        case .procedure: return 4
        case .lighting: return 5
        case .taxiway: return 6
        case .apron: return 7
        case .communication: return 8
        case .service: return 9
        case .other: return 10
        }
    }
}

// MARK: - NOTAM Error

enum NOTAMError: LocalizedError {
    case invalidCoordinates
    case apiError(message: String)
    case parsingError
    case noDataAvailable
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidCoordinates:
            return "Invalid coordinates provided"
        case .apiError(let message):
            return "API error: \(message)"
        case .parsingError:
            return "Error parsing NOTAM data"
        case .noDataAvailable:
            return "No NOTAM data available for this location"
        case .networkError:
            return "Network error while fetching NOTAMs"
        }
    }
}
