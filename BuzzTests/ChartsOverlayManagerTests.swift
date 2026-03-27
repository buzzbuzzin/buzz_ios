//
//  ChartsOverlayManagerTests.swift
//  BuzzTests
//

import XCTest
import MapKit
@testable import Buzz

final class ChartsOverlayManagerTests: XCTestCase {

    @MainActor
    func testPerformLocationQuery_latestRequestWins() async {
        let overlayMETAR = MockChartsMETARService()
        let queryMETAR = MockChartsMETARService()
        let detailMETAR = MockChartsMETARService()
        let tafService = MockChartsTAFService()
        let airspaceService = MockChartsAirspaceService()
        let geometryService = MockChartsAirspaceGeometryService()

        let firstCoordinate = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let secondCoordinate = CLLocationCoordinate2D(latitude: 38.0, longitude: -123.0)

        airspaceService.setResponse(.success(
            snapshot: AirspaceQuerySnapshot(airspaceClass: .classB, laancGridCeiling: 100, hasLAANCCoverage: true),
            delayNanoseconds: 200_000_000
        ), for: firstCoordinate)
        airspaceService.setResponse(.success(
            snapshot: AirspaceQuerySnapshot(airspaceClass: .classG, laancGridCeiling: nil, hasLAANCCoverage: false),
            delayNanoseconds: 20_000_000
        ), for: secondCoordinate)

        queryMETAR.setResponse(.success(
            metars: [Self.sampleMETAR(stationId: "KOLD", coordinate: firstCoordinate)],
            delayNanoseconds: 200_000_000
        ), for: firstCoordinate)
        queryMETAR.setResponse(.success(
            metars: [Self.sampleMETAR(stationId: "KNEW", coordinate: secondCoordinate)],
            delayNanoseconds: 20_000_000
        ), for: secondCoordinate)

        let manager = ChartsOverlayManager(
            overlayMETARService: overlayMETAR,
            queryMETARService: queryMETAR,
            detailMETARService: detailMETAR,
            detailTAFService: tafService,
            airspaceService: airspaceService,
            airspaceGeometryService: geometryService,
            regionChangeDebounceInterval: 0
        )

        let firstTask = Task { await manager.performLocationQuery(coordinate: firstCoordinate) }
        try? await Task.sleep(nanoseconds: 20_000_000)
        let secondTask = Task { await manager.performLocationQuery(coordinate: secondCoordinate) }

        await firstTask.value
        await secondTask.value

        guard let result = manager.queryResult else {
            XCTFail("Expected a query result for the latest request")
            return
        }

        XCTAssertEqual(result.coordinate.latitude, secondCoordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(result.coordinate.longitude, secondCoordinate.longitude, accuracy: 0.0001)
        XCTAssertEqual(result.nearestMETAR?.stationId, "KNEW")
        XCTAssertEqual(result.airspaceClass, .classG)
        XCTAssertNil(manager.queryErrorMessage)
    }

    @MainActor
    func testPerformLocationQuery_fallsBackToUnavailableAirspaceStateOnFailure() async {
        let overlayMETAR = MockChartsMETARService()
        let queryMETAR = MockChartsMETARService()
        let detailMETAR = MockChartsMETARService()
        let tafService = MockChartsTAFService()
        let airspaceService = MockChartsAirspaceService()
        let geometryService = MockChartsAirspaceGeometryService()

        let coordinate = CLLocationCoordinate2D(latitude: 35.0, longitude: -121.0)
        airspaceService.setResponse(.failure(
            MockChartsError.generic,
            delayNanoseconds: 10_000_000
        ), for: coordinate)
        queryMETAR.setResponse(.success(
            metars: [Self.sampleMETAR(stationId: "KERR", coordinate: coordinate)],
            delayNanoseconds: 10_000_000
        ), for: coordinate)

        let manager = ChartsOverlayManager(
            overlayMETARService: overlayMETAR,
            queryMETARService: queryMETAR,
            detailMETARService: detailMETAR,
            detailTAFService: tafService,
            airspaceService: airspaceService,
            airspaceGeometryService: geometryService,
            regionChangeDebounceInterval: 0
        )

        await manager.performLocationQuery(coordinate: coordinate)

        guard let result = manager.queryResult else {
            XCTFail("Expected a query result even when airspace fetch fails")
            return
        }

        XCTAssertEqual(result.airspaceClass, .unknown)
        XCTAssertNil(result.laancCeiling)
        XCTAssertFalse(result.hasLAANCCoverage)
        XCTAssertEqual(result.authorizationStatus, .notApplicable)
        XCTAssertEqual(result.nearestMETAR?.stationId, "KERR")
        XCTAssertEqual(
            manager.queryErrorMessage,
            "Airspace details are unavailable for this point right now."
        )
    }

    @MainActor
    func testOnRegionChanged_latestViewportWins() async {
        let overlayMETAR = MockChartsMETARService()
        let queryMETAR = MockChartsMETARService()
        let detailMETAR = MockChartsMETARService()
        let tafService = MockChartsTAFService()
        let airspaceService = MockChartsAirspaceService()
        let geometryService = MockChartsAirspaceGeometryService()

        let firstRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        let secondRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 41.0, longitude: -75.0),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )

        overlayMETAR.setResponse(.success(
            metars: [Self.sampleMETAR(stationId: "KOLD", coordinate: firstRegion.center)],
            delayNanoseconds: 250_000_000
        ), for: firstRegion.center)
        overlayMETAR.setResponse(.success(
            metars: [Self.sampleMETAR(stationId: "KNEW", coordinate: secondRegion.center)],
            delayNanoseconds: 20_000_000
        ), for: secondRegion.center)

        let manager = ChartsOverlayManager(
            overlayMETARService: overlayMETAR,
            queryMETARService: queryMETAR,
            detailMETARService: detailMETAR,
            detailTAFService: tafService,
            airspaceService: airspaceService,
            airspaceGeometryService: geometryService,
            regionChangeDebounceInterval: 0.01
        )

        manager.showAirspaceOverlay = false
        manager.onRegionChanged(region: firstRegion)
        try? await Task.sleep(nanoseconds: 30_000_000)
        manager.onRegionChanged(region: secondRegion)
        try? await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertEqual(manager.metarAnnotations.map(\.metar.stationId), ["KNEW"])
    }

    @MainActor
    func testOnRegionChanged_failurePublishesOverlayErrorMessage() async {
        let overlayMETAR = MockChartsMETARService()
        let queryMETAR = MockChartsMETARService()
        let detailMETAR = MockChartsMETARService()
        let tafService = MockChartsTAFService()
        let airspaceService = MockChartsAirspaceService()
        let geometryService = MockChartsAirspaceGeometryService()

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.0, longitude: -76.0),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )

        overlayMETAR.setResponse(.failure(
            MockChartsError.generic,
            delayNanoseconds: 10_000_000
        ), for: region.center)

        let manager = ChartsOverlayManager(
            overlayMETARService: overlayMETAR,
            queryMETARService: queryMETAR,
            detailMETARService: detailMETAR,
            detailTAFService: tafService,
            airspaceService: airspaceService,
            airspaceGeometryService: geometryService,
            regionChangeDebounceInterval: 0.01
        )

        manager.showAirspaceOverlay = false
        manager.onRegionChanged(region: region)
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(
            manager.overlayErrorMessage,
            "Some chart overlays could not be refreshed. Check your connection and try again."
        )
    }

    private static func sampleMETAR(
        stationId: String,
        coordinate: CLLocationCoordinate2D,
        flightCategory: FlightCategory = .vfr
    ) -> METAR {
        METAR(
            id: "\(stationId)-sample",
            stationId: stationId,
            stationName: stationId,
            rawText: "\(stationId) 010000Z 18005KT 10SM CLR 18/12 A2992",
            observationTime: Date(),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            temperature: 18,
            dewpoint: 12,
            windDirection: 180,
            windSpeed: 5,
            windGust: nil,
            visibility: 10,
            altimeter: 29.92,
            flightCategory: flightCategory,
            clouds: [],
            weatherPhenomena: nil
        )
    }
}

private enum MockChartsError: LocalizedError {
    case generic

    var errorDescription: String? {
        "Mock charts failure"
    }
}

@MainActor
private final class MockChartsMETARService: ChartsMETARProviding {
    struct Response {
        let metars: [METAR]
        let error: Error?
        let delayNanoseconds: UInt64
    }

    private(set) var responses: [String: Response] = [:]

    static func key(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }

    func fetchMETARsNearLocation(
        coordinate: CLLocationCoordinate2D,
        radiusDegrees: Double,
        maxResults: Int,
        forceRefresh: Bool
    ) async throws -> [METAR] {
        let response = responses[Self.key(for: coordinate)] ?? Response(metars: [], error: nil, delayNanoseconds: 0)

        if response.delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: response.delayNanoseconds)
        }

        if let error = response.error {
            throw error
        }

        return response.metars
    }

    func setResponse(_ response: Response, for coordinate: CLLocationCoordinate2D) {
        responses[Self.key(for: coordinate)] = response
    }
}

private extension MockChartsMETARService.Response {
    static func success(metars: [METAR], delayNanoseconds: UInt64) -> MockChartsMETARService.Response {
        MockChartsMETARService.Response(metars: metars, error: nil, delayNanoseconds: delayNanoseconds)
    }

    static func failure(_ error: Error, delayNanoseconds: UInt64) -> MockChartsMETARService.Response {
        MockChartsMETARService.Response(metars: [], error: error, delayNanoseconds: delayNanoseconds)
    }
}

@MainActor
private final class MockChartsTAFService: ChartsTAFProviding {
    func fetchTAFsNearLocation(
        coordinate: CLLocationCoordinate2D,
        radiusDegrees: Double,
        forceRefresh: Bool
    ) async throws -> [TAF] {
        []
    }
}

@MainActor
private final class MockChartsAirspaceService: ChartsAirspaceQueryProviding {
    struct Response {
        let result: Result<AirspaceQuerySnapshot, Error>
        let delayNanoseconds: UInt64
    }

    private let calculator = ArcGISAirspaceService()
    private(set) var responses: [String: Response] = [:]

    static func key(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }

    func fetchAirspaceSnapshot(
        coordinate: CLLocationCoordinate2D,
        persistResult: Bool
    ) async throws -> AirspaceQuerySnapshot {
        let response = responses[Self.key(for: coordinate)] ?? Response(
            result: .success(.unavailable),
            delayNanoseconds: 0
        )

        if response.delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: response.delayNanoseconds)
        }

        return try response.result.get()
    }

    func calculateAuthorizationStatus(
        requestedAltitude: Int,
        laancCeiling: Int?,
        airspaceClass: AirspaceClass,
        hasLAANCCoverage: Bool
    ) -> LAANCAuthorizationStatus {
        calculator.calculateAuthorizationStatus(
            requestedAltitude: requestedAltitude,
            laancCeiling: laancCeiling,
            airspaceClass: airspaceClass,
            hasLAANCCoverage: hasLAANCCoverage
        )
    }

    func setResponse(_ response: Response, for coordinate: CLLocationCoordinate2D) {
        responses[Self.key(for: coordinate)] = response
    }
}

private extension MockChartsAirspaceService.Response {
    static func success(snapshot: AirspaceQuerySnapshot, delayNanoseconds: UInt64) -> MockChartsAirspaceService.Response {
        MockChartsAirspaceService.Response(result: .success(snapshot), delayNanoseconds: delayNanoseconds)
    }

    static func failure(_ error: Error, delayNanoseconds: UInt64) -> MockChartsAirspaceService.Response {
        MockChartsAirspaceService.Response(result: .failure(error), delayNanoseconds: delayNanoseconds)
    }
}

@MainActor
private final class MockChartsAirspaceGeometryService: ChartsAirspaceGeometryProviding {
    func fetchAirspacePolygons(for region: MKCoordinateRegion) async throws -> [AirspaceOverlayPolygon] {
        []
    }
}
