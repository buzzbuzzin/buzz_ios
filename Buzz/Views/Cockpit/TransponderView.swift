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
    @State private var isLocationTrackingEnabled = true // Always enabled
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
                                onToggleLocationTracking: { _ in },
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
                            isLocationTrackingEnabled = true
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
    
    init(transponder: Transponder, locationManager: LocationManager, onToggleLocationTracking: @escaping (Bool) -> Void, onEdit: @escaping (Transponder) -> Void, onDelete: @escaping () -> Void) {
        self.transponder = transponder
        self.locationManager = locationManager
        self.onToggleLocationTracking = onToggleLocationTracking
        self.onEdit = onEdit
        self.onDelete = onDelete
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
            
            // Location Status
            if transponder.isLocationTrackingEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location Tracking")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                        if let updateTime = transponder.lastLocationUpdate {
                            Text("Last updated: \(formatTime(updateTime))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Waiting for location...")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
    @State private var make: String
    @State private var model: String
    @State private var remoteId: String
    
    init(transponder: Transponder, locationManager: LocationManager, onSave: @escaping (Transponder) -> Void) {
        self.transponder = transponder
        self.locationManager = locationManager
        self.onSave = onSave
        
        // Parse deviceName into make and model
        // Assume format is "Make Model" or just use deviceName as model if no space
        let components = transponder.deviceName.split(separator: " ", maxSplits: 1)
        if components.count >= 2 {
            _make = State(initialValue: String(components[0]))
            _model = State(initialValue: String(components[1]))
        } else {
            _make = State(initialValue: "")
            _model = State(initialValue: transponder.deviceName)
        }
        _remoteId = State(initialValue: transponder.remoteId)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Drone Information")) {
                    TextField("Make", text: $make)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Model", text: $model)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Remote ID", text: $remoteId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
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
                        let deviceName = make.isEmpty ? model : "\(make) \(model)".trimmingCharacters(in: .whitespaces)
                        let edited = Transponder(
                            id: transponder.id,
                            pilotId: transponder.pilotId,
                            deviceName: deviceName,
                            remoteId: remoteId,
                            isLocationTrackingEnabled: transponder.isLocationTrackingEnabled,
                            lastLocationLat: transponder.lastLocationLat,
                            lastLocationLng: transponder.lastLocationLng,
                            lastLocationUpdate: transponder.lastLocationUpdate,
                            speed: transponder.speed,
                            altitude: transponder.altitude,
                            createdAt: transponder.createdAt
                        )
                        onSave(edited)
                    }
                    .disabled(model.isEmpty || remoteId.isEmpty)
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
    @State private var make: String = ""
    @State private var model: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Drone Information")) {
                    TextField("Make", text: $make)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Model", text: $model)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Remote ID", text: $remoteId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
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
                        // Combine make and model into deviceName
                        deviceName = make.isEmpty ? model : "\(make) \(model)".trimmingCharacters(in: .whitespaces)
                        // Always enable location tracking
                        isLocationTrackingEnabled = true
                        onSave()
                    }
                    .disabled(model.isEmpty || remoteId.isEmpty)
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

