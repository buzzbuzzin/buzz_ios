//
//  WeatherService.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import CoreLocation
import Combine

@MainActor
class WeatherService: ObservableObject {
    @Published var currentLocationWeather: Weather?
    @Published var bookingLocationWeather: Weather?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let baseURL = "https://api.weather.gov"
    
    // MARK: - Fetch Weather for Current Location
    
    func fetchWeatherForLocation(coordinate: CLLocationCoordinate2D, locationName: String) async throws -> Weather {
        isLoading = true
        errorMessage = nil
        
        do {
            // Step 1: Get grid point from coordinates
            let gridPointURL = "\(baseURL)/points/\(coordinate.latitude),\(coordinate.longitude)"
            guard let url = URL(string: gridPointURL) else {
                throw WeatherError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw WeatherError.invalidResponse
            }
            
            let gridPointResponse = try JSONDecoder().decode(GridPointResponse.self, from: data)
            
            // Step 2: Get forecast from grid point
            guard let forecastURLString = gridPointResponse.properties.forecast,
                  let forecastURL = URL(string: forecastURLString) else {
                throw WeatherError.missingForecastURL
            }
            
            var forecastRequest = URLRequest(url: forecastURL)
            forecastRequest.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
            forecastRequest.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (forecastData, forecastResponse) = try await URLSession.shared.data(for: forecastRequest)
            
            guard let forecastHttpResponse = forecastResponse as? HTTPURLResponse,
                  forecastHttpResponse.statusCode == 200 else {
                throw WeatherError.invalidResponse
            }
            
            let forecast = try JSONDecoder().decode(ForecastResponse.self, from: forecastData)
            
            // Step 3: Get observation/stations for current conditions
            var observation: ObservationResponse?
            if let observationStationsURLString = gridPointResponse.properties.observationStations,
               let observationStationsURL = URL(string: observationStationsURLString) {
                do {
                    var stationsRequest = URLRequest(url: observationStationsURL)
                    stationsRequest.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
                    stationsRequest.setValue("application/json", forHTTPHeaderField: "Accept")
                    
                    let (stationsData, _) = try await URLSession.shared.data(for: stationsRequest)
                    let stationsResponse = try JSONDecoder().decode(StationsResponse.self, from: stationsData)
                    
                    if let nearestStation = stationsResponse.features.first?.properties.stationIdentifier {
                        let observationURLString = "\(baseURL)/stations/\(nearestStation)/observations/latest"
                        if let observationURL = URL(string: observationURLString) {
                            var obsRequest = URLRequest(url: observationURL)
                            obsRequest.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
                            obsRequest.setValue("application/json", forHTTPHeaderField: "Accept")
                            
                            let (obsData, _) = try await URLSession.shared.data(for: obsRequest)
                            observation = try? JSONDecoder().decode(ObservationResponse.self, from: obsData)
                        }
                    }
                } catch {
                    // Observation is optional, continue without it
                    print("Could not fetch observation: \(error.localizedDescription)")
                }
            }
            
            // Parse weather data
            let weather = parseWeatherData(
                forecast: forecast,
                observation: observation,
                coordinate: coordinate,
                locationName: locationName
            )
            
            isLoading = false
            return weather
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Private Helpers
    
    private func parseWeatherData(
        forecast: ForecastResponse,
        observation: ObservationResponse?,
        coordinate: CLLocationCoordinate2D,
        locationName: String
    ) -> Weather {
        // Get current period (first period in forecast)
        guard let currentPeriod = forecast.properties.periods.first else {
            // Fallback if no periods available
            return Weather(
                location: locationName,
                coordinate: coordinate,
                temperature: 0,
                temperatureMin: nil,
                temperatureMax: nil,
                condition: "No data available",
                conditionIcon: "cloud.slash.fill",
                windSpeed: 0,
                windDirection: "N",
                windDirectionDegrees: nil,
                windGust: nil,
                humidity: 50,
                cloudCover: nil,
                precipitation: 0,
                lowAltCloud: nil,
                highAltCloud: nil,
                sunrise: nil,
                sunset: nil,
                lastUpdated: Date()
            )
        }
        
        // Extract temperature from observation if available, otherwise use forecast
        let temperature = observation?.properties.temperature?.value ?? Double(currentPeriod.temperature ?? 0)
        
        // Get min/max from forecast periods
        var temperatureMin: Double?
        var temperatureMax: Double?
        
        // Look for today's period for min/max
        let todayPeriods = forecast.properties.periods.prefix(2)
        if todayPeriods.count >= 2 {
            let dayPeriod = todayPeriods.first { $0.isDaytime }
            let nightPeriod = todayPeriods.first { !$0.isDaytime }
            
            if let day = dayPeriod {
                temperatureMax = Double(day.temperature ?? 0)
            }
            if let night = nightPeriod {
                temperatureMin = Double(night.temperature ?? 0)
            }
        }
        
        // Wind information
        var windSpeed: Double = 0.0
        if let obsWindSpeed = observation?.properties.windSpeed?.value {
            // Convert from m/s to mph
            windSpeed = obsWindSpeed * 2.237
        } else if let forecastWindSpeed = currentPeriod.windSpeed {
            // Parse forecast wind speed (e.g., "5 to 10 mph")
            let speedString = forecastWindSpeed.components(separatedBy: " ").first ?? "0"
            windSpeed = Double(speedString) ?? 0.0
        }
        
        let windDirection = currentPeriod.windDirection ?? "N"
        // Prefer observation wind direction degrees if available, otherwise parse from cardinal direction
        let windDirectionDegrees = observation?.properties.windDirection?.value.map { Int($0) } ?? parseWindDirectionDegrees(from: windDirection)
        var windGust: Double? = nil
        if let gustValue = observation?.properties.windGust?.value {
            // Convert from m/s to mph
            windGust = gustValue * 2.237
        }
        
        // Other metrics
        let humidity = observation?.properties.relativeHumidity?.value ?? 50
        
        // Cloud cover estimation from forecast description
        let cloudCover = estimateCloudCover(from: currentPeriod.shortForecast)
        let precipitation = currentPeriod.probabilityOfPrecipitation?.value ?? 0
        
        // Cloud levels (not directly available, estimate)
        let lowAltCloud: Int? = nil
        let highAltCloud: Int? = cloudCover
        
        // Sunrise/Sunset - calculate from coordinate and date
        let (sunrise, sunset) = calculateSunriseSunset(coordinate: coordinate)
        
        // Condition icon based on forecast
        let conditionIcon = getConditionIcon(from: currentPeriod.shortForecast)
        
        return Weather(
            location: locationName,
            coordinate: coordinate,
            temperature: temperature,
            temperatureMin: temperatureMin,
            temperatureMax: temperatureMax,
            condition: currentPeriod.shortForecast,
            conditionIcon: conditionIcon,
            windSpeed: windSpeed,
            windDirection: windDirection,
            windDirectionDegrees: windDirectionDegrees,
            windGust: windGust,
            humidity: humidity,
            cloudCover: cloudCover,
            precipitation: precipitation,
            lowAltCloud: lowAltCloud,
            highAltCloud: highAltCloud,
            sunrise: sunrise,
            sunset: sunset,
            lastUpdated: Date()
        )
    }
    
    private func estimateCloudCover(from forecast: String) -> Int? {
        let lowercased = forecast.lowercased()
        if lowercased.contains("clear") || lowercased.contains("sunny") {
            return 0
        } else if lowercased.contains("mostly clear") || lowercased.contains("mostly sunny") {
            return 25
        } else if lowercased.contains("partly cloudy") || lowercased.contains("partly sunny") {
            return 50
        } else if lowercased.contains("mostly cloudy") {
            return 75
        } else if lowercased.contains("cloudy") || lowercased.contains("overcast") {
            return 100
        }
        return nil
    }
    
    private func getConditionIcon(from forecast: String) -> String {
        let lowercased = forecast.lowercased()
        if lowercased.contains("sunny") || lowercased.contains("clear") {
            return "sun.max.fill"
        } else if lowercased.contains("cloudy") || lowercased.contains("overcast") {
            return "cloud.fill"
        } else if lowercased.contains("rain") || lowercased.contains("shower") {
            return "cloud.rain.fill"
        } else if lowercased.contains("snow") {
            return "cloud.snow.fill"
        } else if lowercased.contains("thunder") || lowercased.contains("storm") {
            return "cloud.bolt.fill"
        } else if lowercased.contains("fog") || lowercased.contains("mist") {
            return "cloud.fog.fill"
        }
        return "cloud.fill"
    }
    
    private func parseWindDirectionDegrees(from direction: String) -> Int? {
        // Convert cardinal direction to degrees
        // Wind direction is where wind is coming FROM (meteorological convention)
        let directionMap: [String: Int] = [
            "N": 0, "NNE": 22, "NE": 45, "ENE": 67,
            "E": 90, "ESE": 112, "SE": 135, "SSE": 157,
            "S": 180, "SSW": 202, "SW": 225, "WSW": 247,
            "W": 270, "WNW": 292, "NW": 315, "NNW": 337
        ]
        
        // Try exact match first
        if let degrees = directionMap[direction.uppercased()] {
            return degrees
        }
        
        // Try to parse if it's already in degrees format (e.g., "292°")
        let cleaned = direction.replacingOccurrences(of: "°", with: "").trimmingCharacters(in: .whitespaces)
        if let degrees = Int(cleaned) {
            return degrees % 360
        }
        
        return nil
    }
    
    private func calculateSunriseSunset(coordinate: CLLocationCoordinate2D) -> (sunrise: Date?, sunset: Date?) {
        let calendar = Calendar.current
        let today = Date()
        
        // Simple approximation based on latitude and time of year
        // In production, use a proper astronomical calculation library
        let latitude = coordinate.latitude
        
        // Approximate sunrise/sunset times based on latitude
        // This is a simplified calculation - for accuracy, use a library like SunCalc
        var sunriseHour = 6
        var sunsetHour = 18
        
        // Adjust based on latitude (very simplified)
        if abs(latitude) > 40 {
            // Higher latitudes have more variation, but we'll use defaults
            sunriseHour = 7
            sunsetHour = 17
        }
        
        let sunrise = calendar.date(bySettingHour: sunriseHour, minute: 30, second: 0, of: today)
        let sunset = calendar.date(bySettingHour: sunsetHour, minute: 30, second: 0, of: today)
        
        return (sunrise, sunset)
    }
}

// MARK: - Weather Error

enum WeatherError: LocalizedError {
    case invalidURL
    case invalidResponse
    case missingForecastURL
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from weather service"
        case .missingForecastURL:
            return "Missing forecast URL"
        case .parsingError:
            return "Error parsing weather data"
        }
    }
}

// MARK: - API Response Models

struct GridPointResponse: Codable {
    let properties: GridPointProperties
}

struct GridPointProperties: Codable {
    let forecast: String?
    let forecastHourly: String?
    let observationStations: String?
    
    enum CodingKeys: String, CodingKey {
        case forecast
        case forecastHourly = "forecastHourly"
        case observationStations
    }
}

struct ForecastResponse: Codable {
    let properties: ForecastProperties
}

struct ForecastProperties: Codable {
    let periods: [ForecastPeriod]
}

struct ForecastPeriod: Codable {
    let number: Int
    let name: String
    let startTime: String
    let endTime: String
    let isDaytime: Bool
    let temperature: Int?
    let temperatureUnit: String?
    let windSpeed: String?
    let windDirection: String?
    let shortForecast: String
    let detailedForecast: String
    let probabilityOfPrecipitation: ProbabilityOfPrecipitation?
}

struct ProbabilityOfPrecipitation: Codable {
    let value: Int?
}

struct StationsResponse: Codable {
    let features: [StationFeature]
}

struct StationFeature: Codable {
    let properties: StationProperties
}

struct StationProperties: Codable {
    let stationIdentifier: String
    
    enum CodingKeys: String, CodingKey {
        case stationIdentifier = "stationIdentifier"
    }
}

struct ObservationResponse: Codable {
    let properties: ObservationProperties
}

struct ObservationProperties: Codable {
    let temperature: TemperatureValue?
    let windSpeed: SpeedValue?
    let windDirection: AngleValue?
    let windGust: SpeedValue?
    let relativeHumidity: HumidityValue?
    let visibility: DistanceValue?
}

struct AngleValue: Codable {
    let value: Double? // degrees
}

struct TemperatureValue: Codable {
    let value: Double?
}

struct SpeedValue: Codable {
    let value: Double? // meters per second, convert to mph
}

struct HumidityValue: Codable {
    let value: Int?
}

struct DistanceValue: Codable {
    let value: Double? // meters
}

