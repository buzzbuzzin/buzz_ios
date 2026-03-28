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
        let overlayPIREP = MockChartsPIREPService()
        let queryPIREP = MockChartsPIREPService()
        let gairmetService = MockChartsGAIRMETService()
        let sigmetService = MockChartsSIGMETService()
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
            overlayPIREPService: overlayPIREP,
            queryPIREPService: queryPIREP,
            gairmetService: gairmetService,
            sigmetService: sigmetService,
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
        let overlayPIREP = MockChartsPIREPService()
        let queryPIREP = MockChartsPIREPService()
        let gairmetService = MockChartsGAIRMETService()
        let sigmetService = MockChartsSIGMETService()
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
            overlayPIREPService: overlayPIREP,
            queryPIREPService: queryPIREP,
            gairmetService: gairmetService,
            sigmetService: sigmetService,
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
        let overlayPIREP = MockChartsPIREPService()
        let queryPIREP = MockChartsPIREPService()
        let gairmetService = MockChartsGAIRMETService()
        let sigmetService = MockChartsSIGMETService()
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
            overlayPIREPService: overlayPIREP,
            queryPIREPService: queryPIREP,
            gairmetService: gairmetService,
            sigmetService: sigmetService,
            airspaceService: airspaceService,
            airspaceGeometryService: geometryService,
            regionChangeDebounceInterval: 0.01
        )

        manager.showPIREPOverlay = false
        manager.showGairmetOverlay = false
        manager.showSigmetOverlay = false
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
        let overlayPIREP = MockChartsPIREPService()
        let queryPIREP = MockChartsPIREPService()
        let gairmetService = MockChartsGAIRMETService()
        let sigmetService = MockChartsSIGMETService()
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
            overlayPIREPService: overlayPIREP,
            queryPIREPService: queryPIREP,
            gairmetService: gairmetService,
            sigmetService: sigmetService,
            airspaceService: airspaceService,
            airspaceGeometryService: geometryService,
            regionChangeDebounceInterval: 0.01
        )

        manager.showPIREPOverlay = false
        manager.showGairmetOverlay = false
        manager.showSigmetOverlay = false
        manager.showAirspaceOverlay = false
        manager.onRegionChanged(region: region)
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(
            manager.overlayErrorMessage,
            "Some chart overlays could not be refreshed. Check your connection and try again."
        )
    }

    @MainActor
    func testPerformLocationQuery_includesNearestPIREP() async {
        let overlayMETAR = MockChartsMETARService()
        let queryMETAR = MockChartsMETARService()
        let detailMETAR = MockChartsMETARService()
        let tafService = MockChartsTAFService()
        let overlayPIREP = MockChartsPIREPService()
        let queryPIREP = MockChartsPIREPService()
        let gairmetService = MockChartsGAIRMETService()
        let sigmetService = MockChartsSIGMETService()
        let airspaceService = MockChartsAirspaceService()
        let geometryService = MockChartsAirspaceGeometryService()

        let coordinate = CLLocationCoordinate2D(latitude: 35.2, longitude: -120.1)
        airspaceService.setResponse(.success(
            snapshot: AirspaceQuerySnapshot(airspaceClass: .classG, laancGridCeiling: nil, hasLAANCCoverage: false),
            delayNanoseconds: 0
        ), for: coordinate)
        queryPIREP.setResponse(.success(
            reports: [Self.samplePIREP(coordinate: coordinate, rawText: "LGT-MOD CHOP")],
            delayNanoseconds: 0
        ), for: coordinate)

        let manager = ChartsOverlayManager(
            overlayMETARService: overlayMETAR,
            queryMETARService: queryMETAR,
            detailMETARService: detailMETAR,
            detailTAFService: tafService,
            overlayPIREPService: overlayPIREP,
            queryPIREPService: queryPIREP,
            gairmetService: gairmetService,
            sigmetService: sigmetService,
            airspaceService: airspaceService,
            airspaceGeometryService: geometryService,
            regionChangeDebounceInterval: 0
        )

        await manager.performLocationQuery(coordinate: coordinate)

        XCTAssertEqual(manager.queryResult?.nearestPIREP?.hazardSummary, "LGT CHOP")
    }

    @MainActor
    func testOnRegionChanged_filtersGairmetsBySelectedForecastHour() async {
        let overlayMETAR = MockChartsMETARService()
        let queryMETAR = MockChartsMETARService()
        let detailMETAR = MockChartsMETARService()
        let tafService = MockChartsTAFService()
        let overlayPIREP = MockChartsPIREPService()
        let queryPIREP = MockChartsPIREPService()
        let gairmetService = MockChartsGAIRMETService()
        let sigmetService = MockChartsSIGMETService()
        let airspaceService = MockChartsAirspaceService()
        let geometryService = MockChartsAirspaceGeometryService()

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.0, longitude: -76.0),
            span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
        )

        gairmetService.setResponse(.success(
            advisories: [
                Self.sampleGAIRMET(tag: "1E", forecastHour: 0, hazard: .ifr),
                Self.sampleGAIRMET(tag: "1E", forecastHour: 6, hazard: .icing)
            ],
            delayNanoseconds: 0
        ), for: region.center)

        let manager = ChartsOverlayManager(
            overlayMETARService: overlayMETAR,
            queryMETARService: queryMETAR,
            detailMETARService: detailMETAR,
            detailTAFService: tafService,
            overlayPIREPService: overlayPIREP,
            queryPIREPService: queryPIREP,
            gairmetService: gairmetService,
            sigmetService: sigmetService,
            airspaceService: airspaceService,
            airspaceGeometryService: geometryService,
            regionChangeDebounceInterval: 0
        )

        manager.showMETAROverlay = false
        manager.showPIREPOverlay = false
        manager.showGairmetOverlay = true
        manager.showSigmetOverlay = false
        manager.showAirspaceOverlay = false
        manager.onRegionChanged(region: region)
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(manager.gairmetAdvisories.map(\.forecastHour), [0])

        manager.selectedGairmetForecastHour = 6

        XCTAssertEqual(manager.gairmetAdvisories.map(\.forecastHour), [6])
        XCTAssertEqual(manager.gairmetAdvisories.first?.hazard, .icing)
    }

    @MainActor
    func testOnRegionChanged_usesCachedWeatherFetchesUntilRetry() async {
        let overlayMETAR = MockChartsMETARService()
        let queryMETAR = MockChartsMETARService()
        let detailMETAR = MockChartsMETARService()
        let tafService = MockChartsTAFService()
        let overlayPIREP = MockChartsPIREPService()
        let queryPIREP = MockChartsPIREPService()
        let gairmetService = MockChartsGAIRMETService()
        let sigmetService = MockChartsSIGMETService()
        let airspaceService = MockChartsAirspaceService()
        let geometryService = MockChartsAirspaceGeometryService()

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 38.9, longitude: -77.0),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )

        overlayMETAR.setResponse(.success(
            metars: [Self.sampleMETAR(stationId: "KDCA", coordinate: region.center)],
            delayNanoseconds: 0
        ), for: region.center)
        overlayPIREP.setResponse(.success(
            reports: [Self.samplePIREP(coordinate: region.center, rawText: "LGT CHOP")],
            delayNanoseconds: 0
        ), for: region.center)
        gairmetService.setResponse(.success(
            advisories: [Self.sampleGAIRMET(tag: "1E", forecastHour: 0, hazard: .ifr)],
            delayNanoseconds: 0
        ), for: region.center)
        sigmetService.setResponse(.success(
            advisories: [Self.sampleSIGMET(seriesId: "1E", coordinate: region.center)],
            delayNanoseconds: 0
        ), for: region.center)

        let manager = ChartsOverlayManager(
            overlayMETARService: overlayMETAR,
            queryMETARService: queryMETAR,
            detailMETARService: detailMETAR,
            detailTAFService: tafService,
            overlayPIREPService: overlayPIREP,
            queryPIREPService: queryPIREP,
            gairmetService: gairmetService,
            sigmetService: sigmetService,
            airspaceService: airspaceService,
            airspaceGeometryService: geometryService,
            regionChangeDebounceInterval: 0
        )

        manager.showPIREPOverlay = true
        manager.showGairmetOverlay = true
        manager.showSigmetOverlay = true
        manager.showAirspaceOverlay = false

        manager.onRegionChanged(region: region)
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(overlayMETAR.forceRefreshValues, [false])
        XCTAssertEqual(overlayPIREP.forceRefreshValues, [false])
        XCTAssertEqual(gairmetService.forceRefreshValues, [false])
        XCTAssertEqual(sigmetService.forceRefreshValues, [false])

        manager.retryVisibleOverlays()
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(overlayMETAR.forceRefreshValues.suffix(1), [true])
        XCTAssertEqual(overlayPIREP.forceRefreshValues.suffix(1), [true])
        XCTAssertEqual(gairmetService.forceRefreshValues.suffix(1), [true])
        XCTAssertEqual(sigmetService.forceRefreshValues.suffix(1), [true])
    }

    func testBoundingBoxIntersectionRejectsOutOfViewportWeatherOverlays() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.0, longitude: -76.0),
            span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
        )

        let visibleCoordinates = [
            CLLocationCoordinate2D(latitude: 39.1, longitude: -76.1),
            CLLocationCoordinate2D(latitude: 39.4, longitude: -75.8),
            CLLocationCoordinate2D(latitude: 39.0, longitude: -75.6)
        ]
        let distantCoordinates = [
            CLLocationCoordinate2D(latitude: 36.9, longitude: -75.4),
            CLLocationCoordinate2D(latitude: 36.2, longitude: -74.3),
            CLLocationCoordinate2D(latitude: 34.7, longitude: -79.7)
        ]

        XCTAssertTrue(region.intersectsBoundingBox(of: visibleCoordinates))
        XCTAssertFalse(region.intersectsBoundingBox(of: distantCoordinates))
    }

    func testNegativePIREPLayersDoNotClassifyAsHazards() {
        let negativePIREP = PIREP(
            id: "negative",
            stationId: "KWBC",
            rawText: "DEN UA /OV DEN/TM 0330/FL080/TB NEG/IC NEG",
            observationTime: Date(),
            receiptTime: Date(),
            latitude: 39.8561,
            longitude: -104.6737,
            aircraftType: "B739",
            flightLevel: 80,
            flightLevelType: "OTHER",
            weatherPhenomena: nil,
            visibility: nil,
            temperature: nil,
            turbulenceLayers: [
                PIREPTurbulenceLayer(
                    intensity: "NEG",
                    type: "",
                    frequency: "",
                    base: nil,
                    top: nil
                )
            ],
            icingLayers: [
                PIREPIcingLayer(
                    intensity: "NEG",
                    type: "",
                    base: nil,
                    top: nil
                )
            ],
            reportType: .pirep
        )

        XCTAssertFalse(negativePIREP.turbulenceLayers[0].hasHazardSignal)
        XCTAssertFalse(negativePIREP.icingLayers[0].hasHazardSignal)
        XCTAssertEqual(negativePIREP.dominantHazard, .general)
        XCTAssertEqual(negativePIREP.hazardSummary, "Routine PIREP")
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

    private static func samplePIREP(
        coordinate: CLLocationCoordinate2D,
        rawText: String
    ) -> PIREP {
        PIREP(
            id: "sample-pirep-\(rawText)",
            stationId: "KWBC",
            rawText: rawText,
            observationTime: Date(),
            receiptTime: Date(),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            aircraftType: "E145",
            flightLevel: 260,
            flightLevelType: "OTHER",
            weatherPhenomena: nil,
            visibility: nil,
            temperature: nil,
            turbulenceLayers: [
                PIREPTurbulenceLayer(
                    intensity: "LGT",
                    type: "CHOP",
                    frequency: "",
                    base: nil,
                    top: nil
                )
            ],
            icingLayers: [],
            reportType: .pirep
        )
    }

    private static func sampleGAIRMET(
        tag: String,
        forecastHour: Int,
        hazard: GAIRMETHazard
    ) -> GAIRMETAdvisory {
        GAIRMETAdvisory(
            id: "\(tag)-\(forecastHour)-\(hazard.rawValue)",
            tag: tag,
            forecastHour: forecastHour,
            validTime: Date(),
            issueTime: Date(),
            expireTime: Date(),
            hazard: hazard,
            geometryType: .area,
            dueTo: nil,
            level: nil,
            product: "ZULU",
            coordinates: [
                CLLocationCoordinate2D(latitude: 39.0, longitude: -76.0),
                CLLocationCoordinate2D(latitude: 39.2, longitude: -75.8),
                CLLocationCoordinate2D(latitude: 39.1, longitude: -75.6)
            ]
        )
    }

    private static func sampleSIGMET(
        seriesId: String,
        coordinate: CLLocationCoordinate2D
    ) -> SIGMETAdvisory {
        SIGMETAdvisory(
            id: "sigmet-\(seriesId)",
            issuingOffice: "KKCI",
            seriesId: seriesId,
            alphaChar: "E",
            validFrom: Date(),
            validTo: Date().addingTimeInterval(3600),
            creationTime: Date(),
            hazard: .convective,
            type: "SIGMET",
            severity: 5,
            movementDirection: 270,
            movementSpeed: 40,
            altitudeLow: nil,
            altitudeHigh: 37000,
            rawText: "Sample SIGMET",
            coordinates: [
                coordinate,
                CLLocationCoordinate2D(latitude: coordinate.latitude + 0.3, longitude: coordinate.longitude + 0.2),
                CLLocationCoordinate2D(latitude: coordinate.latitude + 0.1, longitude: coordinate.longitude + 0.4)
            ]
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
    private(set) var forceRefreshValues: [Bool] = []

    static func key(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }

    func fetchMETARsNearLocation(
        coordinate: CLLocationCoordinate2D,
        radiusDegrees: Double,
        maxResults: Int,
        forceRefresh: Bool
    ) async throws -> [METAR] {
        forceRefreshValues.append(forceRefresh)
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
private final class MockChartsPIREPService: ChartsPIREPProviding {
    struct Response {
        let reports: [PIREP]
        let error: Error?
        let delayNanoseconds: UInt64
    }

    private(set) var responses: [String: Response] = [:]
    private(set) var forceRefreshValues: [Bool] = []

    static func key(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }

    func fetchPIREPsNearLocation(
        coordinate: CLLocationCoordinate2D,
        radiusDegrees: Double,
        maxResults: Int,
        forceRefresh: Bool
    ) async throws -> [PIREP] {
        forceRefreshValues.append(forceRefresh)
        let response = responses[Self.key(for: coordinate)] ?? Response(reports: [], error: nil, delayNanoseconds: 0)

        if response.delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: response.delayNanoseconds)
        }

        if let error = response.error {
            throw error
        }

        return response.reports
    }

    func setResponse(_ response: Response, for coordinate: CLLocationCoordinate2D) {
        responses[Self.key(for: coordinate)] = response
    }
}

private extension MockChartsPIREPService.Response {
    static func success(reports: [PIREP], delayNanoseconds: UInt64) -> MockChartsPIREPService.Response {
        MockChartsPIREPService.Response(reports: reports, error: nil, delayNanoseconds: delayNanoseconds)
    }

    static func failure(_ error: Error, delayNanoseconds: UInt64) -> MockChartsPIREPService.Response {
        MockChartsPIREPService.Response(reports: [], error: error, delayNanoseconds: delayNanoseconds)
    }
}

@MainActor
private final class MockChartsGAIRMETService: ChartsGAIRMETProviding {
    struct Response {
        let advisories: [GAIRMETAdvisory]
        let error: Error?
        let delayNanoseconds: UInt64
    }

    private(set) var responses: [String: Response] = [:]
    private(set) var forceRefreshValues: [Bool] = []

    static func key(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }

    func fetchAdvisories(for region: MKCoordinateRegion, forceRefresh: Bool) async throws -> [GAIRMETAdvisory] {
        forceRefreshValues.append(forceRefresh)
        let response = responses[Self.key(for: region.center)] ?? Response(advisories: [], error: nil, delayNanoseconds: 0)

        if response.delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: response.delayNanoseconds)
        }

        if let error = response.error {
            throw error
        }

        return response.advisories
    }

    func setResponse(_ response: Response, for coordinate: CLLocationCoordinate2D) {
        responses[Self.key(for: coordinate)] = response
    }
}

private extension MockChartsGAIRMETService.Response {
    static func success(advisories: [GAIRMETAdvisory], delayNanoseconds: UInt64) -> MockChartsGAIRMETService.Response {
        MockChartsGAIRMETService.Response(advisories: advisories, error: nil, delayNanoseconds: delayNanoseconds)
    }
}

@MainActor
private final class MockChartsSIGMETService: ChartsSIGMETProviding {
    struct Response {
        let advisories: [SIGMETAdvisory]
        let error: Error?
        let delayNanoseconds: UInt64
    }

    private(set) var responses: [String: Response] = [:]
    private(set) var forceRefreshValues: [Bool] = []

    static func key(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }

    func fetchAdvisories(for region: MKCoordinateRegion, forceRefresh: Bool) async throws -> [SIGMETAdvisory] {
        forceRefreshValues.append(forceRefresh)
        let response = responses[Self.key(for: region.center)] ?? Response(advisories: [], error: nil, delayNanoseconds: 0)

        if response.delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: response.delayNanoseconds)
        }

        if let error = response.error {
            throw error
        }

        return response.advisories
    }

    func setResponse(_ response: Response, for coordinate: CLLocationCoordinate2D) {
        responses[Self.key(for: coordinate)] = response
    }
}

private extension MockChartsSIGMETService.Response {
    static func success(advisories: [SIGMETAdvisory], delayNanoseconds: UInt64) -> MockChartsSIGMETService.Response {
        MockChartsSIGMETService.Response(advisories: advisories, error: nil, delayNanoseconds: delayNanoseconds)
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
