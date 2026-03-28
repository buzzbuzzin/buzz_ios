import Foundation
import CoreLocation
import Testing
@testable import Buzz

struct WeatherServiceTests {

    // MARK: - WeatherOpenMeteoResponse decoding

    @Test func decodeCompleteOpenMeteoResponse() throws {
        let json = """
        {
            "current": {
                "temperature_2m": 45.2,
                "relative_humidity_2m": 65,
                "wind_speed_10m": 12.5,
                "wind_direction_10m": 225,
                "wind_gusts_10m": 18.3,
                "weather_code": 2,
                "cloud_cover": 40
            },
            "daily": {
                "temperature_2m_max": [52.1],
                "temperature_2m_min": [38.4],
                "sunrise": ["2026-03-03T07:15"],
                "sunset": ["2026-03-03T18:30"]
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WeatherOpenMeteoResponse.self, from: json)

        #expect(response.current.temperature2m == 45.2)
        #expect(response.current.relativeHumidity2m == 65)
        #expect(response.current.windSpeed10m == 12.5)
        #expect(response.current.windDirection10m == 225)
        #expect(response.current.windGusts10m == 18.3)
        #expect(response.current.weatherCode == 2)
        #expect(response.current.cloudCover == 40)

        let daily = try #require(response.daily)
        #expect(daily.temperature2mMax == [52.1])
        #expect(daily.temperature2mMin == [38.4])
        #expect(daily.sunrise == ["2026-03-03T07:15"])
        #expect(daily.sunset == ["2026-03-03T18:30"])
    }

    @Test func decodeOpenMeteoResponseWithNullDaily() throws {
        let json = """
        {
            "current": {
                "temperature_2m": 72.0,
                "relative_humidity_2m": 50,
                "wind_speed_10m": 5.0,
                "wind_direction_10m": 180,
                "wind_gusts_10m": 8.0,
                "weather_code": 0,
                "cloud_cover": 10
            },
            "daily": null
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WeatherOpenMeteoResponse.self, from: json)

        #expect(response.current.temperature2m == 72.0)
        #expect(response.daily == nil)
    }

    @Test func decodeOpenMeteoResponseWithMissingDaily() throws {
        let json = """
        {
            "current": {
                "temperature_2m": 72.0,
                "relative_humidity_2m": 50,
                "wind_speed_10m": 5.0,
                "wind_direction_10m": 180,
                "wind_gusts_10m": 8.0,
                "weather_code": 0,
                "cloud_cover": 10
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WeatherOpenMeteoResponse.self, from: json)

        #expect(response.current.weatherCode == 0)
        #expect(response.daily == nil)
    }

    // MARK: - WeatherOpenMeteoCurrent decoding

    @Test func decodeOpenMeteoCurrentAllFields() throws {
        let json = """
        {
            "temperature_2m": -5.3,
            "relative_humidity_2m": 92,
            "wind_speed_10m": 25.7,
            "wind_direction_10m": 315,
            "wind_gusts_10m": 42.1,
            "weather_code": 71,
            "cloud_cover": 100
        }
        """.data(using: .utf8)!

        let current = try JSONDecoder().decode(WeatherOpenMeteoCurrent.self, from: json)

        #expect(current.temperature2m == -5.3)
        #expect(current.relativeHumidity2m == 92)
        #expect(current.windSpeed10m == 25.7)
        #expect(current.windDirection10m == 315)
        #expect(current.windGusts10m == 42.1)
        #expect(current.weatherCode == 71)
        #expect(current.cloudCover == 100)
    }

    @Test func decodeOpenMeteoCurrentZeroValues() throws {
        let json = """
        {
            "temperature_2m": 0.0,
            "relative_humidity_2m": 0,
            "wind_speed_10m": 0.0,
            "wind_direction_10m": 0,
            "wind_gusts_10m": 0.0,
            "weather_code": 0,
            "cloud_cover": 0
        }
        """.data(using: .utf8)!

        let current = try JSONDecoder().decode(WeatherOpenMeteoCurrent.self, from: json)

        #expect(current.temperature2m == 0.0)
        #expect(current.relativeHumidity2m == 0)
        #expect(current.windSpeed10m == 0.0)
        #expect(current.windDirection10m == 0)
        #expect(current.windGusts10m == 0.0)
        #expect(current.weatherCode == 0)
        #expect(current.cloudCover == 0)
    }

    // MARK: - WeatherOpenMeteoDaily decoding

    @Test func decodeDailyWithNullValuesInArrays() throws {
        let json = """
        {
            "temperature_2m_max": [null, 72.5],
            "temperature_2m_min": [null, 55.0],
            "sunrise": [null, "2026-03-03T07:15"],
            "sunset": [null, "2026-03-03T18:30"]
        }
        """.data(using: .utf8)!

        let daily = try JSONDecoder().decode(WeatherOpenMeteoDaily.self, from: json)

        #expect(daily.temperature2mMax.count == 2)
        #expect(daily.temperature2mMax[0] == nil)
        #expect(daily.temperature2mMax[1] == 72.5)

        #expect(daily.temperature2mMin.count == 2)
        #expect(daily.temperature2mMin[0] == nil)
        #expect(daily.temperature2mMin[1] == 55.0)

        #expect(daily.sunrise.count == 2)
        #expect(daily.sunrise[0] == nil)
        #expect(daily.sunrise[1] == "2026-03-03T07:15")

        #expect(daily.sunset.count == 2)
        #expect(daily.sunset[0] == nil)
        #expect(daily.sunset[1] == "2026-03-03T18:30")
    }

    @Test func decodeDailyWithAllNullValues() throws {
        let json = """
        {
            "temperature_2m_max": [null],
            "temperature_2m_min": [null],
            "sunrise": [null],
            "sunset": [null]
        }
        """.data(using: .utf8)!

        let daily = try JSONDecoder().decode(WeatherOpenMeteoDaily.self, from: json)

        #expect(daily.temperature2mMax == [nil])
        #expect(daily.temperature2mMin == [nil])
        #expect(daily.sunrise == [nil])
        #expect(daily.sunset == [nil])
    }

    @Test func decodeDailyWithMultipleDays() throws {
        let json = """
        {
            "temperature_2m_max": [52.1, 55.3, 48.9],
            "temperature_2m_min": [38.4, 40.1, 35.2],
            "sunrise": ["2026-03-03T07:15", "2026-03-04T07:14", "2026-03-05T07:12"],
            "sunset": ["2026-03-03T18:30", "2026-03-04T18:31", "2026-03-05T18:33"]
        }
        """.data(using: .utf8)!

        let daily = try JSONDecoder().decode(WeatherOpenMeteoDaily.self, from: json)

        #expect(daily.temperature2mMax.count == 3)
        #expect(daily.temperature2mMax[0] == 52.1)
        #expect(daily.temperature2mMax[2] == 48.9)
        #expect(daily.temperature2mMin.count == 3)
        #expect(daily.sunrise.count == 3)
        #expect(daily.sunset.count == 3)
    }

    // MARK: - Canadian Location: Open-Meteo Data Pipeline

    /// Simulates Toronto winter weather (snow, -5°C/23°F, strong winds)
    /// Verifies the Open-Meteo → Weather mapping produces correct fields
    @Test func openMeteoToWeather_torontoWinterSnow() throws {
        let json = """
        {
            "current": {
                "temperature_2m": 23.0,
                "relative_humidity_2m": 88,
                "wind_speed_10m": 22.4,
                "wind_direction_10m": 315,
                "wind_gusts_10m": 35.2,
                "weather_code": 73,
                "cloud_cover": 95
            },
            "daily": {
                "temperature_2m_max": [28.4],
                "temperature_2m_min": [18.0],
                "sunrise": ["2026-03-03T07:05"],
                "sunset": ["2026-03-03T18:15"]
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WeatherOpenMeteoResponse.self, from: json)

        // Verify Open-Meteo fields decode for Canadian winter data
        #expect(response.current.temperature2m == 23.0)
        #expect(response.current.relativeHumidity2m == 88)
        #expect(response.current.windSpeed10m == 22.4)
        #expect(response.current.windDirection10m == 315)
        #expect(response.current.windGusts10m == 35.2)
        #expect(response.current.weatherCode == 73) // Snow

        // Verify WMO code mapping for snow
        let (condition, icon) = OpenMeteoUtils.mapWMOWeatherCode(response.current.weatherCode)
        #expect(condition == "Snow")
        #expect(icon == "cloud.snow.fill")

        // Verify cardinal direction for NW wind
        let windDir = OpenMeteoUtils.cardinalDirection(from: response.current.windDirection10m)
        #expect(windDir == "NW")

        // Verify daily data for Toronto
        let daily = try #require(response.daily)
        #expect(daily.temperature2mMax[0] == 28.4)
        #expect(daily.temperature2mMin[0] == 18.0)
    }

    /// Simulates Vancouver fog/drizzle conditions
    @Test func openMeteoToWeather_vancouverFog() throws {
        let json = """
        {
            "current": {
                "temperature_2m": 46.4,
                "relative_humidity_2m": 95,
                "wind_speed_10m": 5.6,
                "wind_direction_10m": 180,
                "wind_gusts_10m": 8.9,
                "weather_code": 45,
                "cloud_cover": 100
            },
            "daily": {
                "temperature_2m_max": [50.0],
                "temperature_2m_min": [42.8],
                "sunrise": ["2026-03-03T07:30"],
                "sunset": ["2026-03-03T18:00"]
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WeatherOpenMeteoResponse.self, from: json)

        #expect(response.current.weatherCode == 45) // Fog
        let (condition, icon) = OpenMeteoUtils.mapWMOWeatherCode(response.current.weatherCode)
        #expect(condition == "Fog")
        #expect(icon == "cloud.fog.fill")

        let windDir = OpenMeteoUtils.cardinalDirection(from: response.current.windDirection10m)
        #expect(windDir == "S")
    }

    /// Simulates Montreal freezing rain (common Canadian hazard)
    @Test func openMeteoToWeather_montrealFreezingRain() throws {
        let json = """
        {
            "current": {
                "temperature_2m": 30.2,
                "relative_humidity_2m": 92,
                "wind_speed_10m": 11.2,
                "wind_direction_10m": 45,
                "wind_gusts_10m": 18.0,
                "weather_code": 66,
                "cloud_cover": 100
            },
            "daily": {
                "temperature_2m_max": [33.8],
                "temperature_2m_min": [26.6],
                "sunrise": ["2026-03-03T06:55"],
                "sunset": ["2026-03-03T18:20"]
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WeatherOpenMeteoResponse.self, from: json)

        let (condition, icon) = OpenMeteoUtils.mapWMOWeatherCode(response.current.weatherCode)
        #expect(condition == "Freezing rain")
        #expect(icon == "cloud.sleet.fill")

        let windDir = OpenMeteoUtils.cardinalDirection(from: response.current.windDirection10m)
        #expect(windDir == "NE")

        // Verify below-freezing temp decoded correctly
        #expect(response.current.temperature2m == 30.2)
    }

    // MARK: - US Location: Open-Meteo Data Pipeline

    /// Simulates New York clear spring weather
    /// Verifies same pipeline works for US coordinates
    @Test func openMeteoToWeather_newYorkClearSpring() throws {
        let json = """
        {
            "current": {
                "temperature_2m": 62.5,
                "relative_humidity_2m": 45,
                "wind_speed_10m": 8.3,
                "wind_direction_10m": 225,
                "wind_gusts_10m": 12.1,
                "weather_code": 1,
                "cloud_cover": 15
            },
            "daily": {
                "temperature_2m_max": [68.0],
                "temperature_2m_min": [52.0],
                "sunrise": ["2026-03-03T06:25"],
                "sunset": ["2026-03-03T17:55"]
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WeatherOpenMeteoResponse.self, from: json)

        #expect(response.current.temperature2m == 62.5)
        #expect(response.current.weatherCode == 1) // Mainly clear

        let (condition, icon) = OpenMeteoUtils.mapWMOWeatherCode(response.current.weatherCode)
        #expect(condition == "Mainly clear")
        #expect(icon == "sun.max.fill")

        let windDir = OpenMeteoUtils.cardinalDirection(from: response.current.windDirection10m)
        #expect(windDir == "SW")
    }

    /// Simulates Miami thunderstorm
    @Test func openMeteoToWeather_miamiThunderstorm() throws {
        let json = """
        {
            "current": {
                "temperature_2m": 82.4,
                "relative_humidity_2m": 78,
                "wind_speed_10m": 18.6,
                "wind_direction_10m": 270,
                "wind_gusts_10m": 45.0,
                "weather_code": 95,
                "cloud_cover": 100
            },
            "daily": {
                "temperature_2m_max": [88.0],
                "temperature_2m_min": [75.2],
                "sunrise": ["2026-03-03T06:40"],
                "sunset": ["2026-03-03T18:25"]
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WeatherOpenMeteoResponse.self, from: json)

        let (condition, icon) = OpenMeteoUtils.mapWMOWeatherCode(response.current.weatherCode)
        #expect(condition == "Thunderstorm")
        #expect(icon == "cloud.bolt.fill")

        // Verify high gust value
        #expect(response.current.windGusts10m == 45.0)
    }

    // MARK: - Weather Object Construction from Open-Meteo (Simulates fetchWeatherFromOpenMeteo)

    /// Verifies the full Weather object can be constructed from Open-Meteo data
    /// for a Canadian location, simulating what fetchWeatherFromOpenMeteo produces
    @Test func weatherObjectFromOpenMeteo_canadianLocation() throws {
        // Simulate the Open-Meteo response for Calgary
        let json = """
        {
            "current": {
                "temperature_2m": 14.0,
                "relative_humidity_2m": 70,
                "wind_speed_10m": 30.5,
                "wind_direction_10m": 270,
                "wind_gusts_10m": 52.3,
                "weather_code": 75,
                "cloud_cover": 100
            },
            "daily": {
                "temperature_2m_max": [19.4],
                "temperature_2m_min": [5.0],
                "sunrise": ["2026-03-03T07:45"],
                "sunset": ["2026-03-03T18:35"]
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WeatherOpenMeteoResponse.self, from: json)
        let current = response.current
        let (conditionText, conditionIcon) = OpenMeteoUtils.mapWMOWeatherCode(current.weatherCode)
        let windDir = OpenMeteoUtils.cardinalDirection(from: current.windDirection10m)

        // Construct Weather the same way fetchWeatherFromOpenMeteo does
        let weather = Weather(
            location: "Calgary, AB",
            coordinate: CLLocationCoordinate2D(latitude: 51.0447, longitude: -114.0719),
            temperature: current.temperature2m,
            temperatureMin: response.daily?.temperature2mMin.first.flatMap { $0 },
            temperatureMax: response.daily?.temperature2mMax.first.flatMap { $0 },
            condition: conditionText,
            conditionIcon: conditionIcon,
            windSpeed: current.windSpeed10m,
            windDirection: windDir,
            windDirectionDegrees: current.windDirection10m,
            windGust: current.windGusts10m > 0 ? current.windGusts10m : nil,
            humidity: current.relativeHumidity2m,
            cloudCover: current.cloudCover,
            precipitation: nil,
            lowAltCloud: nil,
            highAltCloud: current.cloudCover,
            sunrise: nil,
            sunset: nil,
            lastUpdated: Date()
        )

        // Verify all Weather fields are populated correctly from Open-Meteo
        #expect(weather.location == "Calgary, AB")
        #expect(weather.temperature == 14.0)
        #expect(weather.temperatureMin == 5.0)
        #expect(weather.temperatureMax == 19.4)
        #expect(weather.condition == "Heavy snow")
        #expect(weather.conditionIcon == "cloud.snow.fill")
        #expect(weather.windSpeed == 30.5)
        #expect(weather.windDirection == "W")
        #expect(weather.windDirectionDegrees == 270)
        #expect(weather.windGust == 52.3)
        #expect(weather.humidity == 70)
        #expect(weather.cloudCover == 100)
        #expect(weather.precipitation == nil) // Open-Meteo doesn't provide probability
        #expect(weather.highAltCloud == 100)
    }

    /// Verifies Weather object construction from Open-Meteo for a US location
    @Test func weatherObjectFromOpenMeteo_usLocation() throws {
        let json = """
        {
            "current": {
                "temperature_2m": 72.0,
                "relative_humidity_2m": 50,
                "wind_speed_10m": 8.0,
                "wind_direction_10m": 180,
                "wind_gusts_10m": 0.0,
                "weather_code": 0,
                "cloud_cover": 5
            },
            "daily": {
                "temperature_2m_max": [78.0],
                "temperature_2m_min": [62.0],
                "sunrise": ["2026-03-03T06:30"],
                "sunset": ["2026-03-03T18:10"]
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WeatherOpenMeteoResponse.self, from: json)
        let current = response.current
        let (conditionText, conditionIcon) = OpenMeteoUtils.mapWMOWeatherCode(current.weatherCode)
        let windDir = OpenMeteoUtils.cardinalDirection(from: current.windDirection10m)

        let weather = Weather(
            location: "Los Angeles, CA",
            coordinate: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
            temperature: current.temperature2m,
            temperatureMin: response.daily?.temperature2mMin.first.flatMap { $0 },
            temperatureMax: response.daily?.temperature2mMax.first.flatMap { $0 },
            condition: conditionText,
            conditionIcon: conditionIcon,
            windSpeed: current.windSpeed10m,
            windDirection: windDir,
            windDirectionDegrees: current.windDirection10m,
            windGust: current.windGusts10m > 0 ? current.windGusts10m : nil,
            humidity: current.relativeHumidity2m,
            cloudCover: current.cloudCover,
            precipitation: nil,
            lowAltCloud: nil,
            highAltCloud: current.cloudCover,
            sunrise: nil,
            sunset: nil,
            lastUpdated: Date()
        )

        #expect(weather.temperature == 72.0)
        #expect(weather.condition == "Clear sky")
        #expect(weather.conditionIcon == "sun.max.fill")
        #expect(weather.windDirection == "S")
        #expect(weather.windGust == nil) // 0.0 gusts should be nil
        #expect(weather.temperatureMin == 62.0)
        #expect(weather.temperatureMax == 78.0)
    }

    @Test func normalizedICAOCode_uppercasesAndTrimsToFourCharacters() {
        #expect(" kjfk ".normalizedICAOCode == "KJFK")
        #expect("c y y z".normalizedICAOCode == "CYYZ")
        #expect("egll123".normalizedICAOCode == "EGLL")
    }

    @Test func aviationWeatherAirportDisplayName_prefersNameAndRegion() {
        let airport = AviationWeatherAirportInfo(
            icaoId: "KJFK",
            iataId: "JFK",
            faaId: "JFK",
            name: "NEW YORK/JOHN F KENNEDY INTL ",
            state: "NY",
            country: "US",
            lat: 40.6399,
            lon: -73.7787,
            elev: 4
        )

        #expect(airport.displayName == "NEW YORK/JOHN F KENNEDY INTL, NY")
        #expect(airport.coordinate?.latitude == 40.6399)
        #expect(airport.coordinate?.longitude == -73.7787)
    }

    @Test func metarSelectFreshestResponses_keepsNewestObservationPerStation() {
        let responses = [
            METARAPIResponse(
                icaoId: "KITH",
                name: "Ithaca",
                rawOb: "old",
                reportTime: "2026-03-28T03:00:00.000Z",
                lat: 42.49,
                lon: -76.45,
                temp: nil,
                dewp: nil,
                wdir: nil,
                wspd: nil,
                wgst: nil,
                visib: nil,
                altim: nil,
                fltCat: nil,
                clouds: nil,
                wxString: nil
            ),
            METARAPIResponse(
                icaoId: "KITH",
                name: "Ithaca",
                rawOb: "new",
                reportTime: "2026-03-28T04:00:00.000Z",
                lat: 42.49,
                lon: -76.45,
                temp: nil,
                dewp: nil,
                wdir: nil,
                wspd: nil,
                wgst: nil,
                visib: nil,
                altim: nil,
                fltCat: nil,
                clouds: nil,
                wxString: nil
            ),
            METARAPIResponse(
                icaoId: "KSYR",
                name: "Syracuse",
                rawOb: "syr",
                reportTime: "2026-03-28T04:00:00.000Z",
                lat: 43.11,
                lon: -76.10,
                temp: nil,
                dewp: nil,
                wdir: nil,
                wspd: nil,
                wgst: nil,
                visib: nil,
                altim: nil,
                fltCat: nil,
                clouds: nil,
                wxString: nil
            )
        ]

        let freshest = METARService.selectFreshestResponses(responses)

        #expect(freshest.count == 2)
        #expect(freshest.first(where: { $0.icaoId == "KITH" })?.rawOb == "new")
        #expect(freshest.first(where: { $0.icaoId == "KSYR" })?.rawOb == "syr")
    }
}
