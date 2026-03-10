//
//  PilotBookingListView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import CoreLocation
import Combine
import Auth

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
    @State private var showExpressPromotionCard = true // Show promotion card
    
    // Radius options: 5, 25, 50, 100, 200 miles
    private let radiusOptions: [Double] = [5, 25, 50, 100, 200]
    private let maxRadius: Double = 200
    
    var filteredBookings: [Booking] {
        // Exclude expired bookings from available list
        var bookings = bookingService.availableBookings.filter { $0.status != .expired }

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

    /// Bookings that are in progress (active jobs for the current pilot)
    var inProgressBookings: [Booking] {
        bookingService.myBookings.filter { $0.status == .inProgress }
    }

    /// S&R bookings that are staffed and ready to start
    var staffedBookings: [Booking] {
        bookingService.myBookings.filter { $0.status == .staffed }
    }

    /// Crew bookings the pilot has joined, still filling crew slots
    var pendingCrewBookings: [Booking] {
        bookingService.myBookings.filter { $0.isCrewBooking && $0.status == .available }
    }

    private var isAwaitingAuth: Bool {
        authService.activeUserId == nil && !authService.hasResolvedInitialSession
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
                if bookingService.isLoading || isAwaitingAuth {
                    LoadingView(message: "Loading bookings...")
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Express Promotion Card (always show at top)
                            if showExpressPromotionCard {
                                ExpressPromotionCard(
                                    onDismiss: {
                                        withAnimation {
                                            showExpressPromotionCard = false
                                        }
                                    },
                                    onLearnMore: {
                                        // Navigate to Express Promotion view
                                        // This will be handled via NavigationLink in the card
                                    }
                                )
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }

                            // Active Jobs Section (in_progress bookings)
                            if !inProgressBookings.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Active Jobs", systemImage: "bolt.fill")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                        .padding(.horizontal)

                                    ForEach(inProgressBookings) { booking in
                                        NavigationLink(destination: BookingDetailView(booking: booking)) {
                                            BookingCard(booking: booking)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.orange, lineWidth: 2)
                                                )
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                .padding(.top, 4)

                                Divider()
                                    .padding(.horizontal)
                            }

                            // Staffed S&R Section
                            if !staffedBookings.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Staffed - Ready to Start", systemImage: "person.3.fill")
                                        .font(.headline)
                                        .foregroundColor(.cyan)
                                        .padding(.horizontal)

                                    ForEach(staffedBookings) { booking in
                                        NavigationLink(destination: BookingDetailView(booking: booking)) {
                                            HStack {
                                                BookingCard(booking: booking)
                                                Spacer()
                                                Text("Staffed")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.cyan)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.cyan.opacity(0.15))
                                                    .cornerRadius(6)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                .padding(.top, 4)

                                Divider()
                                    .padding(.horizontal)
                            }

                            // Pending Crew Section (joined but still recruiting)
                            if !pendingCrewBookings.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Pending Crew", systemImage: "person.badge.clock")
                                        .font(.headline)
                                        .foregroundColor(.yellow)
                                        .padding(.horizontal)

                                    ForEach(pendingCrewBookings) { booking in
                                        NavigationLink(destination: BookingDetailView(booking: booking)) {
                                            HStack {
                                                BookingCard(booking: booking)
                                                Spacer()
                                                Text("Joined")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.yellow)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.yellow.opacity(0.15))
                                                    .cornerRadius(6)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                .padding(.top, 4)

                                Divider()
                                    .padding(.horizontal)
                            }

                            // Available Bookings
                            if filteredBookings.isEmpty && inProgressBookings.isEmpty && staffedBookings.isEmpty && pendingCrewBookings.isEmpty {
                                EmptyStateView(
                                    icon: "airplane.departure",
                                    title: selectedCategory == nil ? "No Available Bookings" : "No \(selectedCategory?.displayName ?? "") Jobs",
                                    message: selectedCategory == nil ? "Check back later for new drone pilot opportunities" : "Try selecting a different category"
                                )
                                .padding(.top, 40)
                            } else if !filteredBookings.isEmpty {
                                if !inProgressBookings.isEmpty || !staffedBookings.isEmpty || !pendingCrewBookings.isEmpty {
                                    Text("Available Jobs")
                                        .font(.headline)
                                        .padding(.horizontal)
                                }

                                ForEach(filteredBookings) { booking in
                                    NavigationLink(destination: BookingDetailView(booking: booking)) {
                                        BookingCard(booking: booking)
                                    }
                                    .padding(.horizontal)
                                }
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
                
                if ProcessInfo.processInfo.arguments.contains("UI_TESTING") || ProcessInfo.processInfo.environment["UITEST_MODE"] == "1" {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Accept First") {
                            Task { await acceptFirstAvailableBookingForUITest() }
                        }
                        .accessibilityIdentifier("pilot.acceptFirstBookingButton")
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
        }
        .task(id: authService.activeUserId) {
            await loadBookings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .bookingDidChange)) { _ in
            Task {
                await loadBookings()
            }
        }
    }
    
    private func loadBookings() async {
        guard let pilotId = authService.activeUserId else { return }

        // Pass pilot ID to filter bookings based on eligibility (rank requirements)
        try? await bookingService.fetchAvailableBookings(forPilotId: pilotId)
        // Also fetch pilot's own bookings for in-progress and staffed sections
        try? await bookingService.fetchMyBookings(userId: pilotId, isPilot: true)
    }
    
    private func acceptFirstAvailableBookingForUITest() async {
        guard let first = bookingService.availableBookings.first,
              let pilotId = authService.activeUserId else { return }
        try? await bookingService.acceptBooking(bookingId: first.id, pilotId: pilotId)
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
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
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
                
                if let description = booking.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                HStack {
                    if booking.specialization == .searchRescue && booking.isVoluntary == true {
                        Label(
                            "Voluntary",
                            systemImage: "hand.raised.fill"
                        )
                        .font(.subheadline)
                        .foregroundColor(.green)
                    } else {
                        Label(
                            String(format: "$%.2f", NSDecimalNumber(decimal: booking.paymentAmount).doubleValue),
                            systemImage: "dollarsign.circle.fill"
                        )
                        .font(.subheadline)
                        .foregroundColor(.green)
                    }
                    
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
                
                if let scheduledDate = booking.scheduledDate {
                    Text("Start at \(formatStartTime(scheduledDate)) (\(formatZuluTime(scheduledDate)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
    
    private func formatStartTime(_ date: Date) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = timeFormatter.string(from: date)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        let dateString = dateFormatter.string(from: date)
        
        return "\(timeString), \(dateString)"
    }
    
    private func formatZuluTime(_ date: Date) -> String {
        let utcTimeZone = TimeZone(secondsFromGMT: 0)!
        let calendar = Calendar(identifier: .gregorian)
        let utcComponents = calendar.dateComponents(in: utcTimeZone, from: date)
        
        // Get UTC components
        let day = utcComponents.day ?? 0
        let hour = utcComponents.hour ?? 0
        let minute = utcComponents.minute ?? 0
        
        // Format as DDHHmmZ (e.g., 241231Z = 24th day, 12:31 UTC)
        return String(format: "%02d%02d%02dZ", day, hour, minute)
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
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
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
                    
                    if let description = booking.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Spacer()
                NavigationLink(destination: BookingDetailView(booking: booking)) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
            }
            
            HStack {
                if booking.specialization == .searchRescue && booking.isVoluntary == true {
                    Label(
                        "Voluntary",
                        systemImage: "hand.raised.fill"
                    )
                    .foregroundColor(.green)
                } else {
                    Label(
                        String(format: "$%.2f", NSDecimalNumber(decimal: booking.paymentAmount).doubleValue),
                        systemImage: "dollarsign.circle.fill"
                    )
                    .foregroundColor(.green)
                }
                
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

// MARK: - Express Promotion Card

struct ExpressPromotionCard: View {
    let onDismiss: () -> Void
    let onLearnMore: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.title3)
            }
            
            // Content with NavigationLink
            NavigationLink(destination: ExpressPromotionView()) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Express Promotion")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Fast-track your rank advancement with verified credentials")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Dismiss button
            Button(action: {
                onDismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}
