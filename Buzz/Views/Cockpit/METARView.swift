//
//  METARView.swift
//  Buzz
//
//  Created by Xinyu Fang on 1/27/26.
//

import SwiftUI
import CoreLocation
import Auth

struct METARView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var metarService = METARService()
    @StateObject private var locationManager = WeatherLocationManager()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Nearby METAR Reports
                METARSectionView(metarService: metarService, userCoordinate: locationManager.currentLocation)
            }
            .padding()
        }
        .navigationTitle("METAR")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMETARData()
        }
        .refreshable {
            await loadMETARData(forceRefresh: true)
        }
        .onChange(of: locationManager.currentLocation?.latitude) { _, _ in
            if locationManager.currentLocation != nil {
                Task {
                    await loadNearbyMETARs()
                }
            }
        }
        .onChange(of: locationManager.currentLocation?.longitude) { _, _ in
            if locationManager.currentLocation != nil {
                Task {
                    await loadNearbyMETARs()
                }
            }
        }
    }
    
    private func loadMETARData(forceRefresh: Bool = false) async {
        // Request location permission if needed
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestPermission()
        }
        
        // Start location updates (if permission granted)
        if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startLocationUpdates()
            // Wait a moment for location to be acquired
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // Load nearby METARs
        await loadNearbyMETARs(forceRefresh: forceRefresh)
    }
    
    private func loadNearbyMETARs(forceRefresh: Bool = false) async {
        guard let userProfile = authService.userProfile,
              userProfile.userType == .pilot else { return }
        
        // Wait for location if not available
        var deviceLocation: CLLocationCoordinate2D? = locationManager.currentLocation
        if deviceLocation == nil {
            for _ in 0..<6 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                deviceLocation = locationManager.currentLocation
                if deviceLocation != nil {
                    break
                }
            }
        }
        
        guard let location = deviceLocation else {
            print("Unable to get device location for METAR")
            return
        }
        
        do {
            _ = try await metarService.fetchMETARsNearLocation(
                coordinate: location,
                forceRefresh: forceRefresh
            )
        } catch {
            print("Error fetching nearby METARs: \(error.localizedDescription)")
        }
    }
}
