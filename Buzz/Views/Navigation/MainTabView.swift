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
    
    var body: some View {
        if authService.userProfile?.userType == .pilot {
            PilotTabView()
        } else {
            CustomerTabView()
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
                    Label("Profile", systemImage: "person.fill")
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
                    Label("Activity", systemImage: "clock.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
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
                            ForEach(bookingService.myBookings.filter { $0.status == .completed }) { booking in
                                NavigationLink(destination: BookingDetailView(booking: booking)) {
                                    MyFlightsBookingCard(booking: booking)
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

