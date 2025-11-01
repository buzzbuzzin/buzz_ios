//
//  BookingDetailView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import MapKit
import Auth

struct BookingDetailView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    @StateObject private var rankingService = RankingService()
    @StateObject private var ratingService = RatingService()
    @Environment(\.dismiss) var dismiss
    
    let booking: Booking
    @State private var region: MKCoordinateRegion
    @State private var showAcceptAlert = false
    @State private var showCompleteAlert = false
    @State private var showRatingSheet = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var customerName = "Customer"
    
    init(booking: Booking) {
        self.booking = booking
        _region = State(initialValue: MKCoordinateRegion(
            center: booking.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Map
                Map(coordinateRegion: .constant(region), annotationItems: [booking]) { booking in
                    MapAnnotation(coordinate: booking.coordinate) {
                        BookingAnnotation(booking: booking, isSelected: true)
                    }
                }
                .frame(height: 250)
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Location
                VStack(alignment: .leading, spacing: 8) {
                    Label("Location", systemImage: "mappin.circle.fill")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text(booking.locationName)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Label("Description", systemImage: "text.alignleft")
                        .font(.headline)
                    
                    Text(booking.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // Payment & Hours
                HStack(spacing: 40) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Payment", systemImage: "dollarsign.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        Text(String(format: "$%.2f", NSDecimalNumber(decimal: booking.paymentAmount).doubleValue))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    if let hours = booking.estimatedFlightHours {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Duration", systemImage: "clock.fill")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Text(String(format: "%.1f hours", hours))
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // Status
                VStack(alignment: .leading, spacing: 8) {
                    Label("Status", systemImage: "info.circle.fill")
                        .font(.headline)
                    
                    Text(booking.status.rawValue.capitalized)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusColor.opacity(0.2))
                        .foregroundColor(statusColor)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // Posted Date
                Text("Posted on \(booking.createdAt.formatted(date: .long, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                // Action Button
                if authService.userProfile?.userType == .pilot {
                    VStack(spacing: 12) {
                        if booking.status == .available {
                            CustomButton(
                                title: "Accept Booking",
                                action: { showAcceptAlert = true },
                                isLoading: bookingService.isLoading
                            )
                            .padding(.horizontal)
                        } else if booking.status == .accepted && booking.pilotId == authService.currentUser?.id {
                            CustomButton(
                                title: "Mark as Completed",
                                action: { showCompleteAlert = true },
                                style: .primary,
                                isLoading: bookingService.isLoading
                            )
                            .padding(.horizontal)
                        } else if booking.status == .completed && booking.pilotId == authService.currentUser?.id && booking.pilotRated != true {
                            CustomButton(
                                title: "Rate Customer",
                                action: { showRatingSheet = true },
                                style: .primary
                            )
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Booking Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Accept Booking", isPresented: $showAcceptAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Accept") {
                acceptBooking()
            }
        } message: {
            Text("Are you sure you want to accept this booking?")
        }
        .alert("Complete Booking", isPresented: $showCompleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Complete") {
                completeBooking()
            }
        } message: {
            Text("Mark this booking as completed? Your flight hours will be updated.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showRatingSheet) {
            RatingView(
                userName: customerName,
                isPilotRatingCustomer: true,
                onRatingSubmitted: { rating, comment, _ in
                    submitRating(rating: rating, comment: comment)
                }
            )
        }
        .task {
            // Load customer name for rating
            await loadCustomerName()
        }
    }
    
    private func loadCustomerName() async {
        // Fetch customer profile name
        // For now, use placeholder
        customerName = "Customer"
    }
    
    private var statusColor: Color {
        switch booking.status {
        case .available:
            return .green
        case .accepted:
            return .blue
        case .completed:
            return .gray
        case .cancelled:
            return .red
        }
    }
    
    private func acceptBooking() {
        guard let currentUser = authService.currentUser else { return }
        
        Task {
            let userId = currentUser.id
            do {
                try await bookingService.acceptBooking(bookingId: booking.id, pilotId: userId)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func completeBooking() {
        guard let currentUser = authService.currentUser else { return }
        
        Task {
            let userId = currentUser.id
            do {
                try await bookingService.completeBooking(bookingId: booking.id)
                
                // Update pilot stats
                if let hours = booking.estimatedFlightHours {
                    try await rankingService.updateFlightHours(pilotId: userId, additionalHours: hours)
                }
                
                // Show rating sheet after completion
                showRatingSheet = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func submitRating(rating: Int, comment: String?) {
        guard let currentUser = authService.currentUser else { return }
        let customerId = booking.customerId
        
        Task {
            do {
                try await ratingService.submitRating(
                    bookingId: booking.id,
                    fromUserId: currentUser.id,
                    toUserId: customerId,
                    rating: rating,
                    comment: comment
                )
                
                // Mark as rated
                try await bookingService.markRatingStatus(
                    bookingId: booking.id,
                    isPilot: true,
                    hasRated: true
                )
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

