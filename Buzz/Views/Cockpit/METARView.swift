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
    @StateObject private var nearbyMETARService = METARService()
    @StateObject private var searchedMETARService = METARService()
    @StateObject private var locationManager = WeatherLocationManager()
    private let airportLookupService = AviationWeatherAirportLookupService()

    @State private var airportSearchQuery = ""
    @State private var activeAirport: AviationWeatherAirportInfo?
    @State private var searchErrorMessage: String?
    @State private var isSearchingAirport = false

    private var locationObservationKey: String? {
        guard let location = locationManager.currentLocation else { return nil }
        return String(format: "%.6f,%.6f", location.latitude, location.longitude)
    }

    private var airportSearchBinding: Binding<String> {
        Binding(
            get: { airportSearchQuery },
            set: { airportSearchQuery = $0.normalizedICAOCode }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                AirportWeatherSearchCard(
                    airportCode: airportSearchBinding,
                    activeAirport: activeAirport,
                    isSearching: isSearchingAirport,
                    errorMessage: searchErrorMessage,
                    onSearch: {
                        Task {
                            await searchForAirport()
                        }
                    },
                    onClear: {
                        clearAirportSearch()
                    }
                )

                if let activeAirport, let searchCoordinate = activeAirport.coordinate {
                    METARSectionView(
                        metarService: searchedMETARService,
                        userCoordinate: searchCoordinate,
                        title: "METAR Around \(activeAirport.icaoId)",
                        helperText: "Search results centered on \(activeAirport.displayName). Distances are measured from this airport.",
                        loadingMessage: "Loading searched METAR reports...",
                        emptyStateTitle: "No METAR reports found around \(activeAirport.icaoId)"
                    )
                }

                METARSectionView(
                    metarService: nearbyMETARService,
                    userCoordinate: locationManager.currentLocation
                )
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("METAR")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshAllData()
        }
        .refreshable {
            guard !nearbyMETARService.isLoading, !searchedMETARService.isLoading, !isSearchingAirport else { return }
            await refreshAllData(forceRefresh: true)
        }
        .onChange(of: airportSearchQuery) { _, newValue in
            handleAirportSearchQueryChange(newValue)
        }
        .onChange(of: locationObservationKey) { _, newKey in
            if newKey != nil {
                Task {
                    await loadNearbyMETARs()
                }
            }
        }
    }

    private func refreshAllData(forceRefresh: Bool = false) async {
        await loadNearbyMETARs(forceRefresh: forceRefresh)

        if let activeAirport,
           let searchCoordinate = activeAirport.coordinate {
            await loadSearchMETARs(
                for: activeAirport,
                coordinate: searchCoordinate,
                forceRefresh: forceRefresh
            )
        }
    }

    private func loadNearbyMETARs(forceRefresh: Bool = false) async {
        guard let userProfile = authService.userProfile,
              userProfile.userType == .pilot else { return }

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
            nearbyMETARService.errorMessage = "Location unavailable. Enable location access to load nearby METARs."
            print("Unable to get device location for METAR")
            return
        }
        
        do {
            _ = try await nearbyMETARService.fetchMETARsNearLocation(
                coordinate: location,
                forceRefresh: forceRefresh
            )
        } catch {
            print("Error fetching nearby METARs: \(error.localizedDescription)")
        }
    }

    private func loadSearchMETARs(
        for airport: AviationWeatherAirportInfo,
        coordinate: CLLocationCoordinate2D,
        forceRefresh: Bool = false
    ) async {
        guard let userProfile = authService.userProfile,
              userProfile.userType == .pilot else { return }

        do {
            _ = try await searchedMETARService.fetchMETARsNearLocation(
                coordinate: coordinate,
                forceRefresh: forceRefresh
            )
        } catch {
            searchedMETARService.errorMessage = "Unable to load METAR around \(airport.icaoId)."
            print("Error fetching searched METARs: \(error.localizedDescription)")
        }
    }

    private func searchForAirport() async {
        guard !isSearchingAirport else { return }

        let normalizedCode = airportSearchQuery.normalizedICAOCode
        guard normalizedCode.count == 4 else {
            searchErrorMessage = AviationWeatherAirportLookupError.invalidICAOCode.errorDescription
            return
        }

        isSearchingAirport = true
        searchErrorMessage = nil
        defer { isSearchingAirport = false }

        do {
            let previousAirportCode = activeAirport?.icaoId
            if previousAirportCode != normalizedCode {
                clearAirportResults()
            }

            let airport = try await airportLookupService.fetchAirport(
                icaoCode: normalizedCode,
                forceRefresh: true
            )
            guard let coordinate = airport.coordinate else {
                throw AviationWeatherAirportLookupError.missingCoordinates(airport.icaoId)
            }

            airportSearchQuery = airport.icaoId
            activeAirport = airport
            await loadSearchMETARs(
                for: airport,
                coordinate: coordinate,
                forceRefresh: true
            )
        } catch {
            searchErrorMessage = error.localizedDescription
        }
    }

    private func handleAirportSearchQueryChange(_ newValue: String) {
        if searchErrorMessage != nil {
            searchErrorMessage = nil
        }

        if newValue.isEmpty {
            clearAirportSearch()
        }
    }

    private func clearAirportResults() {
        activeAirport = nil
        searchedMETARService.clearCache(keepDisplayedMETARs: false)
    }

    private func clearAirportSearch() {
        airportSearchQuery = ""
        searchErrorMessage = nil
        clearAirportResults()
    }
}

struct AirportWeatherSearchCard: View {
    @Binding var airportCode: String

    let activeAirport: AviationWeatherAirportInfo?
    let isSearching: Bool
    let errorMessage: String?
    let onSearch: () -> Void
    let onClear: () -> Void

    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Label("Search Airport", systemImage: "magnifyingglass")
                    .font(.headline)
                Spacer()
                if activeAirport != nil {
                    Button("Clear Search", action: onClear)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                }
            }

            Text("Enter a 4-letter ICAO code to compare another airport without replacing the nearby reports based on your current location.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                TextField("4-letter ICAO (e.g. KJFK)", text: $airportCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .keyboardType(.asciiCapable)
                    .submitLabel(.search)
                    .focused($isSearchFieldFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onSubmit {
                        isSearchFieldFocused = false
                        onSearch()
                    }

                Button {
                    isSearchFieldFocused = false
                    onSearch()
                } label: {
                    if isSearching {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Search")
                            .fontWeight(.semibold)
                            .frame(minWidth: 72)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSearching || airportCode.count != 4)
            }

            if let activeAirport {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                        Text("Showing results for \(activeAirport.icaoId)")
                            .font(.caption.weight(.semibold))
                        Spacer()
                    }

                    Text(activeAirport.displayName)
                        .font(.subheadline.weight(.semibold))

                    Text("This section stays pinned above the nearby reports, and distances are measured from this airport.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text("Nearby reports stay tied to your current location. Search adds a separate section around the airport you enter.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.blue.opacity(activeAirport == nil ? 0.08 : 0.16), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
