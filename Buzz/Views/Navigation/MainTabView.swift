//
//  MainTabView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import Auth

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()
    @State private var notificationToHandle: [AnyHashable: Any]?
    
    var body: some View {
        if authService.userProfile?.userType == .pilot {
            PilotTabView()
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HandleNotificationTap"))) { notification in
                    if let userInfo = notification.userInfo {
                        handleNotificationTap(userInfo: userInfo)
                    }
                }
        } else {
            CustomerTabView()
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HandleNotificationTap"))) { notification in
                    if let userInfo = notification.userInfo {
                        handleNotificationTap(userInfo: userInfo)
                    }
                }
        }
    }
    
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }
        
        // Handle different notification types
        switch type {
        case "booking_accepted", "booking_reminder":
            // Navigate to bookings tab
            // For customer: go to Home tab
            // For pilot: go to My Flights tab
            print("Navigating to booking: \(userInfo)")
            
        case "new_message":
            // Navigate to messages (booking detail)
            print("Navigating to message: \(userInfo)")
            
        case "nearby_booking":
            // Navigate to Jobs tab for pilot
            print("Navigating to nearby booking: \(userInfo)")
            
        case "drone_activity":
            // Navigate to Flight Radar
            print("Navigating to Flight Radar for drone activity")
            
        case "weather_change":
            // Navigate to Weather view
            print("Navigating to Weather view")
            
        case "received_review":
            // Navigate to ratings/profile
            print("Navigating to ratings")
            
        default:
            print("Unknown notification type: \(type)")
        }
    }
}

// MARK: - Pilot Tab View

struct PilotTabView: View {
    var body: some View {
        TabView {
            PilotBookingListView()
                .tabItem {
                    Label("Jobs", systemImage: "drone.fill")
                }
            
            MyFlightsView()
                .tabItem {
                    Label("My Flights", systemImage: "list.bullet")
                }
            
            CockpitView()
                .tabItem {
                    Label("Cockpit", systemImage: "airplane.circle.fill")
                }
            
            AcademyView()
                .tabItem {
                    Label("Academy", systemImage: "book.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Account", systemImage: "person.fill")
                }
        }
    }
}

// MARK: - Customer Tab View

struct CustomerTabView: View {
    var body: some View {
        TabView {
            CustomerBookingView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            CustomerActivityView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Account", systemImage: "person.fill")
                }
        }
    }
}

// MARK: - My Flights View (Pilot's Accepted/Completed Bookings)

struct MyFlightsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    
    var body: some View {
        NavigationView {
            VStack {
                if bookingService.isLoading {
                    LoadingView(message: "Loading your flights...")
                } else if bookingService.myBookings.isEmpty {
                    EmptyStateView(
                        icon: "airplane",
                        title: "No Flights Yet",
                        message: "Accept bookings to see them here"
                    )
                } else {
                    List {
                        Section("Active") {
                            ForEach(bookingService.myBookings.filter { $0.status == .accepted }) { booking in
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
        .task {
            await loadBookings()
        }
    }
    
    private func loadBookings() async {
        guard let currentUser = authService.currentUser else { return }
        try? await bookingService.fetchMyBookings(userId: currentUser.id, isPilot: true)
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
                }
                
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

