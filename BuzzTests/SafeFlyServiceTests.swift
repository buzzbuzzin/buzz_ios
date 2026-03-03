import Foundation
import CoreLocation
import Testing
@testable import Buzz

struct SafeFlyServiceTests {

    // MARK: - OpenMeteoHourlyData Decoding: All New Fields Present

    @Test func openMeteoHourlyData_decodesAllFields() throws {
        let json = """
        {
          "time": ["2026-03-03T00:00", "2026-03-03T01:00"],
          "wind_gusts_10m": [25.3, 18.7],
          "visibility": [10000.0, 8000.0],
          "temperature_2m": [42.5, 40.1],
          "wind_speed_10m": [15.2, 12.8],
          "wind_direction_10m": [225, 210],
          "precipitation_probability": [10, 20],
          "cloud_cover": [40, 60],
          "weather_code": [2, 3],
          "relative_humidity_2m": [65, 70]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(OpenMeteoHourlyData.self, from: json)

        #expect(decoded.time.count == 2)
        #expect(decoded.time[0] == "2026-03-03T00:00")
        #expect(decoded.time[1] == "2026-03-03T01:00")

        #expect(decoded.windGusts10m.count == 2)
        #expect(decoded.windGusts10m[0] == 25.3)
        #expect(decoded.windGusts10m[1] == 18.7)

        #expect(decoded.visibility.count == 2)
        #expect(decoded.visibility[0] == 10000.0)
        #expect(decoded.visibility[1] == 8000.0)

        #expect(decoded.temperature2m?.count == 2)
        #expect(decoded.temperature2m?[0] == 42.5)
        #expect(decoded.temperature2m?[1] == 40.1)

        #expect(decoded.windSpeed10m?.count == 2)
        #expect(decoded.windSpeed10m?[0] == 15.2)
        #expect(decoded.windSpeed10m?[1] == 12.8)

        #expect(decoded.windDirection10m?.count == 2)
        #expect(decoded.windDirection10m?[0] == 225)
        #expect(decoded.windDirection10m?[1] == 210)

        #expect(decoded.precipitationProbability?.count == 2)
        #expect(decoded.precipitationProbability?[0] == 10)
        #expect(decoded.precipitationProbability?[1] == 20)

        #expect(decoded.cloudCover?.count == 2)
        #expect(decoded.cloudCover?[0] == 40)
        #expect(decoded.cloudCover?[1] == 60)

        #expect(decoded.weatherCode?.count == 2)
        #expect(decoded.weatherCode?[0] == 2)
        #expect(decoded.weatherCode?[1] == 3)

        #expect(decoded.relativeHumidity2m?.count == 2)
        #expect(decoded.relativeHumidity2m?[0] == 65)
        #expect(decoded.relativeHumidity2m?[1] == 70)
    }

    // MARK: - OpenMeteoHourlyData Decoding: Only Old Fields (Backward Compatibility)

    @Test func openMeteoHourlyData_decodesWithOnlyOldFields() throws {
        let json = """
        {
          "time": ["2026-03-03T12:00", "2026-03-03T13:00", "2026-03-03T14:00"],
          "wind_gusts_10m": [30.0, 22.5, 15.0],
          "visibility": [5000.0, 7500.0, 10000.0]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(OpenMeteoHourlyData.self, from: json)

        #expect(decoded.time.count == 3)
        #expect(decoded.time[0] == "2026-03-03T12:00")

        #expect(decoded.windGusts10m.count == 3)
        #expect(decoded.windGusts10m[0] == 30.0)

        #expect(decoded.visibility.count == 3)
        #expect(decoded.visibility[2] == 10000.0)

        // All extended fields should be nil
        #expect(decoded.temperature2m == nil)
        #expect(decoded.windSpeed10m == nil)
        #expect(decoded.windDirection10m == nil)
        #expect(decoded.precipitationProbability == nil)
        #expect(decoded.cloudCover == nil)
        #expect(decoded.weatherCode == nil)
        #expect(decoded.relativeHumidity2m == nil)
    }

    // MARK: - OpenMeteoHourlyEntry Construction

    @Test func openMeteoHourlyEntry_constructsCorrectly() {
        let entry = OpenMeteoHourlyEntry(
            gust: 25.3,
            visibility: 6.21,
            temperature: 42.5,
            windSpeed: 15.2,
            windDirection: 225,
            precipitation: 10,
            cloudCover: 40,
            weatherCode: 2,
            humidity: 65
        )

        #expect(entry.gust == 25.3)
        #expect(entry.visibility == 6.21)
        #expect(entry.temperature == 42.5)
        #expect(entry.windSpeed == 15.2)
        #expect(entry.windDirection == 225)
        #expect(entry.precipitation == 10)
        #expect(entry.cloudCover == 40)
        #expect(entry.weatherCode == 2)
        #expect(entry.humidity == 65)
    }

    @Test func openMeteoHourlyEntry_constructsWithNils() {
        let entry = OpenMeteoHourlyEntry(
            gust: nil,
            visibility: nil,
            temperature: nil,
            windSpeed: nil,
            windDirection: nil,
            precipitation: nil,
            cloudCover: nil,
            weatherCode: nil,
            humidity: nil
        )

        #expect(entry.gust == nil)
        #expect(entry.visibility == nil)
        #expect(entry.temperature == nil)
        #expect(entry.windSpeed == nil)
        #expect(entry.windDirection == nil)
        #expect(entry.precipitation == nil)
        #expect(entry.cloudCover == nil)
        #expect(entry.weatherCode == nil)
        #expect(entry.humidity == nil)
    }

    // MARK: - OpenMeteoHourlyData Handles Null Values Within Arrays

    @Test func openMeteoHourlyData_handlesNullsInArrays() throws {
        let json = """
        {
          "time": ["2026-03-03T00:00", "2026-03-03T01:00", "2026-03-03T02:00"],
          "wind_gusts_10m": [25.3, null, 18.7],
          "visibility": [1000.0, null, 5000.0],
          "temperature_2m": [42.5, null, 38.0],
          "wind_speed_10m": [15.2, null, 10.5],
          "wind_direction_10m": [225, null, 180],
          "precipitation_probability": [10, null, 30],
          "cloud_cover": [40, null, 80],
          "weather_code": [2, null, 61],
          "relative_humidity_2m": [65, null, 85]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(OpenMeteoHourlyData.self, from: json)

        #expect(decoded.time.count == 3)

        // First element has values
        #expect(decoded.windGusts10m[0] == 25.3)
        #expect(decoded.visibility[0] == 1000.0)
        #expect(decoded.temperature2m?[0] == 42.5)
        #expect(decoded.windSpeed10m?[0] == 15.2)
        #expect(decoded.windDirection10m?[0] == 225)
        #expect(decoded.precipitationProbability?[0] == 10)
        #expect(decoded.cloudCover?[0] == 40)
        #expect(decoded.weatherCode?[0] == 2)
        #expect(decoded.relativeHumidity2m?[0] == 65)

        // Second element has nulls
        #expect(decoded.windGusts10m[1] == nil)
        #expect(decoded.visibility[1] == nil)
        #expect(decoded.temperature2m?[1] == nil)
        #expect(decoded.windSpeed10m?[1] == nil)
        #expect(decoded.windDirection10m?[1] == nil)
        #expect(decoded.precipitationProbability?[1] == nil)
        #expect(decoded.cloudCover?[1] == nil)
        #expect(decoded.weatherCode?[1] == nil)
        #expect(decoded.relativeHumidity2m?[1] == nil)

        // Third element has values
        #expect(decoded.windGusts10m[2] == 18.7)
        #expect(decoded.visibility[2] == 5000.0)
        #expect(decoded.temperature2m?[2] == 38.0)
        #expect(decoded.windSpeed10m?[2] == 10.5)
        #expect(decoded.windDirection10m?[2] == 180)
        #expect(decoded.precipitationProbability?[2] == 30)
        #expect(decoded.cloudCover?[2] == 80)
        #expect(decoded.weatherCode?[2] == 61)
        #expect(decoded.relativeHumidity2m?[2] == 85)
    }

    // MARK: - OpenMeteoResponse Full Decoding

    @Test func openMeteoResponse_decodesFullResponse() throws {
        let json = """
        {
          "hourly": {
            "time": ["2026-03-03T00:00"],
            "wind_gusts_10m": [25.3],
            "visibility": [10000.0],
            "temperature_2m": [42.5],
            "wind_speed_10m": [15.2],
            "wind_direction_10m": [225],
            "precipitation_probability": [10],
            "cloud_cover": [40],
            "weather_code": [2],
            "relative_humidity_2m": [65]
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: json)

        #expect(decoded.hourly.time.count == 1)
        #expect(decoded.hourly.time[0] == "2026-03-03T00:00")
        #expect(decoded.hourly.windGusts10m[0] == 25.3)
        #expect(decoded.hourly.temperature2m?[0] == 42.5)
    }

    // MARK: - Canadian Location: buildHourlyForecastFromOpenMeteo

    /// Tests that Open-Meteo data for Toronto produces valid HourlyForecast array
    /// This is the code path used when NWS fails (non-US locations)
    @MainActor
    @Test func buildHourlyForecast_torontoWinter() {
        let service = SafeFlyService()
        let baseDate = Date(timeIntervalSince1970: 1772640000) // 2026-03-02T00:00:00Z

        // Simulate 3 hours of Toronto winter weather from Open-Meteo
        let data: [Date: OpenMeteoHourlyEntry] = [
            baseDate: OpenMeteoHourlyEntry(
                gust: 35.2, visibility: 3.1, temperature: 23.0,
                windSpeed: 22.4, windDirection: 315, precipitation: 60,
                cloudCover: 95, weatherCode: 73, humidity: 88
            ),
            baseDate.addingTimeInterval(3600): OpenMeteoHourlyEntry(
                gust: 28.5, visibility: 2.5, temperature: 21.2,
                windSpeed: 18.6, windDirection: 320, precipitation: 70,
                cloudCover: 100, weatherCode: 75, humidity: 92
            ),
            baseDate.addingTimeInterval(7200): OpenMeteoHourlyEntry(
                gust: 20.1, visibility: 5.0, temperature: 24.8,
                windSpeed: 14.3, windDirection: 300, precipitation: 30,
                cloudCover: 80, weatherCode: 3, humidity: 78
            ),
        ]

        let forecasts = service.buildHourlyForecastFromOpenMeteo(data)

        #expect(forecasts.count == 3)

        // Verify first hour: heavy snow conditions
        let first = forecasts[0]
        #expect(first.temperature == 23.0)
        #expect(first.windSpeed == 22.4)
        #expect(first.windGust == 35.2)
        #expect(first.windDirection == "NW")
        #expect(first.windDirectionDegrees == 315)
        #expect(first.precipitation == 60)
        #expect(first.cloudCover == 95)
        #expect(first.humidity == 88)
        #expect(first.visibility == 3.1)
        #expect(first.shortForecast == "Snow")

        // Verify second hour: heavier snow
        let second = forecasts[1]
        #expect(second.temperature == 21.2)
        #expect(second.shortForecast == "Heavy snow")
        #expect(second.visibility == 2.5)

        // Verify third hour: overcast clearing
        let third = forecasts[2]
        #expect(third.shortForecast == "Overcast")
        #expect(third.visibility == 5.0)
    }

    /// Tests that Open-Meteo fallback handles nil values gracefully for Canadian data
    @MainActor
    @Test func buildHourlyForecast_handlesNilValues() {
        let service = SafeFlyService()
        let baseDate = Date(timeIntervalSince1970: 1772640000)

        // Simulate data with many nil fields (e.g. null values from Open-Meteo)
        let data: [Date: OpenMeteoHourlyEntry] = [
            baseDate: OpenMeteoHourlyEntry(
                gust: nil, visibility: nil, temperature: nil,
                windSpeed: nil, windDirection: nil, precipitation: nil,
                cloudCover: nil, weatherCode: nil, humidity: nil
            ),
        ]

        let forecasts = service.buildHourlyForecastFromOpenMeteo(data)

        #expect(forecasts.count == 1)
        let forecast = forecasts[0]

        // When values are nil, defaults should be used
        #expect(forecast.temperature == 0)
        #expect(forecast.windSpeed == 0)
        #expect(forecast.windGust == nil)
        #expect(forecast.windDirection == "N") // Default from 0 degrees
        #expect(forecast.precipitation == 0)
        #expect(forecast.visibility == nil)
        #expect(forecast.shortForecast == "Clear sky") // WMO code 0 default
    }

    // MARK: - US Location: buildHourlyForecastFromOpenMeteo

    /// Tests that Open-Meteo data for New York produces valid HourlyForecast
    /// (used as fallback even for US locations if NWS happens to fail)
    @MainActor
    @Test func buildHourlyForecast_newYorkSpring() {
        let service = SafeFlyService()
        let baseDate = Date(timeIntervalSince1970: 1772640000)

        let data: [Date: OpenMeteoHourlyEntry] = [
            baseDate: OpenMeteoHourlyEntry(
                gust: 12.1, visibility: 10.0, temperature: 62.5,
                windSpeed: 8.3, windDirection: 225, precipitation: 5,
                cloudCover: 15, weatherCode: 1, humidity: 45
            ),
            baseDate.addingTimeInterval(3600): OpenMeteoHourlyEntry(
                gust: 15.0, visibility: 10.0, temperature: 64.0,
                windSpeed: 10.5, windDirection: 210, precipitation: 10,
                cloudCover: 30, weatherCode: 2, humidity: 50
            ),
        ]

        let forecasts = service.buildHourlyForecastFromOpenMeteo(data)

        #expect(forecasts.count == 2)

        let first = forecasts[0]
        #expect(first.temperature == 62.5)
        #expect(first.windSpeed == 8.3)
        #expect(first.windGust == 12.1)
        #expect(first.windDirection == "SW")
        #expect(first.precipitation == 5)
        #expect(first.shortForecast == "Mainly clear")
        #expect(first.visibility == 10.0)

        let second = forecasts[1]
        #expect(second.shortForecast == "Partly cloudy")
        #expect(second.windDirection == "SSW")
    }

    // MARK: - Full Open-Meteo Decode → HourlyForecast Pipeline (Canadian)

    /// Tests the complete pipeline: JSON → OpenMeteoHourlyData → OpenMeteoHourlyEntry → HourlyForecast
    /// Simulates what happens for a Canadian location where NWS fails
    @MainActor
    @Test func fullPipeline_canadianOpenMeteoToHourlyForecast() throws {
        // Step 1: Decode realistic Canadian Open-Meteo response
        let json = """
        {
          "hourly": {
            "time": ["2026-03-03T06:00", "2026-03-03T07:00", "2026-03-03T08:00"],
            "wind_gusts_10m": [40.5, 38.2, 30.1],
            "visibility": [800.0, 1200.0, 5000.0],
            "temperature_2m": [19.4, 18.0, 21.2],
            "wind_speed_10m": [25.0, 22.3, 18.6],
            "wind_direction_10m": [0, 350, 330],
            "precipitation_probability": [80, 70, 40],
            "cloud_cover": [100, 100, 85],
            "weather_code": [75, 73, 61],
            "relative_humidity_2m": [95, 92, 80]
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: json)
        let hourly = response.hourly

        // Step 2: Convert to OpenMeteoHourlyEntry dict (same as fetchOpenMeteoData)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        var entryDict: [Date: OpenMeteoHourlyEntry] = [:]
        for (index, timeString) in hourly.time.enumerated() {
            guard let date = dateFormatter.date(from: timeString) else { continue }
            let visibilityMiles = hourly.visibility[index].map { $0 / 1609.34 }
            let gustMph = hourly.windGusts10m[index]

            func safeGet<T>(_ array: [T?]?) -> T? {
                guard let arr = array, index < arr.count else { return nil }
                return arr[index]
            }

            entryDict[date] = OpenMeteoHourlyEntry(
                gust: gustMph,
                visibility: visibilityMiles,
                temperature: safeGet(hourly.temperature2m),
                windSpeed: safeGet(hourly.windSpeed10m),
                windDirection: safeGet(hourly.windDirection10m),
                precipitation: safeGet(hourly.precipitationProbability),
                cloudCover: safeGet(hourly.cloudCover),
                weatherCode: safeGet(hourly.weatherCode),
                humidity: safeGet(hourly.relativeHumidity2m)
            )
        }

        #expect(entryDict.count == 3)

        // Step 3: Build HourlyForecast array (same as buildHourlyForecastFromOpenMeteo)
        let service = SafeFlyService()
        let forecasts = service.buildHourlyForecastFromOpenMeteo(entryDict)

        #expect(forecasts.count == 3)

        // Verify first hour: heavy snow, very low visibility
        let hour1 = forecasts[0]
        #expect(hour1.temperature == 19.4)
        #expect(hour1.windSpeed == 25.0)
        #expect(hour1.windGust == 40.5)
        #expect(hour1.windDirection == "N")
        #expect(hour1.precipitation == 80)
        #expect(hour1.shortForecast == "Heavy snow")
        // 800m ≈ 0.497 miles
        #expect(hour1.visibility != nil)
        #expect(hour1.visibility! < 0.5)

        // Verify third hour: light rain, better visibility
        let hour3 = forecasts[2]
        #expect(hour3.shortForecast == "Light rain")
        // 5000m ≈ 3.1 miles
        #expect(hour3.visibility != nil)
        #expect(hour3.visibility! > 3.0)
        #expect(hour3.visibility! < 3.2)
    }

    // MARK: - Full Open-Meteo Decode → HourlyForecast Pipeline (US)

    /// Tests the same pipeline for a US location
    @MainActor
    @Test func fullPipeline_usOpenMeteoToHourlyForecast() throws {
        let json = """
        {
          "hourly": {
            "time": ["2026-03-03T14:00", "2026-03-03T15:00"],
            "wind_gusts_10m": [15.0, 18.2],
            "visibility": [16093.0, 16093.0],
            "temperature_2m": [68.0, 70.2],
            "wind_speed_10m": [10.0, 12.5],
            "wind_direction_10m": [180, 190],
            "precipitation_probability": [0, 5],
            "cloud_cover": [10, 20],
            "weather_code": [0, 1],
            "relative_humidity_2m": [40, 38]
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: json)
        let hourly = response.hourly

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        var entryDict: [Date: OpenMeteoHourlyEntry] = [:]
        for (index, timeString) in hourly.time.enumerated() {
            guard let date = dateFormatter.date(from: timeString) else { continue }
            let visibilityMiles = hourly.visibility[index].map { $0 / 1609.34 }
            let gustMph = hourly.windGusts10m[index]

            func safeGet<T>(_ array: [T?]?) -> T? {
                guard let arr = array, index < arr.count else { return nil }
                return arr[index]
            }

            entryDict[date] = OpenMeteoHourlyEntry(
                gust: gustMph,
                visibility: visibilityMiles,
                temperature: safeGet(hourly.temperature2m),
                windSpeed: safeGet(hourly.windSpeed10m),
                windDirection: safeGet(hourly.windDirection10m),
                precipitation: safeGet(hourly.precipitationProbability),
                cloudCover: safeGet(hourly.cloudCover),
                weatherCode: safeGet(hourly.weatherCode),
                humidity: safeGet(hourly.relativeHumidity2m)
            )
        }

        let service = SafeFlyService()
        let forecasts = service.buildHourlyForecastFromOpenMeteo(entryDict)

        #expect(forecasts.count == 2)

        // Clear US weather
        let hour1 = forecasts[0]
        #expect(hour1.temperature == 68.0)
        #expect(hour1.shortForecast == "Clear sky")
        #expect(hour1.precipitation == 0)
        // 16093m ≈ 10 miles
        #expect(hour1.visibility != nil)
        #expect(hour1.visibility! > 9.9)

        let hour2 = forecasts[1]
        #expect(hour2.shortForecast == "Mainly clear")
        #expect(hour2.windDirection == "S")
    }

    // MARK: - Visibility Conversion (meters → miles)

    /// Verify the visibility conversion from Open-Meteo meters to miles is accurate
    @Test func visibilityConversion_metersToMiles() {
        // Open-Meteo always returns visibility in meters
        let testCases: [(meters: Double, expectedMilesApprox: Double)] = [
            (16093.0, 10.0),   // 10 miles - good visibility
            (8046.0, 5.0),     // 5 miles - moderate
            (1609.34, 1.0),    // 1 mile - poor
            (800.0, 0.497),    // ~0.5 miles - very poor (blizzard)
            (100.0, 0.062),    // ~0.06 miles - near zero (dense fog)
        ]

        for testCase in testCases {
            let miles = testCase.meters / 1609.34
            let diff = abs(miles - testCase.expectedMilesApprox)
            #expect(diff < 0.01, "Expected ~\(testCase.expectedMilesApprox) miles for \(testCase.meters)m, got \(miles)")
        }
    }
}
