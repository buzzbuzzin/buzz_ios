//
//  ATISService.swift
//  Buzz
//
//  Created by Xinyu Fang on 1/27/26.
//

import Foundation
import CoreLocation
import Combine

@MainActor
class ATISService: ObservableObject {
    @Published var nearbyATIS: [ATIS] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let baseURL = "https://atisgenerator.com"
    
    // Cache to avoid excessive API calls
    private var lastFetchTime: Date?
    private var lastFetchCoordinate: CLLocationCoordinate2D?
    private let cacheValiditySeconds: TimeInterval = 300 // 5 minutes
    
    // Cached airport list
    private var cachedAirports: [ATISAirport] = []
    private var airportsFetchTime: Date?
    private let airportsCacheValiditySeconds: TimeInterval = 3600 // 1 hour
    
    // MARK: - Fetch ATIS for Nearby Airports
    
    /// Fetches ATIS for airports near the given coordinate
    /// - Parameters:
    ///   - coordinate: The center point for the search
    ///   - radiusKm: The search radius in kilometers (default 100km)
    /// - Returns: Array of ATIS reports sorted by distance
    func fetchATISNearLocation(
        coordinate: CLLocationCoordinate2D,
        radiusKm: Double = 100
    ) async throws -> [ATIS] {
        // Check cache validity
        if let lastTime = lastFetchTime,
           let lastCoord = lastFetchCoordinate,
           Date().timeIntervalSince(lastTime) < cacheValiditySeconds {
            // Check if coordinate is roughly the same (within 0.01 degrees)
            let latDiff = abs(lastCoord.latitude - coordinate.latitude)
            let lonDiff = abs(lastCoord.longitude - coordinate.longitude)
            if latDiff < 0.01 && lonDiff < 0.01 && !nearbyATIS.isEmpty {
                return nearbyATIS
            }
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Step 1: Get nearby airports
            let airports = try await fetchNearbyAirports(coordinate: coordinate, radiusKm: radiusKm)
            
            if airports.isEmpty {
                isLoading = false
                nearbyATIS = []
                return []
            }
            
            // Step 2: Fetch ATIS for each nearby airport (limit to 5)
            var atisResults: [ATIS] = []
            let airportsToFetch = Array(airports.prefix(5))
            
            for airport in airportsToFetch {
                do {
                    if let atis = try await fetchATIS(for: airport) {
                        atisResults.append(atis)
                    }
                } catch {
                    // Log but continue with other airports
                    print("Failed to fetch ATIS for \(airport.icao): \(error.localizedDescription)")
                }
            }
            
            // Only sort by distance when we actually have coordinates. The airport
            // endpoint does not currently return lat/lon so `latitude` and `longitude`
            // are 0 for every ATIS; sorting by distance against (0,0) is essentially
            // random. Preserve the API-returned order (filtered by region prefix) in
            // that case instead of showing a meaningless sort.
            let haveRealCoords = atisResults.contains { $0.latitude != 0 || $0.longitude != 0 }
            let sortedATIS: [ATIS]
            if haveRealCoords {
                sortedATIS = atisResults.sorted {
                    $0.distance(from: coordinate) < $1.distance(from: coordinate)
                }
            } else {
                sortedATIS = atisResults
            }

            nearbyATIS = sortedATIS
            lastFetchTime = Date()
            lastFetchCoordinate = coordinate
            isLoading = false
            
            return nearbyATIS
            
        } catch {
            isLoading = false
            
            // Handle cancellation gracefully
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return nearbyATIS
            }
            
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Fetch Airport List
    
    private func fetchNearbyAirports(
        coordinate: CLLocationCoordinate2D,
        radiusKm: Double
    ) async throws -> [ATISAirport] {
        // Check airport cache
        if let fetchTime = airportsFetchTime,
           Date().timeIntervalSince(fetchTime) < airportsCacheValiditySeconds,
           !cachedAirports.isEmpty {
            return filterAndSortAirports(cachedAirports, near: coordinate, radiusKm: radiusKm)
        }
        
        // Fetch all airports from API
        let urlString = "\(baseURL)/api/v1/airports"
        
        guard let url = URL(string: urlString) else {
            throw ATISError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ATISError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ATISError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Parse the response
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(ATISAirportListResponse.self, from: data)
        
        guard apiResponse.status == "success", let airports = apiResponse.data else {
            throw ATISError.noDataAvailable
        }
        
        // Enrich airports with location data
        // Note: The API doesn't provide lat/lon in the list, so we'll estimate based on ICAO
        // For better accuracy, we'd need to use the individual airport endpoint
        cachedAirports = airports
        airportsFetchTime = Date()
        
        return filterAndSortAirports(airports, near: coordinate, radiusKm: radiusKm)
    }
    
    private func filterAndSortAirports(
        _ airports: [ATISAirport],
        near coordinate: CLLocationCoordinate2D,
        radiusKm: Double
    ) -> [ATISAirport] {
        // Since the API doesn't provide lat/lon in the list response,
        // we'll filter by ICAO prefix for the region
        // US airports start with K, Canadian with C, etc.
        
        // For now, we'll just return all airports that match common US prefixes
        // and let the ATIS fetch fail gracefully for airports without METAR data
        let regionPrefixes = getRegionPrefixes(for: coordinate)
        
        let filtered = airports.filter { airport in
            regionPrefixes.contains { airport.icao.hasPrefix($0) }
        }
        
        // Return first 10 airports (we'll fetch ATIS for top 5)
        return Array(filtered.prefix(10))
    }
    
    private func getRegionPrefixes(for coordinate: CLLocationCoordinate2D) -> [String] {
        // Simple region detection based on coordinates
        // North America
        if coordinate.latitude > 24 && coordinate.latitude < 72 &&
           coordinate.longitude > -170 && coordinate.longitude < -50 {
            // US/Canada/Mexico
            if coordinate.latitude > 49 {
                return ["C", "K", "P"] // Canada, US, Pacific
            } else if coordinate.latitude < 30 && coordinate.longitude < -86 {
                return ["MM", "K"] // Mexico, US
            } else {
                return ["K", "P"] // US, Pacific
            }
        }
        // Europe
        else if coordinate.latitude > 35 && coordinate.latitude < 72 &&
                coordinate.longitude > -10 && coordinate.longitude < 40 {
            return ["E", "L"] // Europe
        }
        // Default to common prefixes
        return ["K", "C", "E", "L", "P"]
    }
    
    // MARK: - Fetch Individual ATIS
    
    private func fetchATIS(for airport: ATISAirport) async throws -> ATIS? {
        let urlString = "\(baseURL)/api/v1/airports/\(airport.icao)/atis"
        
        guard let url = URL(string: urlString) else {
            throw ATISError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        
        // Parse runways from airport data (comma-separated string like "26,08,32,14")
        let runwayList: [String]
        if let runwaysString = airport.runways, !runwaysString.isEmpty {
            runwayList = runwaysString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        } else {
            // If no runways available, we can't generate ATIS
            return nil
        }
        
        // Create request body with runways and ident - API requires these fields
        // Use "A" as default ATIS identifier (Information Alpha)
        let requestBody: [String: Any] = [
            "icao": airport.icao,
            "ident": "A",
            "landing_runways": runwayList,
            "departing_runways": runwayList,
            "output-type": "atis"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ATISError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ATISError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Parse the response
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(ATISAPIResponse.self, from: data)
        
        guard apiResponse.status == "success",
              let atisData = apiResponse.data,
              let spokenText = atisData.spoken,
              let rawText = atisData.text else {
            return nil
        }
        
        // First, get airport details to get location
        let airportDetails = try? await fetchAirportDetails(icao: airport.icao)
        
        // Parse the ATIS text to extract components
        return parseATIS(
            icao: airport.icao,
            airportName: airport.name,
            spokenText: spokenText,
            rawText: rawText,
            latitude: airportDetails?.latitude ?? 0,
            longitude: airportDetails?.longitude ?? 0
        )
    }
    
    private func fetchAirportDetails(icao: String) async throws -> (latitude: Double, longitude: Double)? {
        let urlString = "\(baseURL)/api/v1/airports/\(icao)"
        
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }
        
        // The airport endpoint doesn't seem to return lat/lon directly,
        // so we'll need to use a different approach or accept 0,0 for now
        // In a production app, we'd use a proper airport database
        
        return nil
    }
    
    // MARK: - ATIS Parser
    
    private func parseATIS(
        icao: String,
        airportName: String,
        spokenText: String,
        rawText: String,
        latitude: Double,
        longitude: Double
    ) -> ATIS {
        let uppercasedText = spokenText.uppercased()
        
        // Parse information letter
        let information = parseInformationLetter(from: uppercasedText)
        
        // Parse observation time
        let observationTime = parseObservationTime(from: uppercasedText)
        
        // Parse wind
        let wind = parseWind(from: uppercasedText)
        
        // Parse visibility
        let visibility = parseVisibility(from: uppercasedText)
        
        // Parse sky condition
        let skyCondition = parseSkyCondition(from: uppercasedText)
        
        // Parse temperature and dewpoint
        let (temperature, dewpoint) = parseTemperature(from: uppercasedText)
        
        // Parse altimeter
        let altimeter = parseAltimeter(from: uppercasedText)
        
        // Parse runways
        let (landingRunways, departingRunways) = parseRunways(from: uppercasedText)
        
        return ATIS(
            id: "\(icao)-\(Date().timeIntervalSince1970)",
            icao: icao,
            airportName: airportName,
            information: information ?? "?",
            observationTime: observationTime,
            rawText: rawText,
            spokenText: spokenText,
            wind: wind,
            visibility: visibility,
            skyCondition: skyCondition,
            temperature: temperature,
            dewpoint: dewpoint,
            altimeter: altimeter,
            landingRunways: landingRunways,
            departingRunways: departingRunways,
            latitude: latitude,
            longitude: longitude
        )
    }
    
    private func parseInformationLetter(from text: String) -> String? {
        // Pattern: "INFORMATION ALPHA", "INFORMATION BRAVO", etc.
        let pattern = "INFORMATION\\s+(ALFA|ALPHA|BRAVO|CHARLIE|DELTA|ECHO|FOXTROT|GOLF|HOTEL|INDIA|JULIET|JULIETT|KILO|LIMA|MIKE|NOVEMBER|OSCAR|PAPA|QUEBEC|ROMEO|SIERRA|TANGO|UNIFORM|VICTOR|WHISKEY|X-?RAY|YANKEE|ZULU|[A-Z])"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }
    
    private func parseObservationTime(from text: String) -> Date? {
        // Pattern: "TIME 1700 ZULU" or "1700 ZULU"
        let pattern = "(?:TIME\\s+)?(\\d{2})(\\d{2})\\s*(?:ZULU|Z)"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let hoursRange = Range(match.range(at: 1), in: text),
           let minutesRange = Range(match.range(at: 2), in: text),
           let hours = Int(text[hoursRange]),
           let minutes = Int(text[minutesRange]) {
            
            // Create a date for today at the specified Zulu time
            var components = Calendar.current.dateComponents(in: TimeZone(identifier: "UTC")!, from: Date())
            components.hour = hours
            components.minute = minutes
            components.second = 0
            
            return Calendar.current.date(from: components)
        }
        return nil
    }
    
    private func parseWind(from text: String) -> ATISWind? {
        // Pattern: "WIND 180 AT 10" or "WIND 180 AT 10 GUSTS 20" or "WIND CALM" or "WIND VARIABLE AT 5"
        
        // Check for calm
        if text.contains("WIND CALM") || text.contains("CALM WIND") {
            return ATISWind(direction: nil, speed: 0, gust: nil, isVariable: false, isCalm: true)
        }
        
        // Check for variable wind
        let variablePattern = "WIND\\s+VARIABLE\\s+(?:AT\\s+)?(\\d+)(?:\\s+GUST(?:S|ING)?\\s+(?:TO\\s+)?(\\d+))?"
        if let regex = try? NSRegularExpression(pattern: variablePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let speedRange = Range(match.range(at: 1), in: text),
           let speed = Int(text[speedRange]) {
            
            var gust: Int? = nil
            if match.range(at: 2).location != NSNotFound,
               let gustRange = Range(match.range(at: 2), in: text),
               let gustValue = Int(text[gustRange]) {
                gust = gustValue
            }
            
            return ATISWind(direction: nil, speed: speed, gust: gust, isVariable: true, isCalm: false)
        }
        
        // Pattern for normal wind: "WIND 180 AT 10" or "WIND ONE EIGHT ZERO AT ONE ZERO"
        let normalPattern = "WIND\\s+(\\d{1,3}|(?:(?:ONE|TWO|THREE|FOUR|FIVE|SIX|SEVEN|EIGHT|NINE|ZERO|NINER)\\s*)+)\\s+(?:AT|DEGREES?\\s+AT)?\\s*(\\d+|(?:(?:ONE|TWO|THREE|FOUR|FIVE|SIX|SEVEN|EIGHT|NINE|ZERO|NINER)\\s*)+)(?:\\s+GUST(?:S|ING)?\\s+(?:TO\\s+)?(\\d+|(?:(?:ONE|TWO|THREE|FOUR|FIVE|SIX|SEVEN|EIGHT|NINE|ZERO|NINER)\\s*)+))?"
        
        if let regex = try? NSRegularExpression(pattern: normalPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let dirRange = Range(match.range(at: 1), in: text),
           let speedRange = Range(match.range(at: 2), in: text) {
            
            let dirString = String(text[dirRange])
            let speedString = String(text[speedRange])
            
            let direction = parseSpokenNumber(dirString)
            let speed = parseSpokenNumber(speedString) ?? 0
            
            var gust: Int? = nil
            if match.range(at: 3).location != NSNotFound,
               let gustRange = Range(match.range(at: 3), in: text) {
                gust = parseSpokenNumber(String(text[gustRange]))
            }
            
            return ATISWind(direction: direction, speed: speed, gust: gust, isVariable: false, isCalm: false)
        }
        
        return nil
    }
    
    private func parseSpokenNumber(_ text: String) -> Int? {
        // First try parsing as a regular number
        if let number = Int(text.trimmingCharacters(in: .whitespaces)) {
            return number
        }
        
        // Parse spoken numbers like "ONE EIGHT ZERO"
        let spokenDigits: [String: Int] = [
            "ZERO": 0, "NINER": 9, "NINE": 9,
            "ONE": 1, "TWO": 2, "THREE": 3, "FOUR": 4, "FIVE": 5,
            "SIX": 6, "SEVEN": 7, "EIGHT": 8
        ]
        
        var result = 0
        let words = text.uppercased().split(separator: " ")
        
        for word in words {
            if let digit = spokenDigits[String(word)] {
                result = result * 10 + digit
            }
        }
        
        return result > 0 ? result : nil
    }
    
    private func parseVisibility(from text: String) -> String? {
        // Pattern: "VISIBILITY 10" or "VISIBILITY ONE ZERO" or "VISIBILITY 3"
        let pattern = "VISIBILITY\\s+(\\d+(?:/\\d+)?|(?:(?:ONE|TWO|THREE|FOUR|FIVE|SIX|SEVEN|EIGHT|NINE|ZERO|TEN|NINER)\\s*)+)"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let visRange = Range(match.range(at: 1), in: text) {
            let visString = String(text[visRange]).trimmingCharacters(in: .whitespaces)
            
            // Handle fractions like "1/2"
            if visString.contains("/") {
                return visString
            }
            
            // Try to parse as number
            if let number = parseSpokenNumber(visString) {
                return "\(number)"
            }
            
            // Handle "TEN" -> 10
            if visString.uppercased() == "TEN" {
                return "10"
            }
            
            return visString
        }
        return nil
    }
    
    private func parseSkyCondition(from text: String) -> String? {
        // Pattern: "SKY CLEAR", "FEW CLOUDS AT 5000", "SCATTERED CLOUDS AT 3000"
        let patterns = [
            "SKY CLEAR",
            "CLEAR SKY",
            "SKY CONDITION[S]?[:\\s]+((?:FEW|SCATTERED|BROKEN|OVERCAST|CLEAR)[^,\\.]*)",
            "(FEW|SCATTERED|BROKEN|OVERCAST)\\s+(?:CLOUDS?\\s+)?(?:AT\\s+)?(\\d+)",
            "CEILING\\s+(\\d+)\\s*(?:FEET|FT)?\\s*(BROKEN|OVERCAST)?"
        ]
        
        // Check for sky clear first
        if text.contains("SKY CLEAR") || text.contains("CLEAR SKY") {
            return "Clear"
        }
        
        // Check for specific cloud conditions
        let cloudPattern = "(FEW|SCATTERED|BROKEN|OVERCAST)\\s+(?:CLOUDS?\\s+)?(?:AT\\s+)?(\\d+)"
        if let regex = try? NSRegularExpression(pattern: cloudPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let coverRange = Range(match.range(at: 1), in: text),
           let altRange = Range(match.range(at: 2), in: text) {
            let cover = String(text[coverRange])
            let altitude = String(text[altRange])
            return "\(cover.capitalized) at \(altitude) ft"
        }
        
        // Check for ceiling
        let ceilingPattern = "CEILING\\s+(\\d+)"
        if let regex = try? NSRegularExpression(pattern: ceilingPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let altRange = Range(match.range(at: 1), in: text) {
            let altitude = String(text[altRange])
            return "Ceiling \(altitude) ft"
        }
        
        return nil
    }
    
    private func parseTemperature(from text: String) -> (temperature: Int?, dewpoint: Int?) {
        // Pattern: "TEMPERATURE 27, DEW POINT 23" or "TEMPERATURE TWO SEVEN, DEW POINT TWO THREE"
        let tempPattern = "TEMPERATURE\\s+(MINUS\\s+)?(\\d+|(?:(?:ONE|TWO|THREE|FOUR|FIVE|SIX|SEVEN|EIGHT|NINE|ZERO|NINER)\\s*)+)"
        let dewPattern = "DEW\\s*POINT\\s+(MINUS\\s+)?(\\d+|(?:(?:ONE|TWO|THREE|FOUR|FIVE|SIX|SEVEN|EIGHT|NINE|ZERO|NINER)\\s*)+)"
        
        var temperature: Int? = nil
        var dewpoint: Int? = nil
        
        if let regex = try? NSRegularExpression(pattern: tempPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let tempRange = Range(match.range(at: 2), in: text) {
            let isMinus = match.range(at: 1).location != NSNotFound
            if let temp = parseSpokenNumber(String(text[tempRange])) {
                temperature = isMinus ? -temp : temp
            }
        }
        
        if let regex = try? NSRegularExpression(pattern: dewPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let dewRange = Range(match.range(at: 2), in: text) {
            let isMinus = match.range(at: 1).location != NSNotFound
            if let dew = parseSpokenNumber(String(text[dewRange])) {
                dewpoint = isMinus ? -dew : dew
            }
        }
        
        return (temperature, dewpoint)
    }
    
    private func parseAltimeter(from text: String) -> Double? {
        // Pattern: "ALTIMETER 3002" or "ALTIMETER THREE ZERO ZERO TWO"
        let pattern = "ALTIMETER\\s+(\\d{4}|(?:(?:ONE|TWO|THREE|FOUR|FIVE|SIX|SEVEN|EIGHT|NINE|ZERO|NINER)\\s*)+)"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let altRange = Range(match.range(at: 1), in: text) {
            if let altValue = parseSpokenNumber(String(text[altRange])) {
                // Convert 3002 to 30.02
                return Double(altValue) / 100.0
            }
        }
        return nil
    }
    
    private func parseRunways(from text: String) -> (landing: [String], departing: [String]) {
        var landingRunways: [String] = []
        var departingRunways: [String] = []
        
        // Pattern: "LANDING RUNWAY 8" or "LANDING AND DEPARTING RUNWAY 8"
        // Pattern: "DEPARTING RUNWAY 26" or "DEPARTURE RUNWAY 26"
        
        // Check for combined landing and departing
        let combinedPattern = "LANDING\\s+AND\\s+DEPART(?:ING|URE)\\s+RUNWAY[S]?\\s+([\\d\\sLRC,AND]+)"
        if let regex = try? NSRegularExpression(pattern: combinedPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let runwayRange = Range(match.range(at: 1), in: text) {
            let runways = parseRunwayNumbers(String(text[runwayRange]))
            landingRunways = runways
            departingRunways = runways
        } else {
            // Check for separate landing runways
            let landingPattern = "LANDING\\s+RUNWAY[S]?\\s+([\\d\\sLRC,AND]+)"
            if let regex = try? NSRegularExpression(pattern: landingPattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let runwayRange = Range(match.range(at: 1), in: text) {
                landingRunways = parseRunwayNumbers(String(text[runwayRange]))
            }
            
            // Check for separate departing runways
            let departingPattern = "DEPART(?:ING|URE)\\s+RUNWAY[S]?\\s+([\\d\\sLRC,AND]+)"
            if let regex = try? NSRegularExpression(pattern: departingPattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let runwayRange = Range(match.range(at: 1), in: text) {
                departingRunways = parseRunwayNumbers(String(text[runwayRange]))
            }
        }
        
        return (landingRunways, departingRunways)
    }
    
    private func parseRunwayNumbers(_ text: String) -> [String] {
        // Extract runway numbers like "8", "26L", "27R", etc.
        let pattern = "(\\d{1,2}[LRC]?)"
        var runways: [String] = []
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    runways.append(String(text[range]).uppercased())
                }
            }
        }
        
        return runways
    }
    
    /// Clear the cache to force a fresh fetch
    func clearCache() {
        lastFetchTime = nil
        lastFetchCoordinate = nil
        nearbyATIS = []
    }
}

// MARK: - ATIS Error

enum ATISError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case parsingError
    case noDataAvailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for ATIS request"
        case .invalidResponse:
            return "Invalid response from ATIS service"
        case .httpError(let statusCode):
            return "HTTP error \(statusCode) from ATIS service"
        case .parsingError:
            return "Error parsing ATIS data"
        case .noDataAvailable:
            return "No ATIS data available for this location"
        }
    }
}

// MARK: - API Response Models

struct ATISAirportListResponse: Codable {
    let status: String
    let message: String?
    let code: Int?
    let data: [ATISAirport]?
}

struct ATISAPIResponse: Codable {
    let status: String
    let message: String?
    let code: Int?
    let data: ATISData?
}

struct ATISData: Codable {
    let spoken: String?
    let text: String?
}
