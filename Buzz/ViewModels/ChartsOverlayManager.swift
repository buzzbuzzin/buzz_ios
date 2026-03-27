//
//  ChartsOverlayManager.swift
//  Buzz
//
//  Manages overlay state, toggles, and fetch coordination for VFR charts
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
extension ArcGISAirspaceService: ChartsAirspaceQueryProviding {}
extension ArcGISAirspaceGeometryService: ChartsAirspaceGeometryProviding {}

@MainActor
final class ChartsOverlayManager: ObservableObject {
    // MARK: - Toggle State

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

    // MARK: - METAR Data

    @Published var metarAnnotations: [METARStationAnnotation] = []
    @Published var selectedMETAR: METAR?
    @Published var selectedTAF: TAF?
    @Published var showMETARDetail = false
    @Published var isStationDetailLoading = false

    // MARK: - Airspace Data

    @Published var airspacePolygons: [AirspaceOverlayPolygon] = []

    // MARK: - Long-Press Query

    @Published var queryPin: QueryPinAnnotation?
    @Published var queryResult: LocationQueryResult?
    @Published var isQueryLoading = false
    @Published var queryErrorMessage: String?
    @Published var overlayErrorMessage: String?

    // MARK: - Services

    private let overlayMETARService: ChartsMETARProviding
    private let queryMETARService: ChartsMETARProviding
    private let detailMETARService: ChartsMETARProviding
    private let detailTAFService: ChartsTAFProviding
    private let airspaceService: ChartsAirspaceQueryProviding
    private let airspaceGeometryService: ChartsAirspaceGeometryProviding

    // MARK: - Debounce

    private let regionChangeDebounceInterval: TimeInterval
    private var regionChangeWorkItem: DispatchWorkItem?
    private var lastKnownRegion: MKCoordinateRegion?
    private var activeStationSelectionID: UUID?
    private var activeLocationQueryID: UUID?
    private var activeMETARFetchID: UUID?
    private var activeAirspaceFetchID: UUID?
    private var metarFetchTask: Task<Void, Never>?
    private var airspaceFetchTask: Task<Void, Never>?

    init(
        overlayMETARService: ChartsMETARProviding? = nil,
        queryMETARService: ChartsMETARProviding? = nil,
        detailMETARService: ChartsMETARProviding? = nil,
        detailTAFService: ChartsTAFProviding? = nil,
        airspaceService: ChartsAirspaceQueryProviding? = nil,
        airspaceGeometryService: ChartsAirspaceGeometryProviding? = nil,
        regionChangeDebounceInterval: TimeInterval = 0.5
    ) {
        self.overlayMETARService = overlayMETARService ?? METARService()
        self.queryMETARService = queryMETARService ?? METARService()
        self.detailMETARService = detailMETARService ?? METARService()
        self.detailTAFService = detailTAFService ?? TAFService()
        self.airspaceService = airspaceService ?? ArcGISAirspaceService()
        self.airspaceGeometryService = airspaceGeometryService ?? ArcGISAirspaceGeometryService()
        self.regionChangeDebounceInterval = regionChangeDebounceInterval
    }

    deinit {
        regionChangeWorkItem?.cancel()
        metarFetchTask?.cancel()
        airspaceFetchTask?.cancel()
    }

    // MARK: - Region Change Handler

    func onRegionChanged(region: MKCoordinateRegion) {
        lastKnownRegion = region

        regionChangeWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.overlayErrorMessage = nil
            if self.showMETAROverlay {
                self.enqueueMETARFetch(for: region)
            }
            if self.showAirspaceOverlay {
                self.enqueueAirspaceFetch(for: region)
            }
        }

        regionChangeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + regionChangeDebounceInterval, execute: workItem)
    }

    // MARK: - METAR Fetching

    func retryVisibleOverlays() {
        guard let region = lastKnownRegion else { return }
        overlayErrorMessage = nil

        if showMETAROverlay {
            enqueueMETARFetch(for: region)
        }
        if showAirspaceOverlay {
            enqueueAirspaceFetch(for: region)
        }
    }

    private func enqueueMETARFetch(for region: MKCoordinateRegion) {
        let requestID = UUID()
        activeMETARFetchID = requestID
        metarFetchTask?.cancel()
        metarFetchTask = Task { [weak self] in
            await self?.fetchMETARsForRegion(region, requestID: requestID)
        }
    }

    private func fetchMETARsForRegion(_ region: MKCoordinateRegion, requestID: UUID) async {
        let radiusDegrees = max(region.span.latitudeDelta, region.span.longitudeDelta) / 2

        do {
            let metars = try await overlayMETARService.fetchMETARsNearLocation(
                coordinate: region.center,
                radiusDegrees: radiusDegrees,
                maxResults: 20,
                forceRefresh: false
            )

            guard !Task.isCancelled,
                  activeMETARFetchID == requestID,
                  showMETAROverlay else {
                return
            }

            // Create annotations, avoiding duplicates by station ID
            var seen = Set<String>()
            var annotations: [METARStationAnnotation] = []
            for metar in metars {
                if seen.insert(metar.stationId).inserted {
                    annotations.append(METARStationAnnotation(metar: metar))
                }
            }

            metarAnnotations = annotations
        } catch {
            guard !Task.isCancelled, activeMETARFetchID == requestID else { return }
            print("Charts METAR fetch error: \(error.localizedDescription)")
            overlayErrorMessage = "Some chart overlays could not be refreshed. Check your connection and try again."
        }
    }

    // MARK: - Station Selection

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

    func dismissMETARDetail() {
        activeStationSelectionID = nil
        showMETARDetail = false
        isStationDetailLoading = false
        selectedMETAR = nil
        selectedTAF = nil
    }

    // MARK: - Airspace Fetching

    private func enqueueAirspaceFetch(for region: MKCoordinateRegion) {
        let requestID = UUID()
        activeAirspaceFetchID = requestID
        airspaceFetchTask?.cancel()
        airspaceFetchTask = Task { [weak self] in
            await self?.fetchAirspaceForRegion(region, requestID: requestID)
        }
    }

    private func fetchAirspaceForRegion(_ region: MKCoordinateRegion, requestID: UUID) async {
        // Only fetch at Z9+ (skip when too zoomed out for useful polygons)
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

    // MARK: - Long-Press Location Query

    func performLocationQuery(coordinate: CLLocationCoordinate2D) async {
        let requestID = UUID()
        activeLocationQueryID = requestID
        isQueryLoading = true
        queryPin = QueryPinAnnotation(coordinate: coordinate)
        queryResult = nil
        queryErrorMessage = nil

        async let airspaceResult = fetchAirspaceSnapshotForQuery(coordinate: coordinate)
        async let nearestMETARResult = fetchNearestMETARForQuery(coordinate: coordinate)

        let (resolvedAirspace, resolvedMETAR) = await (airspaceResult, nearestMETARResult)

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
            distanceToNearestMETAR: nearestMETAR?.formattedDistance(from: coordinate)
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

    // MARK: - Station Detail Refresh

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
}
