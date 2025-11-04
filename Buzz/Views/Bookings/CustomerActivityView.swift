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
                    // Only show completed bookings in Activity view
                    let completedBookings = bookingService.myBookings.filter { $0.status == .completed }
                    
                    if completedBookings.isEmpty {
                        EmptyStateView(
                            icon: "clock.arrow.circlepath",
                            title: "No Completed Bookings",
                            message: "Your completed booking history will appear here"
                        )
                    } else {
                        List {
                            Section("Completed") {
                                ForEach(completedBookings.sorted(by: { $0.createdAt > $1.createdAt })) { booking in
                                    NavigationLink(destination: CustomerBookingDetailView(booking: booking)) {
                                        CustomerBookingCard(booking: booking)
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

