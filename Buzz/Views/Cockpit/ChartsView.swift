//
//  ChartsView.swift
//  Buzz
//
//  Created for displaying FAA VFR Sectional Charts
//

import SwiftUI
import MapKit
import CoreLocation
import Combine
import UIKit

struct ChartsView: View {
    @Environment(\.openURL) private var openURL
    @Binding var isPresented: Bool
    @StateObject private var locationManager = ChartsLocationManager()
    @StateObject private var overlayManager = ChartsOverlayManager()
    @State private var region = MKCoordinateRegion(
        center: LocationHelper.shared.defaultSimulatorLocation,
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @State private var currentZoomLevel: Int = 10
    @State private var centerRequestCount: Int = 0
    @State private var cacheStatus: String = ""
    @State private var tileReloadRequestCount: Int = 0
    @State private var pendingCenterOnUserLocation = false
    @State private var locationStatusMessage: String?
    @State private var locationAlert: ChartsAlertContent?

    var body: some View {
        ZStack {
            // VFR Sectional Map
            VFRMapView(
                region: $region,
                currentZoomLevel: $currentZoomLevel,
                centerRequestCount: $centerRequestCount,
                tileReloadRequestCount: $tileReloadRequestCount,
                userLocation: locationManager.currentLocation,
                metarAnnotations: overlayManager.showMETAROverlay ? overlayManager.metarAnnotations : [],
                pirepAnnotations: overlayManager.showPIREPOverlay ? overlayManager.pirepAnnotations : [],
                gairmetAdvisories: overlayManager.showGairmetOverlay ? overlayManager.gairmetAdvisories : [],
                sigmetAdvisories: overlayManager.showSigmetOverlay ? overlayManager.sigmetAdvisories : [],
                airspacePolygons: overlayManager.showAirspaceOverlay ? overlayManager.airspacePolygons : [],
                queryPin: overlayManager.queryPin,
                onRegionChanged: { newRegion in
                    overlayManager.onRegionChanged(region: newRegion)
                },
                onAnnotationSelected: { annotation in
                    Task { await overlayManager.selectStation(annotation) }
                },
                onPIREPSelected: { annotation in
                    overlayManager.selectPIREP(annotation)
                },
                onLongPress: { coordinate in
                    Task { await overlayManager.performLocationQuery(coordinate: coordinate) }
                }
            )
            .ignoresSafeArea(edges: .top)

            // Overlay Controls
            VStack {
                // Header
                HStack {
                    // Dismiss Button
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("VFR Sectional Charts")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("FAA Aviation Charts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        // Zoom Level Indicator
                        Text("Z\(currentZoomLevel)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(zoomLevelColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemBackground))
                            .clipShape(Capsule())
                            .shadow(radius: 2)

                        // My Location Button
                        Button(action: {
                            centerOnUserLocation()
                        }) {
                            Image(systemName: "location.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color(.systemBackground))
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        .accessibilityLabel("Center on my location")
                        .accessibilityHint("Centers the chart on your current position.")
                    }
                }
                .padding()
                .background(Color(.systemBackground).opacity(0.95))

                // Zoom Warning (when outside valid range)
                if currentZoomLevel < 8 || currentZoomLevel > 12 {
                    ZoomWarningCard(currentZoom: currentZoomLevel)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let overlayMessage = overlayManager.overlayErrorMessage {
                    ChartsStatusBanner(
                        systemImage: "exclamationmark.triangle.fill",
                        message: overlayMessage,
                        tint: .orange,
                        actionTitle: "Retry",
                        action: { overlayManager.retryVisibleOverlays() },
                        onDismiss: { overlayManager.overlayErrorMessage = nil }
                    )
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let locationStatusMessage {
                    ChartsStatusBanner(
                        systemImage: "location.fill",
                        message: locationStatusMessage,
                        tint: .blue
                    )
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Bottom Card: Query result only (no persistent info card)
                VStack(spacing: 10) {
                    ChartsWeatherSummaryCard(
                        pireps: overlayManager.pirepAnnotations.map(\.pirep),
                        gairmets: overlayManager.gairmetAdvisories,
                        sigmets: overlayManager.sigmetAdvisories,
                        showPIREPOverlay: overlayManager.showPIREPOverlay,
                        showGairmetOverlay: overlayManager.showGairmetOverlay,
                        showSigmetOverlay: overlayManager.showSigmetOverlay,
                        selectedGairmetForecastHour: $overlayManager.selectedGairmetForecastHour
                    )
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                    if overlayManager.queryResult != nil || overlayManager.isQueryLoading {
                        LocationQueryCard(
                            result: overlayManager.queryResult ?? placeholderQueryResult,
                            isLoading: overlayManager.isQueryLoading,
                            errorMessage: overlayManager.queryErrorMessage,
                            onDismiss: { overlayManager.dismissQuery() }
                        )
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }

            // Floating overlay toggles (top-right, below header)
            VStack {
                Spacer().frame(height: 100) // offset below header
                HStack {
                    Spacer()
                    ChartsOverlayToolbar(
                        showMETAROverlay: $overlayManager.showMETAROverlay,
                        showPIREPOverlay: $overlayManager.showPIREPOverlay,
                        showGairmetOverlay: $overlayManager.showGairmetOverlay,
                        showSigmetOverlay: $overlayManager.showSigmetOverlay,
                        showAirspaceOverlay: $overlayManager.showAirspaceOverlay
                    )
                    .padding(.trailing, 12)
                }
                Spacer()
            }
        }
        .navigationTitle("Charts")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locationManager.requestPermission()
            locationManager.startLocationUpdates()

            // Center on user location when available
            if let location = locationManager.currentLocation {
                region = MKCoordinateRegion(
                    center: location,
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                )
            }

            // Check for new FAA chart editions and update cache status
            let cache = VFRChartCacheService.shared
            cacheStatus = cache.cacheSizeDescription
            Task {
                let didInvalidate = await cache.checkForUpdates()
                await MainActor.run {
                    if didInvalidate {
                        tileReloadRequestCount += 1
                        cacheStatus = "Updated: new FAA edition"
                    } else {
                        cacheStatus = cache.cacheSizeDescription
                    }
                }
            }
        }
        .onDisappear {
            locationManager.stopLocationUpdates()
        }
        .onReceive(locationManager.$currentLocation) { newLocation in
            guard let location = newLocation else { return }

            let shouldCenterOnPendingRequest = pendingCenterOnUserLocation
            locationStatusMessage = nil
            pendingCenterOnUserLocation = false

            if shouldCenterOnPendingRequest {
                withAnimation(.easeInOut(duration: 0.5)) {
                    region = MKCoordinateRegion(
                        center: location,
                        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
                    )
                }
                centerRequestCount += 1
                return
            }

            // Center on first location update if we haven't moved yet
            if region.center.latitude == LocationHelper.shared.defaultSimulatorLocation.latitude {
                withAnimation(.easeInOut(duration: 0.5)) {
                    region = MKCoordinateRegion(
                        center: location,
                        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                    )
                }
            }
        }
        .onReceive(locationManager.$authorizationStatus) { status in
            guard pendingCenterOnUserLocation else { return }

            if status == .denied || status == .restricted {
                pendingCenterOnUserLocation = false
                locationStatusMessage = nil
                locationAlert = ChartsAlertContent(
                    title: "Location Access Needed",
                    message: "Enable location access in Settings to center the chart on your current position.",
                    showsSettingsAction: true
                )
            }
        }
        .onReceive(locationManager.$lastErrorMessage.compactMap { $0 }) { message in
            guard pendingCenterOnUserLocation else { return }
            pendingCenterOnUserLocation = false
            locationStatusMessage = nil
            locationAlert = ChartsAlertContent(
                title: "Location Unavailable",
                message: message,
                showsSettingsAction: false
            )
        }
        .sheet(isPresented: $overlayManager.showMETARDetail) {
            if overlayManager.isStationDetailLoading {
                NavigationStack {
                    ProgressView("Refreshing weather...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationTitle("Weather")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { overlayManager.dismissMETARDetail() }
                            }
                        }
                }
            } else if let metar = overlayManager.selectedMETAR {
                METARDetailSheet(
                    metar: metar,
                    taf: overlayManager.selectedTAF,
                    onDismiss: { overlayManager.dismissMETARDetail() }
                )
                .presentationDetents([.medium, .large])
            } else {
                NavigationStack {
                    ContentUnavailableView(
                        "Weather Unavailable",
                        systemImage: "cloud.slash",
                        description: Text("Unable to load the latest weather for this station.")
                    )
                    .navigationTitle("Weather")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { overlayManager.dismissMETARDetail() }
                        }
                    }
                }
            }
        }
        .sheet(item: $overlayManager.selectedPIREP) { pirep in
            PIREPDetailSheet(
                pirep: pirep,
                onDismiss: { overlayManager.dismissPIREPDetail() }
            )
            .presentationDetents([.medium, .large])
        }
        .alert(item: $locationAlert) { alert in
            if alert.showsSettingsAction {
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("Open Settings")) {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    },
                    secondaryButton: .cancel()
                )
            }

            return Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var zoomLevelColor: Color {
        if currentZoomLevel >= 8 && currentZoomLevel <= 12 {
            return .green
        } else {
            return .orange
        }
    }

    private func centerOnUserLocation() {
        if let userLocation = locationManager.currentLocation {
            pendingCenterOnUserLocation = false
            locationStatusMessage = nil
            region = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
            )
            centerRequestCount += 1
            return
        }

        pendingCenterOnUserLocation = true

        if locationManager.authorizationStatus == .notDetermined {
            locationStatusMessage = "Allow location access to center on your current position."
            locationManager.requestPermission()
        } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
            pendingCenterOnUserLocation = false
            locationStatusMessage = nil
            locationAlert = ChartsAlertContent(
                title: "Location Access Needed",
                message: "Enable location access in Settings to center the chart on your current position.",
                showsSettingsAction: true
            )
            return
        } else {
            locationStatusMessage = "Finding your current position..."
        }

        locationManager.startLocationUpdates()
    }

    /// Placeholder result used while loading
    private var placeholderQueryResult: LocationQueryResult {
        LocationQueryResult(
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            formattedCoordinate: "...",
            airspaceClass: .unknown,
            laancCeiling: nil,
            hasLAANCCoverage: false,
            authorizationStatus: .pending,
            nearestMETAR: nil,
            distanceToNearestMETAR: nil,
            nearestPIREP: nil,
            distanceToNearestPIREP: nil
        )
    }
}

private struct ChartsAlertContent: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let showsSettingsAction: Bool
}

// MARK: - VFR Map View (UIViewRepresentable)

struct VFRMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var currentZoomLevel: Int
    @Binding var centerRequestCount: Int
    @Binding var tileReloadRequestCount: Int
    var userLocation: CLLocationCoordinate2D?

    // Overlay data
    var metarAnnotations: [METARStationAnnotation]
    var pirepAnnotations: [PIREPAnnotation]
    var gairmetAdvisories: [GAIRMETAdvisory]
    var sigmetAdvisories: [SIGMETAdvisory]
    var airspacePolygons: [AirspaceOverlayPolygon]
    var queryPin: QueryPinAnnotation?

    // Callbacks
    var onRegionChanged: ((MKCoordinateRegion) -> Void)?
    var onAnnotationSelected: ((METARStationAnnotation) -> Void)?
    var onPIREPSelected: ((PIREPAnnotation) -> Void)?
    var onLongPress: ((CLLocationCoordinate2D) -> Void)?

    // Zoom level constraints for FAA VFR Sectional tiles
    static let minZoom = 8
    static let maxZoom = 12

    static let minSpanDelta: Double = 360.0 / pow(2, Double(maxZoom))
    static let maxSpanDelta: Double = 360.0 / pow(2, Double(minZoom))

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true

        // Add VFR Sectional tile overlay
        let overlay = VFRTileOverlay()
        mapView.addOverlay(overlay, level: .aboveLabels)

        // Set initial region
        mapView.setRegion(region, animated: false)

        // Add long-press gesture recognizer
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)

        // Store reference
        context.coordinator.mapView = mapView

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator

        // Update callbacks
        coordinator.onRegionChanged = onRegionChanged
        coordinator.onAnnotationSelected = onAnnotationSelected
        coordinator.onPIREPSelected = onPIREPSelected
        coordinator.onLongPress = onLongPress

        // Handle tile reload (edition change)
        if tileReloadRequestCount > coordinator.lastTileReloadCount {
            coordinator.lastTileReloadCount = tileReloadRequestCount
            // Remove old tile overlay and add fresh one
            let tileOverlays = mapView.overlays.filter { $0 is VFRTileOverlay }
            mapView.removeOverlays(tileOverlays)
            mapView.insertOverlay(VFRTileOverlay(), at: 0, level: .aboveLabels)
        }

        // Handle centering request
        if centerRequestCount > coordinator.lastCenterRequestCount {
            coordinator.lastCenterRequestCount = centerRequestCount
            coordinator.hasUserInteracted = false
            coordinator.isProgrammaticChange = true
            mapView.setRegion(region, animated: true)
            return
        }

        // Skip if user has already interacted
        guard coordinator.shouldAcceptProgrammaticUpdate && !coordinator.hasUserInteracted else {
            // Still update overlays even if not re-centering
            updateAnnotations(mapView, context: context)
            updatePIREPAnnotations(mapView)
            updateGAIRMETOverlays(mapView)
            updateSIGMETOverlays(mapView)
            updateAirspacePolygons(mapView, context: context)
            updateQueryPin(mapView, context: context)
            return
        }

        let centerDelta = abs(mapView.region.center.latitude - region.center.latitude) +
                          abs(mapView.region.center.longitude - region.center.longitude)

        if centerDelta > 0.01 {
            coordinator.isProgrammaticChange = true
            mapView.setRegion(region, animated: true)
        }

        // Update overlays
        updateAnnotations(mapView, context: context)
        updatePIREPAnnotations(mapView)
        updateGAIRMETOverlays(mapView)
        updateSIGMETOverlays(mapView)
        updateAirspacePolygons(mapView, context: context)
        updateQueryPin(mapView, context: context)
    }

    // MARK: - Annotation Diffing

    private func updateAnnotations(_ mapView: MKMapView, context: Context) {
        let existing = Set(mapView.annotations.compactMap { $0 as? METARStationAnnotation })
        let desired = Set(metarAnnotations)

        let toRemove = existing.subtracting(desired)
        let toAdd = desired.subtracting(existing)

        if !toRemove.isEmpty {
            mapView.removeAnnotations(Array(toRemove))
        }
        if !toAdd.isEmpty {
            mapView.addAnnotations(Array(toAdd))
        }
    }

    private func updatePIREPAnnotations(_ mapView: MKMapView) {
        let existing = Set(mapView.annotations.compactMap { $0 as? PIREPAnnotation })
        let desired = Set(pirepAnnotations)

        let toRemove = existing.subtracting(desired)
        let toAdd = desired.subtracting(existing)

        if !toRemove.isEmpty {
            mapView.removeAnnotations(Array(toRemove))
        }
        if !toAdd.isEmpty {
            mapView.addAnnotations(Array(toAdd))
        }
    }

    private func updateGAIRMETOverlays(_ mapView: MKMapView) {
        let existingIDs = Set(mapView.overlays.compactMap { overlay -> String? in
            if let polygon = overlay as? MKPolygon, polygon.gairmetAdvisory != nil {
                return polygon.weatherOverlayID
            }
            if let polyline = overlay as? MKPolyline, polyline.gairmetAdvisory != nil {
                return polyline.weatherOverlayID
            }
            return nil
        })
        let desiredIDs = Set(gairmetAdvisories.map(\.id))

        guard existingIDs != desiredIDs else { return }

        let existing = mapView.overlays.filter { overlay in
            if let polygon = overlay as? MKPolygon { return polygon.gairmetAdvisory != nil }
            if let polyline = overlay as? MKPolyline { return polyline.gairmetAdvisory != nil }
            return false
        }
        if !existing.isEmpty {
            mapView.removeOverlays(existing)
        }

        for advisory in gairmetAdvisories {
            switch advisory.geometryType {
            case .area:
                if let overlay = GAIRMETOverlayFactory.makePolygon(for: advisory) {
                    mapView.addOverlay(overlay, level: .aboveLabels)
                }
            case .line:
                if let overlay = GAIRMETOverlayFactory.makePolyline(for: advisory) {
                    mapView.addOverlay(overlay, level: .aboveLabels)
                }
            default:
                continue
            }
        }
    }

    private func updateSIGMETOverlays(_ mapView: MKMapView) {
        let existingIDs = Set(mapView.overlays.compactMap { overlay -> String? in
            (overlay as? MKPolygon)?.sigmetAdvisory != nil ? (overlay as? MKPolygon)?.weatherOverlayID : nil
        })
        let desiredIDs = Set(sigmetAdvisories.map(\.id))

        guard existingIDs != desiredIDs else { return }

        let existing = mapView.overlays.filter { overlay in
            if let polygon = overlay as? MKPolygon { return polygon.sigmetAdvisory != nil }
            return false
        }
        if !existing.isEmpty {
            mapView.removeOverlays(existing)
        }

        for advisory in sigmetAdvisories {
            if let overlay = SIGMETOverlayFactory.makePolygon(for: advisory) {
                mapView.addOverlay(overlay, level: .aboveLabels)
            }
        }
    }

    private func updateAirspacePolygons(_ mapView: MKMapView, context: Context) {
        let existingPolygons = mapView.overlays.compactMap { $0 as? AirspaceOverlayPolygon }
        let desiredCount = airspacePolygons.count

        // Simple diff: if count or content changed, replace all
        if existingPolygons.count != desiredCount || context.coordinator.airspacePolygonsNeedUpdate {
            mapView.removeOverlays(existingPolygons)
            for polygon in airspacePolygons {
                mapView.addOverlay(polygon, level: .aboveLabels)
            }
            context.coordinator.airspacePolygonsNeedUpdate = false
        }
    }

    private func updateQueryPin(_ mapView: MKMapView, context: Context) {
        let existingPins = mapView.annotations.compactMap { $0 as? QueryPinAnnotation }

        if let newPin = queryPin {
            // Check if pin coordinate changed
            let needsUpdate = existingPins.isEmpty ||
                existingPins.first.map {
                    abs($0.coordinate.latitude - newPin.coordinate.latitude) > 0.0001 ||
                    abs($0.coordinate.longitude - newPin.coordinate.longitude) > 0.0001
                } ?? true

            if needsUpdate {
                mapView.removeAnnotations(existingPins)
                mapView.addAnnotation(newPin)
            }
        } else if !existingPins.isEmpty {
            mapView.removeAnnotations(existingPins)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: VFRMapView
        weak var mapView: MKMapView?
        var isProgrammaticChange = false
        var shouldAcceptProgrammaticUpdate = true
        private var isConstrainingZoom = false
        var hasUserInteracted = false
        var lastCenterRequestCount = 0
        var lastTileReloadCount = 0
        var airspacePolygonsNeedUpdate = true

        // Callbacks
        var onRegionChanged: ((MKCoordinateRegion) -> Void)?
        var onAnnotationSelected: ((METARStationAnnotation) -> Void)?
        var onPIREPSelected: ((PIREPAnnotation) -> Void)?
        var onLongPress: ((CLLocationCoordinate2D) -> Void)?

        init(_ parent: VFRMapView) {
            self.parent = parent
        }

        // MARK: - Overlay Renderer

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }

            if let polygon = overlay as? MKPolygon, let advisory = polygon.gairmetAdvisory {
                let renderer = MKPolygonRenderer(polygon: polygon)
                configure(renderer, for: advisory.hazard)
                return renderer
            }

            if let polyline = overlay as? MKPolyline, let advisory = polyline.gairmetAdvisory {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = gairmetStrokeColor(for: advisory.hazard)
                renderer.lineWidth = advisory.hazard == .freezingLevel || advisory.hazard == .multipleFreezingLevels ? 2.5 : 2.0
                renderer.lineDashPattern = [8, 5]
                return renderer
            }

            if let polygon = overlay as? MKPolygon, let advisory = polygon.sigmetAdvisory {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemRed.withAlphaComponent(0.16)
                renderer.strokeColor = UIColor.systemRed.withAlphaComponent(0.8)
                renderer.lineWidth = 2.5
                renderer.lineDashPattern = advisory.hazard == .convective ? nil : [8, 4]
                return renderer
            }

            if let airspacePolygon = overlay as? AirspaceOverlayPolygon {
                let renderer = MKPolygonRenderer(polygon: airspacePolygon)

                switch airspacePolygon.airspaceClass {
                case .classB:
                    renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.12)
                    renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.7)
                    renderer.lineWidth = 2.0
                case .classC:
                    renderer.fillColor = UIColor.systemPurple.withAlphaComponent(0.12)
                    renderer.strokeColor = UIColor.systemPurple.withAlphaComponent(0.7)
                    renderer.lineWidth = 2.0
                case .classD:
                    renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.08)
                    renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.5)
                    renderer.lineWidth = 1.5
                    renderer.lineDashPattern = [8, 4]
                case .classE:
                    renderer.fillColor = UIColor.systemPurple.withAlphaComponent(0.08)
                    renderer.strokeColor = UIColor.systemPurple.withAlphaComponent(0.5)
                    renderer.lineWidth = 1.5
                    renderer.lineDashPattern = [8, 4]
                default:
                    renderer.fillColor = UIColor.gray.withAlphaComponent(0.05)
                    renderer.strokeColor = UIColor.gray.withAlphaComponent(0.3)
                    renderer.lineWidth = 1.0
                }

                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: - Annotation View

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let metarAnnotation = annotation as? METARStationAnnotation {
                return METARAnnotationHelper.createMETARAnnotationView(for: metarAnnotation, in: mapView)
            }

            if let pirepAnnotation = annotation as? PIREPAnnotation {
                return ChartsWeatherOverlayHelper.createPIREPAnnotationView(for: pirepAnnotation, in: mapView)
            }

            if let queryAnnotation = annotation as? QueryPinAnnotation {
                return METARAnnotationHelper.createQueryPinView(for: queryAnnotation, in: mapView)
            }

            return nil // Default for user location
        }

        // MARK: - Annotation Selection

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            if let metarAnnotation = annotation as? METARStationAnnotation {
                mapView.deselectAnnotation(annotation, animated: false)
                onAnnotationSelected?(metarAnnotation)
            } else if let pirepAnnotation = annotation as? PIREPAnnotation {
                mapView.deselectAnnotation(annotation, animated: false)
                onPIREPSelected?(pirepAnnotation)
            }
        }

        // MARK: - Long Press

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let mapView = mapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            onLongPress?(coordinate)
        }

        // MARK: - Region Change

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            if !isProgrammaticChange {
                shouldAcceptProgrammaticUpdate = false
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            shouldAcceptProgrammaticUpdate = true

            let wasProgrammatic = isProgrammaticChange
            isProgrammaticChange = false

            if !wasProgrammatic && !isConstrainingZoom {
                hasUserInteracted = true
            }

            // Calculate current zoom level
            let currentZoom = calculateZoomLevel(for: mapView)

            DispatchQueue.main.async {
                self.parent.currentZoomLevel = currentZoom
            }

            // Notify overlay manager of region change
            onRegionChanged?(mapView.region)

            // Track if airspace polygons need refresh on next updateUIView
            airspacePolygonsNeedUpdate = true

            // Constrain zoom if outside valid range
            if !isConstrainingZoom && !wasProgrammatic {
                let spanDelta = mapView.region.span.longitudeDelta

                if spanDelta < VFRMapView.minSpanDelta {
                    isConstrainingZoom = true
                    let constrainedRegion = MKCoordinateRegion(
                        center: mapView.region.center,
                        span: MKCoordinateSpan(
                            latitudeDelta: VFRMapView.minSpanDelta,
                            longitudeDelta: VFRMapView.minSpanDelta
                        )
                    )
                    mapView.setRegion(constrainedRegion, animated: true)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isConstrainingZoom = false
                    }
                } else if spanDelta > VFRMapView.maxSpanDelta {
                    isConstrainingZoom = true
                    let constrainedRegion = MKCoordinateRegion(
                        center: mapView.region.center,
                        span: MKCoordinateSpan(
                            latitudeDelta: VFRMapView.maxSpanDelta,
                            longitudeDelta: VFRMapView.maxSpanDelta
                        )
                    )
                    mapView.setRegion(constrainedRegion, animated: true)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isConstrainingZoom = false
                    }
                }
            }
        }

        private func calculateZoomLevel(for mapView: MKMapView) -> Int {
            let longitudeDelta = mapView.region.span.longitudeDelta
            let zoomLevel = Int(round(log2(360.0 / longitudeDelta)))
            return max(0, min(20, zoomLevel))
        }

        private func configure(_ renderer: MKPolygonRenderer, for hazard: GAIRMETHazard) {
            switch hazard {
            case .ifr:
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.12)
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.75)
            case .mountainObscuration:
                renderer.fillColor = UIColor.systemGray.withAlphaComponent(0.14)
                renderer.strokeColor = UIColor.systemGray.withAlphaComponent(0.8)
            case .icing:
                renderer.fillColor = UIColor.systemTeal.withAlphaComponent(0.16)
                renderer.strokeColor = UIColor.systemTeal.withAlphaComponent(0.85)
            case .turbulenceLow, .turbulenceHigh:
                renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.16)
                renderer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.85)
            case .lowLevelWindShear, .surfaceWind:
                renderer.fillColor = UIColor.systemYellow.withAlphaComponent(0.15)
                renderer.strokeColor = UIColor.systemYellow.withAlphaComponent(0.8)
            case .freezingLevel, .multipleFreezingLevels, .unknown:
                renderer.fillColor = UIColor.systemCyan.withAlphaComponent(0.1)
                renderer.strokeColor = UIColor.systemCyan.withAlphaComponent(0.75)
            }
            renderer.lineWidth = 2.0
        }

        private func gairmetStrokeColor(for hazard: GAIRMETHazard) -> UIColor {
            switch hazard {
            case .freezingLevel, .multipleFreezingLevels:
                return UIColor.systemCyan.withAlphaComponent(0.9)
            case .turbulenceLow, .turbulenceHigh:
                return UIColor.systemOrange.withAlphaComponent(0.85)
            case .icing:
                return UIColor.systemTeal.withAlphaComponent(0.85)
            case .ifr:
                return UIColor.systemBlue.withAlphaComponent(0.85)
            case .mountainObscuration:
                return UIColor.systemGray.withAlphaComponent(0.85)
            case .lowLevelWindShear, .surfaceWind:
                return UIColor.systemYellow.withAlphaComponent(0.8)
            case .unknown:
                return UIColor.systemCyan.withAlphaComponent(0.85)
            }
        }
    }
}

// MARK: - VFR Tile Overlay

class VFRTileOverlay: MKTileOverlay {
    private let cache = VFRChartCacheService.shared

    init() {
        let template = "https://tiles.arcgis.com/tiles/ssFJjBXIUyZDrSYZ/arcgis/rest/services/VFR_Sectional/MapServer/tile/{z}/{y}/{x}"
        super.init(urlTemplate: template)

        self.minimumZ = 8
        self.maximumZ = 12
        self.tileSize = CGSize(width: 256, height: 256)
        self.canReplaceMapContent = false
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        if let cachedData = cache.cachedTile(z: path.z, y: path.y, x: path.x) {
            result(cachedData, nil)
            return
        }

        super.loadTile(at: path) { [weak self] data, error in
            if let data = data, error == nil {
                self?.cache.cacheTile(data: data, z: path.z, y: path.y, x: path.x)
            }
            result(data, error)
        }
    }
}

// MARK: - Zoom Warning Card

struct ZoomWarningCard: View {
    let currentZoom: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text("Zoom Level Outside Range")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(currentZoom < 8 ? "Zoom in to see chart details (Z8-12)" : "Zoom out for better coverage (Z8-12)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()
        }
        .padding()
        .background(Color.orange)
        .cornerRadius(12)
    }
}

struct ChartsStatusBanner: View {
    let systemImage: String
    let message: String
    let tint: Color
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundColor(tint)

            Text(message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.semibold))
            }

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Chart Info Card

struct ChartInfoCard: View {
    var cacheStatus: String = ""

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("FAA VFR Sectional")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                if cacheStatus.isEmpty || cacheStatus == "Empty" {
                    Text("Official aviation charts \u{2022} Auto-updated with FAA editions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Cached: \(cacheStatus)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Charts Location Manager

class ChartsLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let locationHelper = LocationHelper.shared

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var lastErrorMessage: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus

        if locationHelper.isRunningInSimulator {
            currentLocation = locationHelper.defaultSimulatorLocation
        }
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startLocationUpdates() {
        lastErrorMessage = nil

        if locationHelper.isRunningInSimulator && currentLocation == nil {
            currentLocation = locationHelper.defaultSimulatorLocation
        }

        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            if locationHelper.isRunningInSimulator && currentLocation == nil {
                currentLocation = locationHelper.defaultSimulatorLocation
            }
            return
        }
        manager.startUpdatingLocation()
    }

    func stopLocationUpdates() {
        manager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startLocationUpdates()
        }

        if locationHelper.isRunningInSimulator &&
           (authorizationStatus == .denied || authorizationStatus == .notDetermined) {
            currentLocation = locationHelper.defaultSimulatorLocation
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastErrorMessage = nil
        currentLocation = location.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Charts location manager error: \(error.localizedDescription)")
        lastErrorMessage = "Unable to determine your current location. Please try again."

        if locationHelper.isRunningInSimulator && currentLocation == nil {
            currentLocation = locationHelper.defaultSimulatorLocation
        }
    }
}

#Preview {
    ChartsView(isPresented: .constant(true))
}
