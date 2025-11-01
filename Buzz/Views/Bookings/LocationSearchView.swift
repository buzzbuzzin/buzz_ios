//
//  LocationSearchView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import MapKit

struct LocationSearchView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var locationName: String
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var mapCenterCoordinate: CLLocationCoordinate2D?
    @State private var isSearching = false
    @FocusState private var isSearchFocused: Bool
    
    private let searchCompleter = MKLocalSearchCompleter()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Map View
                Map(coordinateRegion: $region, interactionModes: .all, showsUserLocation: true)
                    .ignoresSafeArea(.all, edges: .bottom)
                    .onTapGesture {
                        // Dismiss keyboard when tapping map
                        isSearchFocused = false
                    }
                    .overlay(
                        // Center pin indicator
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                            .offset(y: -20)
                    )
                
                VStack(spacing: 0) {
                    // Search Bar
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            // Back button
                            Button(action: {
                                isPresented = false
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: 32, height: 32)
                                    .background(Color(.systemGray6))
                                    .clipShape(Circle())
                            }
                            
                            // Search field
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                
                                TextField("Search for an address", text: $searchText)
                                    .focused($isSearchFocused)
                                    .onChange(of: searchText) { _, newValue in
                                        performSearch(query: newValue)
                                    }
                                    .onSubmit {
                                        selectCurrentLocation()
                                    }
                                
                                if !searchText.isEmpty {
                                    Button(action: {
                                        searchText = ""
                                        searchResults = []
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                        
                        // Search Results
                        if !searchResults.isEmpty && isSearchFocused {
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(searchResults, id: \.self) { item in
                                        LocationResultRow(item: item) {
                                            selectLocation(item: item)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 300)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            .padding(.horizontal)
                        }
                    }
                    .background(Color(.systemBackground).opacity(0.95))
                    
                    Spacer()
                    
                    // Done Button
                    if mapCenterCoordinate != nil {
                        VStack {
                            Button(action: {
                                selectCurrentLocation()
                            }) {
                                Text("Done")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                setupLocationManager()
                isSearchFocused = true
                
                // Pre-populate search if location already selected
                if !locationName.isEmpty {
                    searchText = locationName
                }
            }
            .onChange(of: region.center.latitude) { _, _ in
                updateMapCenter()
            }
            .onChange(of: region.center.longitude) { _, _ in
                updateMapCenter()
            }
        }
    }
    
    private func setupLocationManager() {
        // Request location authorization if needed
        let manager = CLLocationManager()
        
        // Try to center on user's current location if available
        if let userLocation = manager.location?.coordinate {
            region.center = userLocation
            updateMapCenter()
        }
    }
    
    private func updateMapCenter() {
        mapCenterCoordinate = region.center
    }
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else { return }
            DispatchQueue.main.async {
                searchResults = response.mapItems
            }
        }
    }
    
    private func selectLocation(item: MKMapItem) {
        guard let coordinate = item.placemark.location?.coordinate else { return }
        
        region.center = coordinate
        selectedLocation = coordinate
        
        // Get address name
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(item.placemark.location!) { placemarks, error in
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    locationName = formatAddress(from: placemark)
                    searchText = locationName
                    isSearchFocused = false
                }
            }
        }
    }
    
    private func selectCurrentLocation() {
        guard let coordinate = mapCenterCoordinate else { return }
        
        selectedLocation = coordinate
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    locationName = formatAddress(from: placemark)
                    isPresented = false
                }
            } else {
                // If geocoding fails, just use coordinate
                DispatchQueue.main.async {
                    locationName = String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
                    isPresented = false
                }
            }
        }
    }
    
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let name = placemark.name {
            components.append(name)
        }
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        return components.joined(separator: ", ")
    }
}

// MARK: - Location Result Row

struct LocationResultRow: View {
    let item: MKMapItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: 4) {
                    if let name = item.name {
                        Text(name)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    
                    Text(formatAddress(item))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatAddress(_ item: MKMapItem) -> String {
        let placemark = item.placemark
        var components: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let subThoroughfare = placemark.subThoroughfare {
            components.insert(subThoroughfare, at: 0)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        return components.isEmpty ? "Unknown address" : components.joined(separator: ", ")
    }
}

