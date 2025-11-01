//
//  PilotBookingListView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI

struct PilotBookingListView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    @State private var selectedBooking: Booking?
    @State private var showMapView = false
    
    var body: some View {
        NavigationView {
            VStack {
                if bookingService.isLoading {
                    LoadingView(message: "Loading bookings...")
                } else if bookingService.availableBookings.isEmpty {
                    EmptyStateView(
                        icon: "airplane.departure",
                        title: "No Available Bookings",
                        message: "Check back later for new drone pilot opportunities"
                    )
                } else {
                    List {
                        ForEach(bookingService.availableBookings) { booking in
                            NavigationLink(destination: BookingDetailView(booking: booking)) {
                                BookingCard(booking: booking)
                            }
                        }
                    }
                    .refreshable {
                        await loadBookings()
                    }
                }
            }
            .navigationTitle("Available Jobs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showMapView = true
                    } label: {
                        Image(systemName: "map")
                    }
                }
            }
            .sheet(isPresented: $showMapView) {
                NavigationView {
                    BookingMapView(
                        bookings: bookingService.availableBookings,
                        selectedBooking: $selectedBooking
                    )
                    .navigationTitle("Map View")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showMapView = false
                            }
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        if let booking = selectedBooking {
                            BookingMapCard(booking: booking)
                                .padding()
                        }
                    }
                }
            }
        }
        .task {
            await loadBookings()
        }
    }
    
    private func loadBookings() async {
        try? await bookingService.fetchAvailableBookings()
    }
}

// MARK: - Booking Card

struct BookingCard: View {
    let booking: Booking
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.red)
                Text(booking.locationName)
                    .font(.headline)
                Spacer()
            }
            
            Text(booking.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Label(
                    String(format: "$%.2f", NSDecimalNumber(decimal: booking.paymentAmount).doubleValue),
                    systemImage: "dollarsign.circle.fill"
                )
                .font(.subheadline)
                .foregroundColor(.green)
                
                Spacer()
                
                if let hours = booking.estimatedFlightHours {
                    Label(
                        String(format: "%.1f hrs", hours),
                        systemImage: "clock.fill"
                    )
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            
            Text("Posted \(booking.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Booking Map Card (Bottom Sheet)

struct BookingMapCard: View {
    let booking: Booking
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.locationName)
                        .font(.headline)
                    Text(booking.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                NavigationLink(destination: BookingDetailView(booking: booking)) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
            }
            
            HStack {
                Label(
                    String(format: "$%.2f", NSDecimalNumber(decimal: booking.paymentAmount).doubleValue),
                    systemImage: "dollarsign.circle.fill"
                )
                .foregroundColor(.green)
                
                if let hours = booking.estimatedFlightHours {
                    Label(
                        String(format: "%.1f hrs", hours),
                        systemImage: "clock.fill"
                    )
                    .foregroundColor(.blue)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}

