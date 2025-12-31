//
//  IncidentLogBookingSelectionView.swift
//  Buzz
//
//  Created for incident log booking selection
//

import SwiftUI
import Auth

struct IncidentLogBookingSelectionView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    @StateObject private var incidentLogService = IncidentLogService()
    
    var body: some View {
        Group {
            if bookingService.isLoading {
                ProgressView("Loading your bookings...")
            } else if acceptedBookings.isEmpty {
                EmptyStateView(
                    icon: "airplane.circle",
                    title: "No Active Bookings",
                    message: "You don't have any accepted bookings yet. Accept a booking to create an incident log."
                )
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Info banner
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Select a Booking")
                                    .font(.headline)
                            }
                            
                            Text("Choose the booking related to the incident you want to report. Once submitted, the incident log cannot be modified.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top)
                        
                        ForEach(acceptedBookings) { booking in
                            NavigationLink(destination: IncidentLogFormView(booking: booking).environmentObject(authService)) {
                                IncidentLogBookingCard(booking: booking, hasExistingLog: false)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Incident Log")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadBookings()
        }
    }
    
    private var acceptedBookings: [Booking] {
        bookingService.myBookings.filter { booking in
            booking.status == .accepted ||
            (booking.isAutomotiveCrewBooking && booking.status == .available)
        }
    }
    
    private func loadBookings() async {
        guard let pilotId = authService.currentUser?.id else {
            return
        }
        try? await bookingService.fetchMyBookings(userId: pilotId, isPilot: true)
    }
}

// MARK: - Subviews

private struct IncidentLogBookingCard: View {
    let booking: Booking
    let hasExistingLog: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.locationName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let scheduledDate = booking.scheduledDate {
                        Text(scheduledDate, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if hasExistingLog {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            HStack {
                if let description = booking.description {
                    Label(description.prefix(50) + (description.count > 50 ? "..." : ""), systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
}


