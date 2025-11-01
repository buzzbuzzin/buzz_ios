//
//  CustomerActivityView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct CustomerActivityView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    
    var body: some View {
        NavigationView {
            VStack {
                if bookingService.isLoading {
                    LoadingView(message: "Loading booking history...")
                } else {
                    let completedBookings = bookingService.myBookings.filter { $0.status == .completed || $0.status == .cancelled }
                    let activeBookings = bookingService.myBookings.filter { $0.status == .accepted }
                    
                    if bookingService.myBookings.isEmpty {
                        EmptyStateView(
                            icon: "clock.arrow.circlepath",
                            title: "No Activity Yet",
                            message: "Your booking history will appear here"
                        )
                    } else {
                        List {
                            // Active Bookings
                            if !activeBookings.isEmpty {
                                Section("Active") {
                                    ForEach(activeBookings) { booking in
                                        NavigationLink(destination: CustomerBookingDetailView(booking: booking)) {
                                            CustomerBookingCard(booking: booking)
                                        }
                                    }
                                }
                            }
                            
                            // Completed Bookings
                            if !completedBookings.isEmpty {
                                Section("History") {
                                    ForEach(completedBookings.sorted(by: { $0.createdAt > $1.createdAt })) { booking in
                                        NavigationLink(destination: CustomerBookingDetailView(booking: booking)) {
                                            CustomerBookingCard(booking: booking)
                                        }
                                    }
                                }
                            }
                        }
                        .refreshable {
                            await loadBookings()
                        }
                    }
                }
            }
            .navigationTitle("Activity")
        }
        .task {
            await loadBookings()
        }
    }
    
    private func loadBookings() async {
        guard let currentUser = authService.currentUser else { return }
        try? await bookingService.fetchMyBookings(userId: currentUser.id, isPilot: false)
    }
}

