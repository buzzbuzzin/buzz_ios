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

struct ChartsView: View {
    @Binding var isPresented: Bool
    @StateObject private var locationManager = ChartsLocationManager()
    @State private var region = MKCoordinateRegion(
        center: LocationHelper.shared.defaultSimulatorLocation,
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @State private var currentZoomLevel: Int = 10
    @State private var centerRequestCount: Int = 0  // Increment to request centering
    
    var body: some View {
        ZStack {
            // VFR Sectional Map
            VFRMapView(
                region: $region,
                currentZoomLevel: $currentZoomLevel,
                centerRequestCount: $centerRequestCount,
                userLocation: locationManager.currentLocation
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
                    
                    HStack(spacing: 12) {
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
                    }
                }
                .padding()
                .background(Color(.systemBackground).opacity(0.95))
                
                // Zoom Warning (when outside valid range)
                if currentZoomLevel < 8 || currentZoomLevel > 11 {
                    ZoomWarningCard(currentZoom: currentZoomLevel)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                // Chart Info Card
                ChartInfoCard()
                    .padding()
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
        }
        .onDisappear {
            locationManager.stopLocationUpdates()
        }
        .onReceive(locationManager.$currentLocation) { newLocation in
            // Center on first location update if we haven't moved yet
            if let location = newLocation, region.center.latitude == LocationHelper.shared.defaultSimulatorLocation.latitude {
                withAnimation(.easeInOut(duration: 0.5)) {
                    region = MKCoordinateRegion(
                        center: location,
                        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                    )
                }
            }
        }
    }
    
    private var zoomLevelColor: Color {
        if currentZoomLevel >= 8 && currentZoomLevel <= 11 {
            return .green
        } else {
            return .orange
        }
    }
    
    private func centerOnUserLocation() {
        if let userLocation = locationManager.currentLocation {
            // Update region and request centering
            region = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
            )
            centerRequestCount += 1  // Trigger explicit centering
            return
        }
        
        // Request permission if not determined
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestPermission()
        }
        
        // Start location updates
        locationManager.startLocationUpdates()
    }
}

// MARK: - VFR Map View (UIViewRepresentable)

struct VFRMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var currentZoomLevel: Int
    @Binding var centerRequestCount: Int  // Increment to explicitly request centering
    var userLocation: CLLocationCoordinate2D?
    
    // Zoom level constraints for FAA VFR Sectional tiles
    static let minZoom = 8
    static let maxZoom = 11
    
    // Corresponding span deltas for zoom levels
    // Formula: longitudeDelta = 360.0 / pow(2, zoomLevel)
    static let minSpanDelta: Double = 360.0 / pow(2, Double(maxZoom)) // ~0.176 for Z11
    static let maxSpanDelta: Double = 360.0 / pow(2, Double(minZoom)) // ~1.406 for Z8
    
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
        
        // Store reference for programmatic updates
        context.coordinator.mapView = mapView
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Check if user explicitly requested centering (via "My Location" button)
        if centerRequestCount > context.coordinator.lastCenterRequestCount {
            context.coordinator.lastCenterRequestCount = centerRequestCount
            context.coordinator.hasUserInteracted = false  // Reset to allow this center
            context.coordinator.isProgrammaticChange = true
            mapView.setRegion(region, animated: true)
            return
        }
        
        // Skip if user has already interacted with the map (panning/zooming)
        // This prevents GPS updates from resetting the map position
        guard context.coordinator.shouldAcceptProgrammaticUpdate && !context.coordinator.hasUserInteracted else { return }
        
        let centerDelta = abs(mapView.region.center.latitude - region.center.latitude) +
                          abs(mapView.region.center.longitude - region.center.longitude)
        
        if centerDelta > 0.01 {
            context.coordinator.isProgrammaticChange = true
            mapView.setRegion(region, animated: true)
        }
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: VFRMapView
        weak var mapView: MKMapView?
        var isProgrammaticChange = false
        var shouldAcceptProgrammaticUpdate = true
        private var isConstrainingZoom = false
        var hasUserInteracted = false  // Track if user has panned/zoomed
        var lastCenterRequestCount = 0  // Track explicit center requests
        
        init(_ parent: VFRMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // Disable programmatic updates while user is interacting
            if !isProgrammaticChange {
                shouldAcceptProgrammaticUpdate = false
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Re-enable programmatic updates
            shouldAcceptProgrammaticUpdate = true
            
            // Reset programmatic change flag
            let wasProgrammatic = isProgrammaticChange
            isProgrammaticChange = false
            
            // Mark that user has interacted with the map (panning/zooming)
            if !wasProgrammatic && !isConstrainingZoom {
                hasUserInteracted = true
            }
            
            // Calculate current zoom level
            let currentZoom = calculateZoomLevel(for: mapView)
            
            // Update zoom level display
            DispatchQueue.main.async {
                self.parent.currentZoomLevel = currentZoom
            }
            
            // Constrain zoom if outside valid range (and not already constraining to avoid loop)
            if !isConstrainingZoom && !wasProgrammatic {
                let spanDelta = mapView.region.span.longitudeDelta
                
                if spanDelta < VFRMapView.minSpanDelta {
                    // User zoomed in too much (beyond Z11) - snap back to Z11
                    isConstrainingZoom = true
                    let constrainedRegion = MKCoordinateRegion(
                        center: mapView.region.center,
                        span: MKCoordinateSpan(
                            latitudeDelta: VFRMapView.minSpanDelta,
                            longitudeDelta: VFRMapView.minSpanDelta
                        )
                    )
                    mapView.setRegion(constrainedRegion, animated: true)
                    
                    // Reset flag after animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isConstrainingZoom = false
                    }
                } else if spanDelta > VFRMapView.maxSpanDelta {
                    // User zoomed out too much (beyond Z8) - snap back to Z8
                    isConstrainingZoom = true
                    let constrainedRegion = MKCoordinateRegion(
                        center: mapView.region.center,
                        span: MKCoordinateSpan(
                            latitudeDelta: VFRMapView.maxSpanDelta,
                            longitudeDelta: VFRMapView.maxSpanDelta
                        )
                    )
                    mapView.setRegion(constrainedRegion, animated: true)
                    
                    // Reset flag after animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isConstrainingZoom = false
                    }
                }
            }
        }
        
        private func calculateZoomLevel(for mapView: MKMapView) -> Int {
            // Calculate zoom level based on the visible span
            // This approximation works for Web Mercator projection
            let longitudeDelta = mapView.region.span.longitudeDelta
            let zoomLevel = Int(round(log2(360.0 / longitudeDelta)))
            return max(0, min(20, zoomLevel))
        }
    }
}

// MARK: - VFR Tile Overlay

class VFRTileOverlay: MKTileOverlay {
    init() {
        // FAA VFR Sectional tile service URL template
        // ArcGIS uses /tile/z/y/x format
        let template = "https://tiles.arcgis.com/tiles/ssFJjBXIUyZDrSYZ/arcgis/rest/services/VFR_Sectional/MapServer/tile/{z}/{y}/{x}"
        super.init(urlTemplate: template)
        
        // Configure tile overlay
        self.minimumZ = 8  // Valid zoom range for reliable tile loading
        self.maximumZ = 11 // Limit to Z11 to ensure tiles are always available
        self.tileSize = CGSize(width: 256, height: 256)
        self.canReplaceMapContent = false // Show base map underneath
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
                
                Text(currentZoom < 8 ? "Zoom in to see chart details (Z8-11)" : "Zoom out for better coverage (Z8-11)")
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

// MARK: - Chart Info Card

struct ChartInfoCard: View {
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
                
                Text("Official aviation charts • Updated regularly")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
        
        // Set default location for simulator if running in simulator
        if locationHelper.isRunningInSimulator {
            currentLocation = locationHelper.defaultSimulatorLocation
        }
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        // In simulator, use default location if no GPS available
        if locationHelper.isRunningInSimulator && currentLocation == nil {
            currentLocation = locationHelper.defaultSimulatorLocation
        }
        
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            // In simulator, still provide default location even without permission
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
        
        // If permission was just granted, start location updates
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startLocationUpdates()
        }
        
        // In simulator, set default location if permission not granted
        if locationHelper.isRunningInSimulator &&
           (authorizationStatus == .denied || authorizationStatus == .notDetermined) {
            currentLocation = locationHelper.defaultSimulatorLocation
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Charts location manager error: \(error.localizedDescription)")
        
        // In simulator, fallback to default location on error
        if locationHelper.isRunningInSimulator && currentLocation == nil {
            currentLocation = locationHelper.defaultSimulatorLocation
        }
    }
}

#Preview {
    ChartsView(isPresented: .constant(true))
}
