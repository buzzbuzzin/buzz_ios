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
                                ForEach(completedBookings.sorted(by: { booking1, booking2 in
                                    // Sort by completedAt if available, otherwise createdAt
                                    let date1 = booking1.completedAt ?? booking1.createdAt
                                    let date2 = booking2.completedAt ?? booking2.createdAt
                                    return date1 > date2
                                })) { booking in
                                    NavigationLink(destination: CustomerBookingDetailView(booking: booking)) {
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

// MARK: - Completed Booking Card (Simplified for Activity View)

struct CompletedBookingCard: View {
    let booking: Booking
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Line 1: Title
            Text(booking.locationName)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Line 2: Date and time of completion
            if let completedAt = booking.completedAt {
                Text(formatCompletionDate(completedAt))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                // Fallback to createdAt if completedAt is not available (for backwards compatibility)
                Text(formatCompletionDate(booking.createdAt))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Line 3: Total amount (including tips)
            let totalAmount = booking.paymentAmount + (booking.tipAmount ?? 0)
            Text(String(format: "$%.2f", NSDecimalNumber(decimal: totalAmount).doubleValue))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.green)
        }
        .padding(.vertical, 4)
    }
    
    private func formatCompletionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}

