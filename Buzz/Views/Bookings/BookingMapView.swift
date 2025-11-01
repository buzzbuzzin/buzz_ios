//
//  BookingMapView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import MapKit

struct BookingMapView: View {
    let bookings: [Booking]
    @Binding var selectedBooking: Booking?
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    
    var body: some View {
        Map(coordinateRegion: $region, annotationItems: bookings) { booking in
            MapAnnotation(coordinate: booking.coordinate) {
                BookingAnnotation(booking: booking, isSelected: selectedBooking?.id == booking.id)
                    .onTapGesture {
                        selectedBooking = booking
                    }
            }
        }
        .onAppear {
            if let firstBooking = bookings.first {
                region.center = firstBooking.coordinate
            }
        }
    }
}

struct BookingAnnotation: View {
    let booking: Booking
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : Color.red)
                    .frame(width: 40, height: 40)
                    .shadow(radius: 4)
                
                Image(systemName: "airplane")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
            
            Image(systemName: "triangle.fill")
                .foregroundColor(isSelected ? .blue : .red)
                .font(.system(size: 10))
                .offset(y: -5)
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Location Picker Map

struct LocationPickerMap: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var locationName: String
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, interactionModes: .all, showsUserLocation: true)
                .onTapGesture(perform: handleMapTap)
            
            // Pin in center
            if selectedLocation != nil {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                    .offset(y: -20)
            }
        }
        .onChange(of: selectedLocation?.latitude) { _, _ in
            updateLocation()
        }
        .onChange(of: selectedLocation?.longitude) { _, _ in
            updateLocation()
        }
    }
    
    private func updateLocation() {
        if let location = selectedLocation {
            region.center = location
            reverseGeocode(location)
        }
    }
    
    private func handleMapTap(at point: CGPoint) {
        let coordinate = region.center
        selectedLocation = coordinate
    }
    
    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                var components: [String] = []
                if let name = placemark.name {
                    components.append(name)
                }
                if let locality = placemark.locality {
                    components.append(locality)
                }
                if let state = placemark.administrativeArea {
                    components.append(state)
                }
                locationName = components.joined(separator: ", ")
            }
        }
    }
}

