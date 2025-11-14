//
//  PilotBookingListView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import CoreLocation
import Combine

struct PilotBookingListView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    @StateObject private var locationManager = BookingMapLocationManager()
    @State private var selectedBooking: Booking?
    @State private var showMapView = false
    @State private var showConversations = false
    @State private var selectedCategory: BookingSpecialization? = nil
    @State private var radiusMiles: Double = 25.0 // Default 25 miles
    @State private var isRadiusExpanded = false // Collapse/expand radius filter
    
    // Radius options: 5, 25, 50, 100, 200 miles
    private let radiusOptions: [Double] = [5, 25, 50, 100, 200]
    private let maxRadius: Double = 200
    
    var filteredBookings: [Booking] {
        var bookings = bookingService.availableBookings
        
        // Filter by category
        if let category = selectedCategory {
            bookings = bookings.filter { $0.specialization == category }
        }
        
        // Filter by radius if location is available
        if let pilotLocation = locationManager.currentLocation {
            let pilotCLLocation = CLLocation(latitude: pilotLocation.latitude, longitude: pilotLocation.longitude)
            let radiusMeters = radiusMiles * 1609.34 // Convert miles to meters
            
            bookings = bookings.filter { booking in
                let bookingLocation = CLLocation(latitude: booking.locationLat, longitude: booking.locationLng)
                let distance = pilotCLLocation.distance(from: bookingLocation)
                return distance <= radiusMeters
            }
        }
        
        return bookings
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // All Categories button
                        Button(action: {
                            selectedCategory = nil
                        }) {
                            Text("All")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedCategory == nil ? Color.blue : Color(.systemGray5))
                                .foregroundColor(selectedCategory == nil ? .white : .primary)
                                .cornerRadius(20)
                        }
                        
                        // Category buttons
                        ForEach(BookingSpecialization.allCases, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                Label(category.displayName, systemImage: category.icon)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == category ? Color.blue : Color(.systemGray5))
                                    .foregroundColor(selectedCategory == category ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))
                
                Divider()
                
                // Radius Filter
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        
                        Text("Search Radius")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(String(format: "%.0f mi", radiusMiles))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .frame(minWidth: 50)
                        
                        // Collapse/Expand button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isRadiusExpanded.toggle()
                            }
                        }) {
                            Image(systemName: isRadiusExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                                .padding(4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    if isRadiusExpanded {
                        VStack(spacing: 4) {
                            // Slider
                            Slider(value: $radiusMiles, in: 1...maxRadius, step: 1)
                                .tint(.blue)
                                .padding(.horizontal)
                            
                            // Quick selection buttons
                            HStack(spacing: 8) {
                                ForEach(radiusOptions, id: \.self) { radius in
                                    Button(action: {
                                        withAnimation {
                                            radiusMiles = radius
                                        }
                                    }) {
                                        Text("\(Int(radius))")
                                            .font(.caption)
                                            .fontWeight(radiusMiles == radius ? .bold : .regular)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            .background(radiusMiles == radius ? Color.blue : Color(.systemGray5))
                                            .foregroundColor(radiusMiles == radius ? .white : .primary)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .background(Color(.systemBackground))
                
                Divider()
                
                // Bookings List
                if bookingService.isLoading {
                    LoadingView(message: "Loading bookings...")
                } else if filteredBookings.isEmpty {
                    EmptyStateView(
                        icon: "airplane.departure",
                        title: selectedCategory == nil ? "No Available Bookings" : "No \(selectedCategory?.displayName ?? "") Jobs",
                        message: selectedCategory == nil ? "Check back later for new drone pilot opportunities" : "Try selecting a different category"
                    )
                } else {
                    List {
                        ForEach(filteredBookings) { booking in
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showConversations = true
                    } label: {
                        Image(systemName: "message.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showMapView = true
                    } label: {
                        Image(systemName: "map")
                    }
                }
            }
            .sheet(isPresented: $showConversations) {
                ConversationsListView()
            }
            .sheet(isPresented: $showMapView) {
                NavigationView {
                    BookingMapView(
                        bookings: filteredBookings,
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
            locationManager.requestPermission()
            locationManager.startLocationUpdates()
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
    @StateObject private var profileService = ProfileService()
    @State private var customerProfile: UserProfile?
    
    var body: some View {
        HStack(spacing: 12) {
            // Customer Profile Picture
            Group {
                if let profile = customerProfile,
                   let pictureUrl = profile.profilePictureUrl,
                   let url = URL(string: pictureUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 50, height: 50)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        case .failure:
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                }
            }
            .frame(width: 50, height: 50)
            
            // Booking Info
            VStack(alignment: .leading, spacing: 12) {
                // Title
                Text(booking.locationName)
                    .font(.headline)
                
                // Category badge below title
                if let specialization = booking.specialization {
                    Label(specialization.displayName, systemImage: specialization.icon)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
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
        }
        .padding(.vertical, 8)
        .task {
            await loadCustomerProfile()
        }
    }
    
    private func loadCustomerProfile() async {
        // Try to get sample customer profile first (for demo)
        if let sampleProfile = profileService.getSampleCustomerProfile(customerId: booking.customerId) {
            customerProfile = sampleProfile
        } else {
            // Fallback to real profile fetch
            do {
                customerProfile = try await profileService.getProfile(userId: booking.customerId)
            } catch {
                print("Error loading customer profile: \(error)")
            }
        }
    }
}

// MARK: - Booking Map Card (Bottom Sheet)

struct BookingMapCard: View {
    let booking: Booking
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(booking.locationName)
                        .font(.headline)
                    
                    // Category badge below title
                    if let specialization = booking.specialization {
                        Label(specialization.displayName, systemImage: specialization.icon)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                    }
                    
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

