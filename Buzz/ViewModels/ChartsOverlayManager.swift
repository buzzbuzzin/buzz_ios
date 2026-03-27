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
class ChartsOverlayManager: ObservableObject {
    // MARK: - Toggle State

    @Published var showMETAROverlay = true {
        didSet {
            if showMETAROverlay, let region = lastKnownRegion {
                Task { await fetchMETARsForRegion(region) }
            } else if !showMETAROverlay {
                metarAnnotations = []
            }
        }
    }

    @Published var showAirspaceOverlay = true {
        didSet {
            if showAirspaceOverlay, let region = lastKnownRegion {
                Task { await fetchAirspaceForRegion(region) }
            } else if !showAirspaceOverlay {
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

    // MARK: - Services

    private let overlayMETARService = METARService()
    private let queryMETARService = METARService()
    private let detailMETARService = METARService()
    private let detailTAFService = TAFService()
    private let airspaceService = ArcGISAirspaceService()
    private let airspaceGeometryService = ArcGISAirspaceGeometryService()

    // MARK: - Debounce

    private var regionChangeWorkItem: DispatchWorkItem?
    private var lastKnownRegion: MKCoordinateRegion?
    private var activeStationSelectionID: UUID?

    // MARK: - Region Change Handler

    func onRegionChanged(region: MKCoordinateRegion) {
        lastKnownRegion = region

        regionChangeWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.showMETAROverlay {
                    await self.fetchMETARsForRegion(region)
                }
                if self.showAirspaceOverlay {
                    await self.fetchAirspaceForRegion(region)
                }
            }
        }

        regionChangeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    // MARK: - METAR Fetching

    private func fetchMETARsForRegion(_ region: MKCoordinateRegion) async {
        let radiusDegrees = max(region.span.latitudeDelta, region.span.longitudeDelta) / 2

        do {
            let metars = try await overlayMETARService.fetchMETARsNearLocation(
                coordinate: region.center,
                radiusDegrees: radiusDegrees,
                maxResults: 20
            )

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
            print("Charts METAR fetch error: \(error.localizedDescription)")
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

    private func fetchAirspaceForRegion(_ region: MKCoordinateRegion) async {
        // Only fetch at Z9+ (skip when too zoomed out for useful polygons)
        let zoomLevel = Int(round(log2(360.0 / region.span.longitudeDelta)))
        guard zoomLevel >= 9 else {
            airspacePolygons = []
            return
        }

        do {
            let polygons = try await airspaceGeometryService.fetchAirspacePolygons(for: region)
            airspacePolygons = polygons
        } catch {
            print("Charts airspace geometry fetch error: \(error.localizedDescription)")
        }
    }

    // MARK: - Long-Press Location Query

    func performLocationQuery(coordinate: CLLocationCoordinate2D) async {
        isQueryLoading = true
        queryPin = QueryPinAnnotation(coordinate: coordinate)
        queryResult = nil

        // Run airspace and METAR queries in parallel
        await airspaceService.fetchAirspaceData(coordinate: coordinate)

        var nearestMETAR: METAR?
        do {
            let metars = try await queryMETARService.fetchMETARsNearLocation(
                coordinate: coordinate,
                radiusDegrees: 0.5,
                maxResults: 1
            )
            nearestMETAR = metars.first
        } catch {
            print("Charts query METAR error: \(error.localizedDescription)")
        }

        let authStatus = airspaceService.calculateAuthorizationStatus(
            requestedAltitude: 400,
            laancCeiling: airspaceService.laancGridCeiling,
            airspaceClass: airspaceService.airspaceClass,
            hasLAANCCoverage: airspaceService.hasLAANCCoverage
        )

        queryResult = LocationQueryResult(
            coordinate: coordinate,
            formattedCoordinate: LocationQueryResult.formatDMS(coordinate),
            airspaceClass: airspaceService.airspaceClass,
            laancCeiling: airspaceService.laancGridCeiling,
            hasLAANCCoverage: airspaceService.hasLAANCCoverage,
            authorizationStatus: authStatus,
            nearestMETAR: nearestMETAR,
            distanceToNearestMETAR: nearestMETAR?.formattedDistance(from: coordinate)
        )

        isQueryLoading = false
    }

    func dismissQuery() {
        queryPin = nil
        queryResult = nil
        isQueryLoading = false
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
}
