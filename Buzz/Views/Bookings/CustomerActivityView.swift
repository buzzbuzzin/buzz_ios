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
                    let completedBookings = bookingService.myBookings.filter { $0.status == .completed }
                    let expiredBookings = bookingService.myBookings.filter { $0.status == .expired }
                    let cancelledBookings = bookingService.myBookings.filter { $0.status == .cancelled }

                    if completedBookings.isEmpty && expiredBookings.isEmpty && cancelledBookings.isEmpty {
                        EmptyStateView(
                            icon: "clock.arrow.circlepath",
                            title: "No Booking History",
                            message: "Your completed and expired booking history will appear here"
                        )
                    } else {
                        List {
                            if !completedBookings.isEmpty {
                                Section("Completed") {
                                    ForEach(completedBookings.sorted(by: { booking1, booking2 in
                                        let date1 = booking1.completedAt ?? booking1.createdAt
                                        let date2 = booking2.completedAt ?? booking2.createdAt
                                        return date1 > date2
                                    })) { booking in
                                        NavigationLink(destination: CustomerBookingDetailView(booking: booking)) {
                                            CompletedBookingCard(booking: booking, disputes: bookingService.disputes)
                                        }
                                    }
                                }
                            }

                            if !expiredBookings.isEmpty {
                                Section("Expired") {
                                    ForEach(expiredBookings.sorted(by: { $0.createdAt > $1.createdAt })) { booking in
                                        NavigationLink(destination: CustomerBookingDetailView(booking: booking)) {
                                            ExpiredBookingCard(booking: booking)
                                        }
                                    }
                                }
                            }

                            if !cancelledBookings.isEmpty {
                                Section("Cancelled") {
                                    ForEach(cancelledBookings.sorted(by: { $0.createdAt > $1.createdAt })) { booking in
                                        NavigationLink(destination: CustomerBookingDetailView(booking: booking)) {
                                            CompletedBookingCard(booking: booking, disputes: [])
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
            .navigationTitle("History")
        }
        .task {
            await loadBookings()
        }
    }

    private func loadBookings() async {
        guard let currentUser = authService.currentUser else { return }
        try? await bookingService.fetchMyBookings(userId: currentUser.id, isPilot: false)
        try? await bookingService.fetchMyDisputes()
    }
}

// MARK: - Completed Booking Card (Simplified for Activity View)

struct CompletedBookingCard: View {
    let booking: Booking
    var disputes: [BookingDispute] = []

    private var hasDispute: Bool {
        disputes.contains { $0.bookingId == booking.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Line 1: Title
                Text(booking.locationName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if hasDispute {
                    Label("Dispute", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)
                }
            }

            // Line 2: Date and time of completion
            if let completedAt = booking.completedAt {
                Text(formatCompletionDate(completedAt))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text(formatCompletionDate(booking.createdAt))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Line 3: Total amount (including tips)
            let totalAmount = booking.paymentAmount + (booking.tipAmount ?? 0)
            Text(String(format: "$%.2f", NSDecimalNumber(decimal: totalAmount).doubleValue))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatCompletionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Expired Booking Card

struct ExpiredBookingCard: View {
    let booking: Booking

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(booking.locationName)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Expired")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(6)
            }

            Text(formatDate(booking.expiresAt ?? booking.createdAt))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(String(format: "$%.2f", NSDecimalNumber(decimal: booking.paymentAmount).doubleValue))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}

