//
//  MainTabView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import Auth
import CoreLocation

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var deepLinkManager = DeepLinkManager.shared

    var body: some View {
        Group {
            if authService.userProfile?.userType == .pilot {
                PilotTabView()
            } else {
                CustomerTabView()
            }
        }
        .environmentObject(deepLinkManager)
    }
}

// MARK: - Pilot Tab View

struct PilotTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @AppStorage(MissionDistancePreference.storageKey)
    private var missionDistanceMiles: Double = MissionDistancePreference.defaultMiles
    @StateObject private var bookingService = BookingService()
    @StateObject private var locationManager = BookingMapLocationManager()
    @StateObject private var beaconService = BeaconService()
    @StateObject private var verificationGate = VerificationGate()
    @State private var hasNearbyBeaconMissions = false
    @State private var selectedTab = 0
    @State private var showConversations = false
    @State private var deepLinkConversationId: UUID?
    @State private var deepLinkedBooking: Booking?
    @State private var deepLinkErrorMessage: String?
    @State private var showDeepLinkError = false
    @State private var showVerificationSheet = false

    var body: some View {
        TabView(selection: $selectedTab) {
            gated("Missions") { PilotBookingListView() }
                .tabItem {
                    Label("Missions", systemImage: "drone.fill")
                }
                .tag(0)

            gated("My Flights") { MyFlightsView() }
                .tabItem {
                    Label("My Flights", systemImage: "list.bullet")
                }
                .tag(1)

            gated("Cockpit") { CockpitView() }
                .tabItem {
                    Label("Cockpit", systemImage: "airplane.circle.fill")
                }
                .tag(2)
                .badge(hasNearbyBeaconMissions ? 1 : 0)

            gated("Academy") { AcademyView() }
                .tabItem {
                    Label("Academy", systemImage: "book.fill")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Label("Account", systemImage: "person.fill")
                }
                .tag(4)
        }
        .task(id: authService.activeUserId) {
            await verificationGate.refresh(userId: authService.activeUserId)
        }
        .sheet(isPresented: $showVerificationSheet, onDismiss: {
            Task {
                await verificationGate.refresh(userId: authService.activeUserId)
                handlePendingDeepLinkIfNeeded()
            }
        }) {
            NavigationStack { GovernmentIDView() }
                .environmentObject(authService)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await verificationGate.refresh(userId: authService.activeUserId) }
        }
        .onAppear {
            handlePendingDeepLinkIfNeeded()
        }
        .onChange(of: deepLinkManager.pendingDestination) { _, destination in
            guard let destination = destination else { return }
            handleDeepLinkDestination(destination)
        }
        .onChange(of: verificationGate.state) { _, newState in
            if newState == .verified {
                handlePendingDeepLinkIfNeeded()
            }
        }
        .sheet(isPresented: $showConversations, onDismiss: {
            deepLinkConversationId = nil
        }) {
            ConversationsListView(deepLinkConversationId: deepLinkConversationId)
                .environmentObject(authService)
        }
        .sheet(item: $deepLinkedBooking) { booking in
            NavigationStack {
                BookingDetailView(booking: booking)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                deepLinkedBooking = nil
                            }
                        }
                    }
            }
        }
        .task {
            locationManager.requestPermission()
            locationManager.startLocationUpdates()
            if let userId = authService.activeUserId {
                _ = try? await beaconService.getVolunteerStatus(userId: userId)
            }
            await checkForNearbyBeaconMissions()
        }
        .onDisappear {
            locationManager.stopLocationUpdates()
        }
        .onChange(of: bookingService.availableBookings.count) { _, _ in
            Task {
                await checkForNearbyBeaconMissions()
            }
        }
        .onChange(of: missionDistanceMiles) { _, _ in
            Task {
                await checkForNearbyBeaconMissions()
            }
        }
        .alert("Unable to Open Booking", isPresented: $showDeepLinkError) {
            Button("OK", role: .cancel) {
                deepLinkErrorMessage = nil
            }
        } message: {
            Text(deepLinkErrorMessage ?? "The booking could not be loaded.")
        }
    }
    
    @ViewBuilder
    private func gated<Content: View>(_ tabTitle: String,
                                       @ViewBuilder content: () -> Content) -> some View {
        switch verificationGate.state {
        case .verified:
            content()
        case .unverified:
            VerificationLockView(tabTitle: tabTitle) {
                showVerificationSheet = true
            }
        case .loading:
            LoadingView(message: "Checking verification…")
        }
    }

    private func checkForNearbyBeaconMissions() async {
        // Only show beacon notifications for enrolled and available volunteers
        guard authService.userProfile?.isBeaconVolunteer == true,
              beaconService.volunteerStatus?.isAvailable == true else {
            hasNearbyBeaconMissions = false
            return
        }

        guard let pilotId = authService.activeUserId else { return }

        // Load available bookings first
        try? await bookingService.fetchAvailableBookings(forPilotId: pilotId)

        // Get bookings the pilot already joined so we can exclude them
        let joinedBookingIds = Set(
            (try? await bookingService.fetchPilotCrewMemberships(pilotId: pilotId))?.map(\.bookingId) ?? []
        )

        // Check for beacon missions (S&R bookings with usesBeaconProgram == true)
        let beaconMissions = bookingService.availableBookings.filter { booking in
            booking.specialization == .searchRescue &&
            booking.usesBeaconProgram == true &&
            booking.status == .available &&
            !joinedBookingIds.contains(booking.id)
        }

        // Filter by proximity if location is available
        if let pilotLocation = locationManager.currentLocation {
            let pilotCLLocation = CLLocation(latitude: pilotLocation.latitude, longitude: pilotLocation.longitude)
            let radiusMeters = missionDistanceMiles * 1609.34

            let nearbyBeaconMissions = beaconMissions.filter { booking in
                let bookingLocation = CLLocation(latitude: booking.locationLat, longitude: booking.locationLng)
                let distance = pilotCLLocation.distance(from: bookingLocation)
                return distance <= radiusMeters
            }

            await MainActor.run {
                hasNearbyBeaconMissions = !nearbyBeaconMissions.isEmpty
            }
        } else {
            // If location not available, show badge if any beacon missions exist
            await MainActor.run {
                hasNearbyBeaconMissions = !beaconMissions.isEmpty
            }
        }
    }

    private func handlePendingDeepLinkIfNeeded() {
        guard let destination = deepLinkManager.pendingDestination else { return }
        handleDeepLinkDestination(destination)
    }

    private func handleDeepLinkDestination(_ destination: DeepLinkDestination) {
        // Profile/Account is never gated — handle it up front.
        switch destination {
        case .profile:
            selectedTab = 4
            deepLinkManager.pendingDestination = nil
            return
        case .licenseManagement:
            selectedTab = 4
            return
        default:
            break
        }

        // Everything else requires a verified identity. Keep the destination
        // pending and prompt for verification; once verified, state change
        // will re-invoke handlePendingDeepLinkIfNeeded().
        guard verificationGate.state == .verified else {
            showVerificationSheet = true
            return
        }

        switch destination {
        case .jobs:
            selectedTab = 0
            deepLinkManager.pendingDestination = nil
        case .bookingDetail(let bookingId):
            selectedTab = 1
            openPilotBookingDetail(bookingId: bookingId)
        case .weather, .flightRadar, .hangerTalkPost, .hangerTalkProfile, .hangerTalkInbox, .hangerTalkSpace, .marketplace:
            // These live inside CockpitView fullScreenCovers — switch to Cockpit tab
            // and let CockpitView handle the rest
            selectedTab = 2
        case .messages(let conversationId):
            // Open conversations list and target the specific conversation when possible
            selectedTab = 0
            deepLinkConversationId = conversationId
            showConversations = true
            deepLinkManager.pendingDestination = nil
        case .profile, .licenseManagement:
            break // handled above
        }
    }

    private func openPilotBookingDetail(bookingId: UUID) {
        Task { @MainActor in
            let detailService = BookingService()
            do {
                deepLinkedBooking = try await detailService.fetchBooking(id: bookingId)
            } catch {
                deepLinkErrorMessage = error.localizedDescription
                showDeepLinkError = true
            }
            deepLinkManager.pendingDestination = nil
        }
    }
}

// MARK: - Customer Tab View

struct CustomerTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @StateObject private var verificationGate = VerificationGate()
    @State private var selectedTab = 0
    @State private var showConversations = false
    @State private var deepLinkConversationId: UUID?
    @State private var deepLinkedBooking: Booking?
    @State private var deepLinkErrorMessage: String?
    @State private var showDeepLinkError = false
    @State private var showVerificationSheet = false

    var body: some View {
        TabView(selection: $selectedTab) {
            gated("Home") { CustomerBookingView() }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            gated("History") { CustomerActivityView() }
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Label("Account", systemImage: "person.fill")
                }
                .tag(2)
        }
        .task(id: authService.activeUserId) {
            await verificationGate.refresh(userId: authService.activeUserId)
        }
        .sheet(isPresented: $showVerificationSheet, onDismiss: {
            Task {
                await verificationGate.refresh(userId: authService.activeUserId)
                handlePendingDeepLinkIfNeeded()
            }
        }) {
            NavigationStack { GovernmentIDView() }
                .environmentObject(authService)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await verificationGate.refresh(userId: authService.activeUserId) }
        }
        .onAppear {
            handlePendingDeepLinkIfNeeded()
        }
        .onChange(of: deepLinkManager.pendingDestination) { _, destination in
            guard let destination = destination else { return }
            handleDeepLinkDestination(destination)
        }
        .onChange(of: verificationGate.state) { _, newState in
            if newState == .verified {
                handlePendingDeepLinkIfNeeded()
            }
        }
        .sheet(isPresented: $showConversations, onDismiss: {
            deepLinkConversationId = nil
        }) {
            ConversationsListView(deepLinkConversationId: deepLinkConversationId)
                .environmentObject(authService)
        }
        .sheet(item: $deepLinkedBooking) { booking in
            NavigationStack {
                CustomerBookingDetailView(booking: booking)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                deepLinkedBooking = nil
                            }
                        }
                    }
            }
        }
        .alert("Unable to Open Booking", isPresented: $showDeepLinkError) {
            Button("OK", role: .cancel) {
                deepLinkErrorMessage = nil
            }
        } message: {
            Text(deepLinkErrorMessage ?? "The booking could not be loaded.")
        }
    }

    @ViewBuilder
    private func gated<Content: View>(_ tabTitle: String,
                                       @ViewBuilder content: () -> Content) -> some View {
        switch verificationGate.state {
        case .verified:
            content()
        case .unverified:
            VerificationLockView(tabTitle: tabTitle) {
                showVerificationSheet = true
            }
        case .loading:
            LoadingView(message: "Checking verification…")
        }
    }

    private func handlePendingDeepLinkIfNeeded() {
        guard let destination = deepLinkManager.pendingDestination else { return }
        handleDeepLinkDestination(destination)
    }

    private func handleDeepLinkDestination(_ destination: DeepLinkDestination) {
        // Profile/Account is never gated — handle it up front.
        if case .profile = destination {
            selectedTab = 2
            deepLinkManager.pendingDestination = nil
            return
        }

        // Gated destinations — hold the link and prompt for verification.
        guard verificationGate.state == .verified else {
            showVerificationSheet = true
            return
        }

        switch destination {
        case .bookingDetail(let bookingId):
            selectedTab = 0
            openCustomerBookingDetail(bookingId: bookingId)
        case .messages(let conversationId):
            selectedTab = 0
            deepLinkConversationId = conversationId
            showConversations = true
            deepLinkManager.pendingDestination = nil
        case .profile:
            break // handled above
        default:
            // If user type is still loading, keep the destination for the eventual correct tab host.
            if authService.userProfile?.userType == .customer {
                deepLinkManager.pendingDestination = nil
            }
        }
    }

    private func openCustomerBookingDetail(bookingId: UUID) {
        Task { @MainActor in
            let detailService = BookingService()
            do {
                deepLinkedBooking = try await detailService.fetchBooking(id: bookingId)
            } catch {
                deepLinkErrorMessage = error.localizedDescription
                showDeepLinkError = true
            }
            deepLinkManager.pendingDestination = nil
        }
    }
}

// MARK: - My Flights View (Pilot's Accepted/Completed Bookings)

struct MyFlightsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()

    private var isAwaitingAuth: Bool {
        authService.activeUserId == nil && !authService.hasResolvedInitialSession
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if bookingService.isLoading || isAwaitingAuth {
                    LoadingView(message: "Loading your flights...")
                } else if bookingService.myBookings.isEmpty {
                    EmptyStateView(
                        icon: "airplane",
                        title: "No Flights Yet",
                        message: "Accept missions to see them here"
                    )
                } else {
                    List {
                        let activeBookings = bookingService.myBookings.filter { booking in
                            booking.status == .accepted ||
                            booking.status == .staffed ||
                            booking.status == .inProgress ||
                            (booking.isCrewBooking && booking.status == .available)
                        }
                        
                        Section("Active") {
                            ForEach(activeBookings) { booking in
                                NavigationLink(destination: BookingDetailView(booking: booking)) {
                                    MyFlightsBookingCard(booking: booking)
                                }
                            }
                        }
                        
                        Section("Completed") {
                            ForEach(bookingService.myBookings.filter { $0.status == .completed }.sorted(by: { booking1, booking2 in
                                // Sort by completedAt if available, otherwise createdAt
                                let date1 = booking1.completedAt ?? booking1.createdAt
                                let date2 = booking2.completedAt ?? booking2.createdAt
                                return date1 > date2
                            })) { booking in
                                NavigationLink(destination: BookingDetailView(booking: booking)) {
                                    CompletedBookingCard(booking: booking)
                                }
                            }
                        }
                    }
                    .refreshable {
                        await loadBookings()
                    }
                }
            }
            .navigationTitle("My Flights")
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
        guard let currentUserId = authService.activeUserId else { return }
        try? await bookingService.fetchMyBookings(userId: currentUserId, isPilot: true)
    }
}

// MARK: - My Flights Booking Card

struct MyFlightsBookingCard: View {
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
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bookingAccessibilityLabel)
        .task {
            await loadCustomerProfile()
        }
    }

    private var bookingAccessibilityLabel: String {
        var parts = [booking.locationName]
        if let specialization = booking.specialization {
            parts.append(specialization.displayName)
        }
        if booking.specialization == .searchRescue && booking.isVoluntary == true {
            parts.append("Voluntary")
        } else {
            parts.append(String(format: "$%.2f", NSDecimalNumber(decimal: booking.paymentAmount).doubleValue))
        }
        if let hours = booking.estimatedFlightHours {
            parts.append(String(format: "%.1f hours", hours))
        }
        return parts.joined(separator: ", ")
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
