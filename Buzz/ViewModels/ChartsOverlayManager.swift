//
//  ChartsOverlayManager.swift
//  Buzz
//
//  Manages overlay state, toggles, and fetch coordination for VFR charts.
//

import Foundation
import MapKit
import CoreLocation
import Combine

@MainActor
protocol ChartsMETARProviding: AnyObject {
    func fetchMETARsNearLocation(
        coordinate: CLLocationCoordinate2D,
        radiusDegrees: Double,
        maxResults: Int,
        forceRefresh: Bool
    ) async throws -> [METAR]
}

@MainActor
protocol ChartsTAFProviding: AnyObject {
    func fetchTAFsNearLocation(
        coordinate: CLLocationCoordinate2D,
        radiusDegrees: Double,
        forceRefresh: Bool
    ) async throws -> [TAF]
}

@MainActor
protocol ChartsPIREPProviding: AnyObject {
    func fetchPIREPsNearLocation(
        coordinate: CLLocationCoordinate2D,
        radiusDegrees: Double,
        maxResults: Int,
        forceRefresh: Bool
    ) async throws -> [PIREP]
}

@MainActor
protocol ChartsGAIRMETProviding: AnyObject {
    func fetchAdvisories(
        for region: MKCoordinateRegion,
        forceRefresh: Bool
    ) async throws -> [GAIRMETAdvisory]
}

@MainActor
protocol ChartsSIGMETProviding: AnyObject {
    func fetchAdvisories(
        for region: MKCoordinateRegion,
        forceRefresh: Bool
    ) async throws -> [SIGMETAdvisory]
}

@MainActor
protocol ChartsAirspaceQueryProviding: AnyObject {
    func fetchAirspaceSnapshot(
        coordinate: CLLocationCoordinate2D,
        persistResult: Bool
    ) async throws -> AirspaceQuerySnapshot

    func calculateAuthorizationStatus(
        requestedAltitude: Int,
        laancCeiling: Int?,
        airspaceClass: AirspaceClass,
        hasLAANCCoverage: Bool
    ) -> LAANCAuthorizationStatus
}

@MainActor
protocol ChartsAirspaceGeometryProviding: AnyObject {
    func fetchAirspacePolygons(for region: MKCoordinateRegion) async throws -> [AirspaceOverlayPolygon]
}

extension METARService: ChartsMETARProviding {}
extension TAFService: ChartsTAFProviding {}
extension PIREPService: ChartsPIREPProviding {}
extension GAIRMETService: ChartsGAIRMETProviding {}
extension SIGMETService: ChartsSIGMETProviding {}
extension ArcGISAirspaceService: ChartsAirspaceQueryProviding {}
extension ArcGISAirspaceGeometryService: ChartsAirspaceGeometryProviding {}

@MainActor
final class ChartsOverlayManager: ObservableObject {
    @Published var showMETAROverlay = true {
        didSet {
            if showMETAROverlay, let region = lastKnownRegion {
                overlayErrorMessage = nil
                enqueueMETARFetch(for: region)
            } else if !showMETAROverlay {
                metarFetchTask?.cancel()
                metarAnnotations = []
            }
        }
    }

    @Published var showPIREPOverlay = false {
        didSet {
            if showPIREPOverlay, let region = lastKnownRegion {
                overlayErrorMessage = nil
                enqueuePIREPFetch(for: region)
            } else if !showPIREPOverlay {
                pirepFetchTask?.cancel()
                pirepAnnotations = []
            }
        }
    }

    @Published var showGairmetOverlay = false {
        didSet {
            if showGairmetOverlay, let region = lastKnownRegion {
                overlayErrorMessage = nil
                enqueueGAIRMETFetch(for: region)
            } else if !showGairmetOverlay {
                gairmetFetchTask?.cancel()
                allGairmetAdvisories = []
                gairmetAdvisories = []
            }
        }
    }

    @Published var showSigmetOverlay = false {
        didSet {
            if showSigmetOverlay, let region = lastKnownRegion {
                overlayErrorMessage = nil
                enqueueSIGMETFetch(for: region)
            } else if !showSigmetOverlay {
                sigmetFetchTask?.cancel()
                sigmetAdvisories = []
            }
        }
    }

    @Published var showAirspaceOverlay = true {
        didSet {
            if showAirspaceOverlay, let region = lastKnownRegion {
                overlayErrorMessage = nil
                enqueueAirspaceFetch(for: region)
            } else if !showAirspaceOverlay {
                airspaceFetchTask?.cancel()
                airspacePolygons = []
            }
        }
    }

    @Published var selectedGairmetForecastHour = 0 {
        didSet {
            applyGairmetForecastSelection()
        }
    }

    @Published var metarAnnotations: [METARStationAnnotation] = []
    @Published var pirepAnnotations: [PIREPAnnotation] = []
    @Published var selectedMETAR: METAR?
    @Published var selectedTAF: TAF?
    @Published var selectedPIREP: PIREP?
    @Published var showMETARDetail = false
    @Published var isStationDetailLoading = false

    @Published var gairmetAdvisories: [GAIRMETAdvisory] = []
    @Published var sigmetAdvisories: [SIGMETAdvisory] = []
    @Published var airspacePolygons: [AirspaceOverlayPolygon] = []

    @Published var queryPin: QueryPinAnnotation?
    @Published var queryResult: LocationQueryResult?
    @Published var isQueryLoading = false
    @Published var queryErrorMessage: String?
    @Published var overlayErrorMessage: String?

    private let overlayMETARService: ChartsMETARProviding
    private let queryMETARService: ChartsMETARProviding
    private let detailMETARService: ChartsMETARProviding
    private let detailTAFService: ChartsTAFProviding
    private let overlayPIREPService: ChartsPIREPProviding
    private let queryPIREPService: ChartsPIREPProviding
    private let gairmetService: ChartsGAIRMETProviding
    private let sigmetService: ChartsSIGMETProviding
    private let airspaceService: ChartsAirspaceQueryProviding
    private let airspaceGeometryService: ChartsAirspaceGeometryProviding

    private let regionChangeDebounceInterval: TimeInterval
    private var regionChangeWorkItem: DispatchWorkItem?
    private var lastKnownRegion: MKCoordinateRegion?
    private var activeStationSelectionID: UUID?
    private var activeLocationQueryID: UUID?
    private var activeMETARFetchID: UUID?
    private var activePIREPFetchID: UUID?
    private var activeGAIRMETFetchID: UUID?
    private var activeSIGMETFetchID: UUID?
    private var activeAirspaceFetchID: UUID?
    private var metarFetchTask: Task<Void, Never>?
    private var pirepFetchTask: Task<Void, Never>?
    private var gairmetFetchTask: Task<Void, Never>?
    private var sigmetFetchTask: Task<Void, Never>?
    private var airspaceFetchTask: Task<Void, Never>?
    private var allGairmetAdvisories: [GAIRMETAdvisory] = []

    init(
        overlayMETARService: ChartsMETARProviding? = nil,
        queryMETARService: ChartsMETARProviding? = nil,
        detailMETARService: ChartsMETARProviding? = nil,
        detailTAFService: ChartsTAFProviding? = nil,
        overlayPIREPService: ChartsPIREPProviding? = nil,
        queryPIREPService: ChartsPIREPProviding? = nil,
        gairmetService: ChartsGAIRMETProviding? = nil,
        sigmetService: ChartsSIGMETProviding? = nil,
        airspaceService: ChartsAirspaceQueryProviding? = nil,
        airspaceGeometryService: ChartsAirspaceGeometryProviding? = nil,
        regionChangeDebounceInterval: TimeInterval = 0.5
    ) {
        self.overlayMETARService = overlayMETARService ?? METARService()
        self.queryMETARService = queryMETARService ?? METARService()
        self.detailMETARService = detailMETARService ?? METARService()
        self.detailTAFService = detailTAFService ?? TAFService()
        self.overlayPIREPService = overlayPIREPService ?? PIREPService()
        self.queryPIREPService = queryPIREPService ?? PIREPService()
        self.gairmetService = gairmetService ?? GAIRMETService()
        self.sigmetService = sigmetService ?? SIGMETService()
        self.airspaceService = airspaceService ?? ArcGISAirspaceService()
        self.airspaceGeometryService = airspaceGeometryService ?? ArcGISAirspaceGeometryService()
        self.regionChangeDebounceInterval = regionChangeDebounceInterval
    }

    deinit {
        regionChangeWorkItem?.cancel()
        metarFetchTask?.cancel()
        pirepFetchTask?.cancel()
        gairmetFetchTask?.cancel()
        sigmetFetchTask?.cancel()
        airspaceFetchTask?.cancel()
    }

    func onRegionChanged(region: MKCoordinateRegion) {
        lastKnownRegion = region

        regionChangeWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.overlayErrorMessage = nil
                if self.showMETAROverlay {
                    self.enqueueMETARFetch(for: region)
                }
                if self.showPIREPOverlay {
                    self.enqueuePIREPFetch(for: region)
                }
                if self.showGairmetOverlay {
                    self.enqueueGAIRMETFetch(for: region)
                }
                if self.showSigmetOverlay {
                    self.enqueueSIGMETFetch(for: region)
                }
                if self.showAirspaceOverlay {
                    self.enqueueAirspaceFetch(for: region)
                }
            }
        }

        regionChangeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + regionChangeDebounceInterval, execute: workItem)
    }

    func retryVisibleOverlays() {
        guard let region = lastKnownRegion else { return }
        overlayErrorMessage = nil

        if showMETAROverlay {
            enqueueMETARFetch(for: region, forceRefresh: true)
        }
        if showPIREPOverlay {
            enqueuePIREPFetch(for: region, forceRefresh: true)
        }
        if showGairmetOverlay {
            enqueueGAIRMETFetch(for: region, forceRefresh: true)
        }
        if showSigmetOverlay {
            enqueueSIGMETFetch(for: region, forceRefresh: true)
        }
        if showAirspaceOverlay {
            enqueueAirspaceFetch(for: region)
        }
    }

    private func enqueueMETARFetch(
        for region: MKCoordinateRegion,
        forceRefresh: Bool = false
    ) {
        let requestID = UUID()
        activeMETARFetchID = requestID
        metarFetchTask?.cancel()
        metarFetchTask = Task { [weak self] in
            await self?.fetchMETARsForRegion(region, requestID: requestID, forceRefresh: forceRefresh)
        }
    }

    private func fetchMETARsForRegion(
        _ region: MKCoordinateRegion,
        requestID: UUID,
        forceRefresh: Bool
    ) async {
        let radiusDegrees = max(region.span.latitudeDelta, region.span.longitudeDelta) / 2

        do {
            let metars = try await overlayMETARService.fetchMETARsNearLocation(
                coordinate: region.center,
                radiusDegrees: radiusDegrees,
                maxResults: 20,
                forceRefresh: forceRefresh
            )

            guard !Task.isCancelled,
                  activeMETARFetchID == requestID,
                  showMETAROverlay else {
                return
            }

            var seen = Set<String>()
            metarAnnotations = metars.compactMap { metar in
                guard seen.insert(metar.stationId).inserted else { return nil }
                return METARStationAnnotation(metar: metar)
            }
        } catch {
            guard !Task.isCancelled, activeMETARFetchID == requestID else { return }
            print("Charts METAR fetch error: \(error.localizedDescription)")
            overlayErrorMessage = "Some chart overlays could not be refreshed. Check your connection and try again."
        }
    }

    private func enqueuePIREPFetch(
        for region: MKCoordinateRegion,
        forceRefresh: Bool = false
    ) {
        let requestID = UUID()
        activePIREPFetchID = requestID
        pirepFetchTask?.cancel()
        pirepFetchTask = Task { [weak self] in
            await self?.fetchPIREPsForRegion(region, requestID: requestID, forceRefresh: forceRefresh)
        }
    }

    private func fetchPIREPsForRegion(
        _ region: MKCoordinateRegion,
        requestID: UUID,
        forceRefresh: Bool
    ) async {
        let radiusDegrees = max(region.span.latitudeDelta, region.span.longitudeDelta) / 2

        do {
            let reports = try await overlayPIREPService.fetchPIREPsNearLocation(
                coordinate: region.center,
                radiusDegrees: radiusDegrees,
                maxResults: 30,
                forceRefresh: forceRefresh
            )

            guard !Task.isCancelled,
                  activePIREPFetchID == requestID,
                  showPIREPOverlay else {
                return
            }

            var seen = Set<String>()
            pirepAnnotations = reports.compactMap { report in
                guard seen.insert(report.id).inserted else { return nil }
                return PIREPAnnotation(pirep: report)
            }
        } catch {
            guard !Task.isCancelled, activePIREPFetchID == requestID else { return }
            print("Charts PIREP fetch error: \(error.localizedDescription)")
            overlayErrorMessage = "Some chart overlays could not be refreshed. Check your connection and try again."
        }
    }

    func selectStation(_ annotation: METARStationAnnotation) async {
        let requestID = UUID()
        activeStationSelectionID = requestID
        selectedMETAR = nil
        selectedTAF = nil
        isStationDetailLoading = true
        showMETARDetail = true

        defer {
            if activeStationSelectionID == requestID {
                isStationDetailLoading = false
            }
        }

        async let refreshedMETAR = fetchFreshMETAR(for: annotation.metar)
        async let refreshedTAF = fetchFreshTAF(for: annotation.metar)

        let latestMETAR = await refreshedMETAR
        let latestTAF = await refreshedTAF

        guard activeStationSelectionID == requestID else { return }

        let displayMETAR = latestMETAR ?? annotation.metar
        selectedMETAR = displayMETAR
        selectedTAF = latestTAF

        if let latestMETAR {
            updateDisplayedMETAR(latestMETAR)
        }
    }

    func selectPIREP(_ annotation: PIREPAnnotation) {
        selectedPIREP = annotation.pirep
    }

    func dismissMETARDetail() {
        activeStationSelectionID = nil
        showMETARDetail = false
        isStationDetailLoading = false
        selectedMETAR = nil
        selectedTAF = nil
    }

    func dismissPIREPDetail() {
        selectedPIREP = nil
    }

    private func enqueueGAIRMETFetch(
        for region: MKCoordinateRegion,
        forceRefresh: Bool = false
    ) {
        let requestID = UUID()
        activeGAIRMETFetchID = requestID
        gairmetFetchTask?.cancel()
        gairmetFetchTask = Task { [weak self] in
            await self?.fetchGAIRMETsForRegion(region, requestID: requestID, forceRefresh: forceRefresh)
        }
    }

    private func fetchGAIRMETsForRegion(
        _ region: MKCoordinateRegion,
        requestID: UUID,
        forceRefresh: Bool
    ) async {
        do {
            let advisories = try await gairmetService.fetchAdvisories(for: region, forceRefresh: forceRefresh)
            guard !Task.isCancelled,
                  activeGAIRMETFetchID == requestID,
                  showGairmetOverlay else {
                return
            }

            allGairmetAdvisories = advisories
            applyGairmetForecastSelection()
        } catch {
            guard !Task.isCancelled, activeGAIRMETFetchID == requestID else { return }
            print("Charts G-AIRMET fetch error: \(error.localizedDescription)")
            overlayErrorMessage = "Some chart overlays could not be refreshed. Check your connection and try again."
        }
    }

    private func applyGairmetForecastSelection() {
        gairmetAdvisories = allGairmetAdvisories.filter { $0.forecastHour == selectedGairmetForecastHour }
    }

    private func enqueueSIGMETFetch(
        for region: MKCoordinateRegion,
        forceRefresh: Bool = false
    ) {
        let requestID = UUID()
        activeSIGMETFetchID = requestID
        sigmetFetchTask?.cancel()
        sigmetFetchTask = Task { [weak self] in
            await self?.fetchSIGMETsForRegion(region, requestID: requestID, forceRefresh: forceRefresh)
        }
    }

    private func fetchSIGMETsForRegion(
        _ region: MKCoordinateRegion,
        requestID: UUID,
        forceRefresh: Bool
    ) async {
        do {
            let advisories = try await sigmetService.fetchAdvisories(for: region, forceRefresh: forceRefresh)
            guard !Task.isCancelled,
                  activeSIGMETFetchID == requestID,
                  showSigmetOverlay else {
                return
            }

            sigmetAdvisories = advisories
        } catch {
            guard !Task.isCancelled, activeSIGMETFetchID == requestID else { return }
            print("Charts SIGMET fetch error: \(error.localizedDescription)")
            overlayErrorMessage = "Some chart overlays could not be refreshed. Check your connection and try again."
        }
    }

    private func enqueueAirspaceFetch(for region: MKCoordinateRegion) {
        let requestID = UUID()
        activeAirspaceFetchID = requestID
        airspaceFetchTask?.cancel()
        airspaceFetchTask = Task { [weak self] in
            await self?.fetchAirspaceForRegion(region, requestID: requestID)
        }
    }

    private func fetchAirspaceForRegion(_ region: MKCoordinateRegion, requestID: UUID) async {
        let zoomLevel = Int(round(log2(360.0 / region.span.longitudeDelta)))
        guard zoomLevel >= 9 else {
            guard activeAirspaceFetchID == requestID else { return }
            airspacePolygons = []
            return
        }

        do {
            let polygons = try await airspaceGeometryService.fetchAirspacePolygons(for: region)
            guard !Task.isCancelled,
                  activeAirspaceFetchID == requestID,
                  showAirspaceOverlay else {
                return
            }
            airspacePolygons = polygons
        } catch {
            guard !Task.isCancelled, activeAirspaceFetchID == requestID else { return }
            print("Charts airspace geometry fetch error: \(error.localizedDescription)")
            overlayErrorMessage = "Some chart overlays could not be refreshed. Check your connection and try again."
        }
    }

    func performLocationQuery(coordinate: CLLocationCoordinate2D) async {
        let requestID = UUID()
        activeLocationQueryID = requestID
        isQueryLoading = true
        queryPin = QueryPinAnnotation(coordinate: coordinate)
        queryResult = nil
        queryErrorMessage = nil

        async let airspaceResult = fetchAirspaceSnapshotForQuery(coordinate: coordinate)
        async let nearestMETARResult = fetchNearestMETARForQuery(coordinate: coordinate)
        async let nearestPIREPResult = fetchNearestPIREPForQuery(coordinate: coordinate)

        let (resolvedAirspace, resolvedMETAR, resolvedPIREP) = await (
            airspaceResult,
            nearestMETARResult,
            nearestPIREPResult
        )

        guard activeLocationQueryID == requestID else { return }

        let snapshot: AirspaceQuerySnapshot
        var queryErrors: [String] = []

        switch resolvedAirspace {
        case .success(let value):
            snapshot = value
        case .failure(let error):
            print("Charts airspace query error: \(error.localizedDescription)")
            snapshot = .unavailable
            queryErrors.append("Airspace details are unavailable for this point right now.")
        }

        let nearestMETAR: METAR?
        switch resolvedMETAR {
        case .success(let value):
            nearestMETAR = value
        case .failure(let error):
            print("Charts query METAR error: \(error.localizedDescription)")
            nearestMETAR = nil
            queryErrors.append("Nearby weather data is unavailable right now.")
        }

        let nearestPIREP: PIREP?
        switch resolvedPIREP {
        case .success(let value):
            nearestPIREP = value
        case .failure(let error):
            print("Charts query PIREP error: \(error.localizedDescription)")
            nearestPIREP = nil
            queryErrors.append("Nearby pilot reports are unavailable right now.")
        }

        let authStatus = airspaceService.calculateAuthorizationStatus(
            requestedAltitude: 400,
            laancCeiling: snapshot.laancGridCeiling,
            airspaceClass: snapshot.airspaceClass,
            hasLAANCCoverage: snapshot.hasLAANCCoverage
        )

        queryResult = LocationQueryResult(
            coordinate: coordinate,
            formattedCoordinate: LocationQueryResult.formatDMS(coordinate),
            airspaceClass: snapshot.airspaceClass,
            laancCeiling: snapshot.laancGridCeiling,
            hasLAANCCoverage: snapshot.hasLAANCCoverage,
            authorizationStatus: authStatus,
            nearestMETAR: nearestMETAR,
            distanceToNearestMETAR: nearestMETAR?.formattedDistance(from: coordinate),
            nearestPIREP: nearestPIREP,
            distanceToNearestPIREP: nearestPIREP?.formattedDistance(from: coordinate)
        )

        queryErrorMessage = queryErrors.isEmpty ? nil : queryErrors.joined(separator: " ")
        isQueryLoading = false
    }

    func dismissQuery() {
        activeLocationQueryID = nil
        queryPin = nil
        queryResult = nil
        isQueryLoading = false
        queryErrorMessage = nil
    }

    private func fetchFreshMETAR(for station: METAR) async -> METAR? {
        do {
            let metars = try await detailMETARService.fetchMETARsNearLocation(
                coordinate: station.coordinate,
                radiusDegrees: 0.05,
                maxResults: 10,
                forceRefresh: true
            )
            return metars.first { $0.stationId == station.stationId } ?? metars.first
        } catch {
            print("Charts METAR detail refresh error: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchFreshTAF(for station: METAR) async -> TAF? {
        do {
            let tafs = try await detailTAFService.fetchTAFsNearLocation(
                coordinate: station.coordinate,
                radiusDegrees: 0.05,
                forceRefresh: true
            )
            return tafs.first { $0.stationId == station.stationId }
        } catch {
            print("Charts TAF detail refresh error: \(error.localizedDescription)")
            return nil
        }
    }

    private func updateDisplayedMETAR(_ metar: METAR) {
        guard let index = metarAnnotations.firstIndex(where: { $0.metar.stationId == metar.stationId }) else {
            return
        }

        metarAnnotations[index] = METARStationAnnotation(metar: metar)
    }

    private func fetchAirspaceSnapshotForQuery(
        coordinate: CLLocationCoordinate2D
    ) async -> Result<AirspaceQuerySnapshot, Error> {
        do {
            let snapshot = try await airspaceService.fetchAirspaceSnapshot(
                coordinate: coordinate,
                persistResult: false
            )
            return .success(snapshot)
        } catch {
            return .failure(error)
        }
    }

    private func fetchNearestMETARForQuery(
        coordinate: CLLocationCoordinate2D
    ) async -> Result<METAR?, Error> {
        do {
            let metars = try await queryMETARService.fetchMETARsNearLocation(
                coordinate: coordinate,
                radiusDegrees: 0.5,
                maxResults: 1,
                forceRefresh: false
            )
            return .success(metars.first)
        } catch {
            return .failure(error)
        }
    }

    private func fetchNearestPIREPForQuery(
        coordinate: CLLocationCoordinate2D
    ) async -> Result<PIREP?, Error> {
        do {
            let reports = try await queryPIREPService.fetchPIREPsNearLocation(
                coordinate: coordinate,
                radiusDegrees: 0.5,
                maxResults: 1,
                forceRefresh: false
            )
            return .success(reports.first)
        } catch {
            return .failure(error)
        }
    }
}
