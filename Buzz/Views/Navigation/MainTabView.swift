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
                    Label("Jobs", systemImage: "airplane.departure")
                }
            
            MyFlightsView()
                .tabItem {
                    Label("My Flights", systemImage: "list.bullet")
                }
            
            LeaderboardView()
                .tabItem {
                    Label("Rankings", systemImage: "chart.bar.fill")
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
                    Label("Bookings", systemImage: "doc.text.fill")
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
                                    BookingCard(booking: booking)
                                }
                            }
                        }
                        
                        Section("Completed") {
                            ForEach(bookingService.myBookings.filter { $0.status == .completed }) { booking in
                                NavigationLink(destination: BookingDetailView(booking: booking)) {
                                    BookingCard(booking: booking)
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

