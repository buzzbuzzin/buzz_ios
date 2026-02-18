//
//  MeetupLocationView.swift
//  Buzz
//
//  Created for Marketplace feature
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

extension MKMapItem: @retroactive Identifiable {
    public var id: String {
        "\(placemark.coordinate.latitude),\(placemark.coordinate.longitude),\(name ?? "")"
    }
}

struct MeetupLocationView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    var onLocationSelected: (String, Double, Double) -> Void

    // Default to Ithaca, NY; will be replaced by user location if available
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 42.4434, longitude: -76.5017),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var policeStations: [MKMapItem] = []
    @State private var isSearching = false
    @State private var selectedStation: MKMapItem?
    @StateObject private var locationHelper = MeetupLocationHelper()

    var body: some View {
        VStack(spacing: 0) {
            // Safety banner
            HStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.blue)
                Text("For your safety, we recommend meeting at a police station")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))

            // Map
            Map(coordinateRegion: $region, annotationItems: policeStations, annotationContent: { station in
                MapAnnotation(coordinate: station.placemark.coordinate) {
                    VStack(spacing: 2) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 20))
                            .foregroundColor(selectedStation?.placemark.coordinate.latitude == station.placemark.coordinate.latitude ? .orange : .blue)

                        if selectedStation?.placemark.coordinate.latitude == station.placemark.coordinate.latitude {
                            Text(station.name ?? "Station")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial)
                                .cornerRadius(4)
                        }
                    }
                    .onTapGesture {
                        selectedStation = station
                    }
                }
            })
            .frame(height: 250)

            // Station list
            if isSearching {
                ProgressView("Finding nearby police stations...")
                    .padding()
            } else if policeStations.isEmpty {
                VStack(spacing: 8) {
                    Text("No police stations found nearby")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Search Again") { searchPoliceStations() }
                        .foregroundColor(.orange)
                }
                .padding()
            } else {
                List {
                    ForEach(policeStations, id: \.self) { station in
                        Button {
                            selectedStation = station
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "shield.fill")
                                    .foregroundColor(selectedStation == station ? .orange : .blue)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(station.name ?? "Police Station")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)

                                    if let address = station.placemark.thoroughfare {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    if let city = station.placemark.locality,
                                       let state = station.placemark.administrativeArea {
                                        Text("\(city), \(state)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if selectedStation == station {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }

            // Select button
            if let station = selectedStation {
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        let name = station.name ?? "Police Station"
                        let lat = station.placemark.coordinate.latitude
                        let lng = station.placemark.coordinate.longitude
                        onLocationSelected(name, lat, lng)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "shield.checkered")
                            Text("Select \(station.name ?? "This Location")")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange)
                        .cornerRadius(12)
                    }
                    .padding()
                }
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Safe Meetup Location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
        .task {
            if let userLocation = locationHelper.userLocation {
                region = MKCoordinateRegion(
                    center: userLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                )
            }
            searchPoliceStations()
        }
        .onReceive(locationHelper.$userLocation) { newLocation in
            guard let location = newLocation else { return }
            region = MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
            searchPoliceStations()
        }
    }

    private func searchPoliceStations() {
        isSearching = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "police station"
        request.region = region

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                if let response = response {
                    policeStations = response.mapItems
                    if let first = policeStations.first {
                        selectedStation = first
                    }
                }
            }
        }
    }
}

// MARK: - Location Helper

class MeetupLocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            DispatchQueue.main.async {
                self.userLocation = location.coordinate
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Fall back to default hardcoded location
    }
}
