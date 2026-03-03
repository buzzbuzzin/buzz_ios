import Foundation
import Testing
@testable import Buzz

struct OpenMeteoUtilsTests {

    // MARK: - mapWMOWeatherCode

    @Test func mapWMOWeatherCode_clear() {
        let result = OpenMeteoUtils.mapWMOWeatherCode(0)
        #expect(result.condition == "Clear sky")
        #expect(result.icon == "sun.max.fill")
    }

    @Test func mapWMOWeatherCode_partlyCloudy() {
        let result = OpenMeteoUtils.mapWMOWeatherCode(2)
        #expect(result.condition == "Partly cloudy")
        #expect(result.icon == "cloud.sun.fill")
    }

    @Test func mapWMOWeatherCode_overcast() {
        let result = OpenMeteoUtils.mapWMOWeatherCode(3)
        #expect(result.condition == "Overcast")
        #expect(result.icon == "cloud.fill")
    }

    @Test func mapWMOWeatherCode_fog() {
        let result = OpenMeteoUtils.mapWMOWeatherCode(45)
        #expect(result.condition == "Fog")
        #expect(result.icon == "cloud.fog.fill")
    }

    @Test func mapWMOWeatherCode_lightRain() {
        let result = OpenMeteoUtils.mapWMOWeatherCode(61)
        #expect(result.condition == "Light rain")
        #expect(result.icon == "cloud.rain.fill")
    }

    @Test func mapWMOWeatherCode_snow() {
        let result = OpenMeteoUtils.mapWMOWeatherCode(73)
        #expect(result.condition == "Snow")
        #expect(result.icon == "cloud.snow.fill")
    }

    @Test func mapWMOWeatherCode_thunderstorm() {
        let result = OpenMeteoUtils.mapWMOWeatherCode(95)
        #expect(result.condition == "Thunderstorm")
        #expect(result.icon == "cloud.bolt.fill")
    }

    @Test func mapWMOWeatherCode_thunderstormWithHail() {
        let result = OpenMeteoUtils.mapWMOWeatherCode(99)
        #expect(result.condition == "Thunderstorm with hail")
        #expect(result.icon == "cloud.bolt.rain.fill")
    }

    @Test func mapWMOWeatherCode_unknown() {
        let result = OpenMeteoUtils.mapWMOWeatherCode(999)
        #expect(result.condition == "Unknown")
        #expect(result.icon == "cloud.fill")
    }

    // MARK: - cardinalDirection

    @Test func cardinalDirection_north() {
        #expect(OpenMeteoUtils.cardinalDirection(from: 0) == "N")
    }

    @Test func cardinalDirection_northEast() {
        #expect(OpenMeteoUtils.cardinalDirection(from: 45) == "NE")
    }

    @Test func cardinalDirection_east() {
        #expect(OpenMeteoUtils.cardinalDirection(from: 90) == "E")
    }

    @Test func cardinalDirection_southEast() {
        #expect(OpenMeteoUtils.cardinalDirection(from: 135) == "SE")
    }

    @Test func cardinalDirection_south() {
        #expect(OpenMeteoUtils.cardinalDirection(from: 180) == "S")
    }

    @Test func cardinalDirection_southWest() {
        #expect(OpenMeteoUtils.cardinalDirection(from: 225) == "SW")
    }

    @Test func cardinalDirection_west() {
        #expect(OpenMeteoUtils.cardinalDirection(from: 270) == "W")
    }

    @Test func cardinalDirection_northWest() {
        #expect(OpenMeteoUtils.cardinalDirection(from: 315) == "NW")
    }

    @Test func cardinalDirection_justBelow360() {
        #expect(OpenMeteoUtils.cardinalDirection(from: 359) == "N")
    }

    @Test func cardinalDirection_boundaryStillNorth() {
        #expect(OpenMeteoUtils.cardinalDirection(from: 11) == "N")
    }
}
