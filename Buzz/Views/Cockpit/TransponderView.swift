//
//  TransponderView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import CoreLocation
import Combine
import Auth

struct TransponderView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var transponderService = TransponderService()
    @StateObject private var locationManager = LocationManager()
    
    @State private var showingAddDevice = false
    @State private var deviceName = ""
    @State private var remoteId = ""
    @State private var isLocationTrackingEnabled = false
    @State private var locationUpdateTimer: Timer?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transponder")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Manage your drones and track location")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
                
                // Location Permission Banner
                if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                    LocationPermissionBanner()
                        .padding(.horizontal)
                }
                
                // Add Drone Button
                Button(action: {
                    showingAddDevice = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("Add Drone")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Transponders List
                if transponderService.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if transponderService.transponders.isEmpty {
                    EmptyStateView(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "No Drones",
                        message: "Add your first drone to get started"
                    )
                    .padding(.top, 40)
                } else {
                    VStack(spacing: 16) {
                        ForEach(transponderService.transponders) { transponder in
                            TransponderCard(
                                transponder: transponder,
                                locationManager: locationManager,
                                onToggleLocationTracking: { isEnabled in
                                    Task {
                                        try? await transponderService.updateLocationTrackingStatus(
                                            transponderId: transponder.id,
                                            isEnabled: isEnabled
                                        )
                                        // Refresh to get updated location status
                                        if let pilotId = authService.currentUser?.id {
                                            try? await transponderService.fetchTransponders(pilotId: pilotId)
                                        }
                                    }
                                },
                                onEdit: { editedTransponder in
                                    Task {
                                        try? await transponderService.updateTransponder(
                                            transponderId: editedTransponder.id,
                                            deviceName: editedTransponder.deviceName,
                                            remoteId: editedTransponder.remoteId,
                                            isLocationTrackingEnabled: editedTransponder.isLocationTrackingEnabled
                                        )
                                    }
                                },
                                onDelete: {
                                    Task {
                                        if let pilotId = authService.currentUser?.id {
                                            try? await transponderService.deleteTransponder(
                                                transponderId: transponder.id,
                                                pilotId: pilotId
                                            )
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .navigationTitle("Transponder")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddDevice) {
            AddTransponderSheet(
                deviceName: $deviceName,
                remoteId: $remoteId,
                isLocationTrackingEnabled: $isLocationTrackingEnabled,
                locationManager: locationManager,
                onSave: {
                    Task {
                        if let pilotId = authService.currentUser?.id {
                            try? await transponderService.createTransponder(
                                pilotId: pilotId,
                                deviceName: deviceName,
                                remoteId: remoteId,
                                isLocationTrackingEnabled: isLocationTrackingEnabled
                            )
                            // Reset form
                            deviceName = ""
                            remoteId = ""
                            isLocationTrackingEnabled = false
                            showingAddDevice = false
                        }
                    }
                }
            )
        }
        .task {
            await loadTransponders()
            locationManager.requestPermission()
            startLocationUpdatesIfNeeded()
        }
        .refreshable {
            await loadTransponders()
        }
        .onChange(of: transponderService.transponders.count) { _, _ in
            startLocationUpdatesIfNeeded()
        }
        .onChange(of: locationManager.authorizationStatus.rawValue) { _, _ in
            startLocationUpdatesIfNeeded()
        }
        .onReceive(locationManager.$currentLocation) { location in
            if let location = location {
                updateTransponderLocations(location: location)
            }
        }
        .onDisappear {
            stopLocationUpdates()
        }
    }
    
    private func loadTransponders() async {
        guard let currentUser = authService.currentUser else { return }
        try? await transponderService.fetchTransponders(pilotId: currentUser.id)
    }
    
    private func startLocationUpdatesIfNeeded() {
        // Check if any transponder has location tracking enabled
        let hasTrackingEnabled = transponderService.transponders.contains { $0.isLocationTrackingEnabled }
        
        if hasTrackingEnabled && locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.startLocationUpdates()
        } else {
            locationManager.stopLocationUpdates()
        }
    }
    
    private func updateTransponderLocations(location: CLLocationCoordinate2D) {
        // Update location for all transponders with tracking enabled
        for transponder in transponderService.transponders where transponder.isLocationTrackingEnabled {
            Task {
                try? await transponderService.updateTransponderLocation(
                    transponderId: transponder.id,
                    location: location
                )
            }
        }
    }
    
    private func stopLocationUpdates() {
        locationManager.stopLocationUpdates()
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
}

// MARK: - Transponder Card

struct TransponderCard: View {
    let transponder: Transponder
    let locationManager: LocationManager
    let onToggleLocationTracking: (Bool) -> Void
    let onEdit: (Transponder) -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    @State private var showingEditSheet = false
    @State private var isTrackingEnabled: Bool
    @State private var pendingEnable: Bool = false
    
    init(transponder: Transponder, locationManager: LocationManager, onToggleLocationTracking: @escaping (Bool) -> Void, onEdit: @escaping (Transponder) -> Void, onDelete: @escaping () -> Void) {
        self.transponder = transponder
        self.locationManager = locationManager
        self.onToggleLocationTracking = onToggleLocationTracking
        self.onEdit = onEdit
        self.onDelete = onDelete
        _isTrackingEnabled = State(initialValue: transponder.isLocationTrackingEnabled)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transponder.deviceName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Remote ID: \(transponder.remoteId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        showingEditSheet = true
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                    }
                    
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 16))
                    }
                }
            }
            
            Divider()
            
            // Location Tracking Toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location Tracking")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if transponder.isLocationTrackingEnabled {
                        if let updateTime = transponder.lastLocationUpdate {
                            Text("Last updated: \(formatTime(updateTime))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Waiting for location...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Tracking disabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { isTrackingEnabled },
                    set: { newValue in
                        if newValue {
                            // Requesting to enable - check permission first
                            if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                                // Permission already granted, enable tracking
                                isTrackingEnabled = newValue
                                pendingEnable = false
                                onToggleLocationTracking(newValue)
                            } else {
                                // Request permission - mark as pending enable
                                pendingEnable = true
                                locationManager.requestPermission()
                                // Don't update toggle yet - wait for permission
                            }
                        } else {
                            // Disabling - always allow
                            isTrackingEnabled = newValue
                            pendingEnable = false
                            onToggleLocationTracking(newValue)
                        }
                    }
                ))
                .disabled(locationManager.authorizationStatus != .authorizedWhenInUse && locationManager.authorizationStatus != .authorizedAlways && !isTrackingEnabled)
                .onAppear {
                    isTrackingEnabled = transponder.isLocationTrackingEnabled
                    pendingEnable = false
                }
                .onChange(of: transponder.isLocationTrackingEnabled) { _, newValue in
                    isTrackingEnabled = newValue
                }
                .onChange(of: locationManager.authorizationStatus.rawValue) { _, _ in
                    // If permission was just granted and user wanted to enable tracking, enable it now
                    if pendingEnable && (locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways) {
                        // User just granted permission, enable tracking
                        isTrackingEnabled = true
                        pendingEnable = false
                        onToggleLocationTracking(true)
                    }
                }
            }
            
            // Show location if available
            if transponder.isLocationTrackingEnabled, let location = transponder.lastLocation {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text(String(format: "%.6f, %.6f", location.latitude, location.longitude))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
        .sheet(isPresented: $showingEditSheet) {
            EditTransponderSheet(
                transponder: transponder,
                locationManager: locationManager,
                onSave: { editedTransponder in
                    onEdit(editedTransponder)
                    showingEditSheet = false
                }
            )
        }
        .alert("Delete Drone", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete \(transponder.deviceName)?")
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Edit Transponder Sheet

struct EditTransponderSheet: View {
    let transponder: Transponder
    let locationManager: LocationManager
    let onSave: (Transponder) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var deviceName: String
    @State private var remoteId: String
    @State private var isLocationTrackingEnabled: Bool
    @State private var pendingEnable: Bool = false
    
    init(transponder: Transponder, locationManager: LocationManager, onSave: @escaping (Transponder) -> Void) {
        self.transponder = transponder
        self.locationManager = locationManager
        self.onSave = onSave
        _deviceName = State(initialValue: transponder.deviceName)
        _remoteId = State(initialValue: transponder.remoteId)
        _isLocationTrackingEnabled = State(initialValue: transponder.isLocationTrackingEnabled)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Drone Information")) {
                    TextField("Drone Name", text: $deviceName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Remote ID", text: $remoteId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section(header: Text("Location Tracking")) {
                    Toggle("Enable Location Tracking", isOn: Binding(
                        get: { isLocationTrackingEnabled },
                        set: { newValue in
                            if newValue {
                                if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                                    isLocationTrackingEnabled = newValue
                                    pendingEnable = false
                                } else {
                                    // Request permission - mark as pending enable
                                    pendingEnable = true
                                    locationManager.requestPermission()
                                }
                            } else {
                                isLocationTrackingEnabled = newValue
                                pendingEnable = false
                            }
                        }
                    ))
                    .onChange(of: locationManager.authorizationStatus.rawValue) { _, _ in
                        // If permission was just granted and user wanted to enable tracking, enable it now
                        if pendingEnable && (locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways) {
                            isLocationTrackingEnabled = true
                            pendingEnable = false
                        }
                    }
                    
                    if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                        Text("Location permission is required for tracking. Please enable it in Settings.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Drone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let edited = Transponder(
                            id: transponder.id,
                            pilotId: transponder.pilotId,
                            deviceName: deviceName,
                            remoteId: remoteId,
                            isLocationTrackingEnabled: isLocationTrackingEnabled,
                            lastLocationLat: transponder.lastLocationLat,
                            lastLocationLng: transponder.lastLocationLng,
                            lastLocationUpdate: transponder.lastLocationUpdate,
                            speed: transponder.speed,
                            altitude: transponder.altitude,
                            createdAt: transponder.createdAt
                        )
                        onSave(edited)
                    }
                    .disabled(deviceName.isEmpty || remoteId.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Transponder Sheet

struct AddTransponderSheet: View {
    @Binding var deviceName: String
    @Binding var remoteId: String
    @Binding var isLocationTrackingEnabled: Bool
    let locationManager: LocationManager
    let onSave: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var pendingEnable: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Drone Information")) {
                    TextField("Drone Name", text: $deviceName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Remote ID", text: $remoteId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section(header: Text("Location Tracking")) {
                    Toggle("Enable Location Tracking", isOn: Binding(
                        get: { isLocationTrackingEnabled },
                        set: { newValue in
                            if newValue {
                                if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                                    isLocationTrackingEnabled = newValue
                                    pendingEnable = false
                                } else {
                                    // Request permission - mark as pending enable
                                    pendingEnable = true
                                    locationManager.requestPermission()
                                }
                            } else {
                                isLocationTrackingEnabled = newValue
                                pendingEnable = false
                            }
                        }
                    ))
                    .onChange(of: locationManager.authorizationStatus.rawValue) { _, _ in
                        // If permission was just granted and user wanted to enable tracking, enable it now
                        if pendingEnable && (locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways) {
                            isLocationTrackingEnabled = true
                            pendingEnable = false
                        }
                    }
                    
                    if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                        Text("Location permission is required for tracking. Please enable it in Settings.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add Drone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(deviceName.isEmpty || remoteId.isEmpty)
                }
            }
        }
    }
}

// MARK: - Location Permission Banner

struct LocationPermissionBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
                .foregroundColor(.orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Location Permission Required")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Enable location access in Settings to track your pilot location")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
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
        // Request permission - iOS will only show dialog if status is .notDetermined
        // If already denied/restricted, this won't show dialog but that's expected
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
        print("Location manager error: \(error.localizedDescription)")
        
        // In simulator, fallback to default location on error
        if locationHelper.isRunningInSimulator && currentLocation == nil {
            currentLocation = locationHelper.defaultSimulatorLocation
        }
    }
}

