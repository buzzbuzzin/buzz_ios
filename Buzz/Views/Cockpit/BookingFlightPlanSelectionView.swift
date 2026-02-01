//
//  BookingFlightPlanSelectionView.swift
//  Buzz
//
//  Created for flight plan booking selection
//

import SwiftUI
import Auth

struct BookingFlightPlanSelectionView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    @State private var hasLoadedInitialData = false
    @State private var selectedBooking: Booking? = nil

    var body: some View {
        Group {
            if bookingService.isLoading && !hasLoadedInitialData {
                ProgressView("Loading your bookings...")
            } else if acceptedBookings.isEmpty {
                EmptyStateView(
                    icon: "airplane.circle",
                    title: "No Active Bookings",
                    message: "You don't have any accepted bookings yet. Accept a booking to create a flight plan."
                )
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(acceptedBookings) { booking in
                            Button {
                                selectedBooking = booking
                            } label: {
                                BookingFlightPlanCard(booking: booking)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
        }
        .fullScreenCover(item: $selectedBooking) { booking in
            NavigationView {
                FlightPlanFormView(booking: booking)
                    .environmentObject(authService)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                selectedBooking = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
            }
        }
        .navigationTitle("Select Booking")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !hasLoadedInitialData else { return }
            await loadBookings()
            hasLoadedInitialData = true
        }
    }

    private var acceptedBookings: [Booking] {
        bookingService.myBookings.filter { booking in
            booking.status == .accepted ||
            (booking.isAutomotiveCrewBooking && booking.status == .available)
        }
    }

    private func loadBookings() async {
        guard let pilotId = authService.currentUser?.id else { return }
        try? await bookingService.fetchMyBookings(userId: pilotId, isPilot: true)
    }
}

// MARK: - Subviews

private struct BookingFlightPlanCard: View {
    let booking: Booking

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Specialization Icon
                if let specialization = booking.specialization {
                    Image(systemName: specialization.icon)
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(Color.blue.gradient)
                        )
                } else {
                    Image(systemName: "airplane")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(Color.gray.gradient)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.specialization?.displayName ?? "Flight")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(booking.locationName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }

            Divider()

            // Flight Details
            HStack(spacing: 20) {
                if let scheduledDate = booking.scheduledDate {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Date")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(scheduledDate, style: .date)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(scheduledDate, style: .time)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
