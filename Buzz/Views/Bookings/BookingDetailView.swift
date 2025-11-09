//
//  BookingDetailView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import MapKit
import Auth
import UIKit

struct BookingDetailView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    @StateObject private var rankingService = RankingService()
    @StateObject private var ratingService = RatingService()
    @StateObject private var profileService = ProfileService()
    @StateObject private var identityService = IdentityVerificationService()
    @Environment(\.dismiss) var dismiss
    
    let booking: Booking
    @State private var region: MKCoordinateRegion
    @State private var showAcceptAlert = false
    @State private var showCompleteAlert = false
    @State private var showRatingSheet = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var customerProfile: UserProfile?
    @State private var showMessageSheet = false
    @State private var showCopyConfirmation = false
    @State private var isIdentityVerified = false
    @State private var showVerificationRequiredAlert = false
    @State private var showDirectionsSheet = false
    @State private var showFinishBookingAlert = false
    @State private var showCompletionConfirmation = false
    @State private var showCompletionSuccess = false
    @State private var currentBooking: Booking
    
    init(booking: Booking) {
        self.booking = booking
        _region = State(initialValue: MKCoordinateRegion(
            center: booking.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        _currentBooking = State(initialValue: booking)
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
                    
                    // Detailed Address with Get directions button
                    HStack {
                        Text(detailedAddress)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        Button(action: {
                            showDirectionsSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                Text("Get directions")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // Customer Info Section (for pilots)
                if authService.userProfile?.userType == .pilot {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Posted by", systemImage: "person.fill")
                            .font(.headline)
                        
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
                                                .frame(width: 60, height: 60)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 60, height: 60)
                                                .clipShape(Circle())
                                        case .failure:
                                            Image(systemName: "person.circle.fill")
                                                .font(.system(size: 60))
                                                .foregroundColor(.blue)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.blue)
                                }
                            }
                            .frame(width: 60, height: 60)
                            
                            // Customer Name
                            VStack(alignment: .leading, spacing: 4) {
                                Text(customerProfile?.fullName ?? "Customer")
                                    .font(.headline)
                            }
                            
                            Spacer()
                            
                            // Message Button (only for accepted/completed bookings)
                            if currentBooking.status == .accepted || currentBooking.status == .completed {
                                Button(action: {
                                    showMessageSheet = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "message.fill")
                                        Text("Message")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .cornerRadius(20)
                                }
                            } else {
                                Text("Message available after booking is accepted")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                }
                
                // Category
                if let specialization = booking.specialization {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Category", systemImage: "tag.fill")
                            .font(.headline)
                        
                        HStack {
                            Label(specialization.displayName, systemImage: specialization.icon)
                                .font(.body)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                }
                
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
                
                // Payment, Hourly Rate & Hours (Grid Layout)
                VStack(spacing: 20) {
                    // First row: Payment and Hourly rate
                    HStack(spacing: 40) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Payment", systemImage: "dollarsign.circle.fill")
                                .font(.subheadline)
                                .foregroundColor(.green)
                            Text(String(format: "$%.2f", NSDecimalNumber(decimal: booking.paymentAmount).doubleValue))
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        if let hours = booking.estimatedFlightHours, hours > 0 {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Hourly rate", systemImage: "clock.badge.checkmark")
                                    .font(.subheadline)
                                    .foregroundColor(.purple)
                                Text(String(format: "$%.2f/hr", NSDecimalNumber(decimal: booking.paymentAmount).doubleValue / hours))
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Second row: Duration
                    if let hours = booking.estimatedFlightHours {
                        HStack(spacing: 40) {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Duration", systemImage: "clock.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                Text(String(format: "%.1f hours", hours))
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
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
                        if currentBooking.status == .available {
                            if isIdentityVerified {
                                CustomButton(
                                    title: "Accept Booking",
                                    action: { showAcceptAlert = true },
                                    isLoading: bookingService.isLoading
                                )
                                .padding(.horizontal)
                            } else {
                                VStack(spacing: 8) {
                                    CustomButton(
                                        title: "Accept Booking",
                                        action: { showVerificationRequiredAlert = true },
                                        isLoading: false
                                    )
                                    .padding(.horizontal)
                                    .disabled(true)
                                    .opacity(0.6)
                                    
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        Text("Identity verification required to accept bookings")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        } else if currentBooking.status == .accepted && currentBooking.pilotId == authService.currentUser?.id {
                            // Show Finish Booking button if pilot hasn't completed yet and customer hasn't completed yet
                            if currentBooking.pilotCompleted != true && currentBooking.customerCompleted != true {
                                CustomButton(
                                    title: "Finish Booking",
                                    action: { showFinishBookingAlert = true },
                                    style: .primary,
                                    isLoading: bookingService.isLoading
                                )
                                .padding(.horizontal)
                            }
                            
                            // Show waiting message if pilot has completed but customer hasn't
                            if currentBooking.pilotCompleted == true && currentBooking.customerCompleted != true {
                                VStack(spacing: 12) {
                                    Text("Booking finish is waiting to be confirmed by customer")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                        .multilineTextAlignment(.center)
                                        .padding()
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .padding(.horizontal)
                            }
                            
                            // Completion Confirmation (when customer has marked as finished)
                            if currentBooking.customerCompleted == true && currentBooking.pilotCompleted != true {
                                VStack(spacing: 12) {
                                    Text("Customer has marked this booking as finished")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .multilineTextAlignment(.center)
                                        .padding()
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                    
                                    CustomButton(
                                        title: "Confirm Completion",
                                        action: { showCompletionConfirmation = true },
                                        style: .primary,
                                        isLoading: bookingService.isLoading
                                    )
                                }
                                .padding(.horizontal)
                            }
                        } else if currentBooking.status == .completed && currentBooking.pilotId == authService.currentUser?.id && currentBooking.pilotRated != true {
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
        .alert("Finish Booking", isPresented: $showFinishBookingAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Finish") {
                finishBooking()
            }
        } message: {
            Text("Mark this booking as finished? The customer will be notified to confirm completion.")
        }
        .alert("Confirm Completion", isPresented: $showCompletionConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm") {
                confirmCompletion()
            }
        } message: {
            Text("Confirm that this booking is complete? This will finalize the booking and update your balance.")
        }
        .alert("Booking Completed", isPresented: $showCompletionSuccess) {
            Button("OK") {
                // Refresh view or navigate back
            }
        } message: {
            Text("Booking completed successfully! Your balance has been updated.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Verification Required", isPresented: $showVerificationRequiredAlert) {
            Button("Go to Settings", role: .none) {
                // Navigate to profile/settings - user will need to manually navigate
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You must verify your identity before accepting bookings. Please complete identity verification in your Profile settings.")
        }
        .sheet(isPresented: $showRatingSheet) {
            RatingView(
                userName: customerProfile?.fullName ?? "Customer",
                isPilotRatingCustomer: true,
                onRatingSubmitted: { rating, comment, _ in
                    submitRating(rating: rating, comment: comment)
                }
            )
        }
        .sheet(isPresented: $showMessageSheet) {
            MessageView(
                customerProfile: customerProfile,
                booking: currentBooking
            )
        }
        .sheet(isPresented: $showDirectionsSheet) {
            DirectionsBottomSheet(
                onOpenAppleMaps: {
                    showDirectionsSheet = false
                    openAppleMaps()
                },
                onOpenGoogleMaps: {
                    showDirectionsSheet = false
                    openGoogleMaps()
                },
                onCopyToClipboard: {
                    showDirectionsSheet = false
                    copyToClipboard()
                },
                onCancel: {
                    showDirectionsSheet = false
                }
            )
            .presentationDetents([.height(214)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
        }
        .alert("Copied!", isPresented: $showCopyConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Address copied to clipboard")
        }
        .task {
            await loadCustomerProfile()
            await checkIdentityVerification()
            await refreshBooking()
        }
        .onAppear {
            // Refresh booking when view appears to get latest status
            Task {
                await refreshBooking()
            }
        }
    }
    
    private func checkIdentityVerification() async {
        guard let userId = authService.currentUser?.id else { return }
        isIdentityVerified = await identityService.isIdentityVerified(userId: userId)
    }
    
    private func refreshBooking() async {
        do {
            let updatedBooking = try await bookingService.getBooking(bookingId: booking.id)
            currentBooking = updatedBooking
        } catch {
            print("Error refreshing booking: \(error)")
            // Keep current booking if refresh fails
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
    
    private var detailedAddress: String {
        // Return detailed street addresses for famous tourist locations
        // These are actual addresses for demo purposes
        switch booking.locationName {
        case "Golden Gate Bridge, San Francisco":
            return "Golden Gate Bridge, San Francisco, CA 94129"
        case "Hollywood Hills, Los Angeles":
            return "Hollywood Hills, Los Angeles, CA 90068"
        case "Brooklyn Bridge, New York":
            return "Brooklyn Bridge, New York, NY 10038"
        case "Millennium Park, Chicago":
            return "201 E Randolph St, Chicago, IL 60602"
        case "Independence Hall, Philadelphia":
            return "520 Chestnut St, Philadelphia, PA 19106"
        case "Downtown Houston, Texas":
            return "Downtown Houston, TX 77002"
        case "Coit Tower, San Francisco":
            return "1 Telegraph Hill Blvd, San Francisco, CA 94133"
        case "Griffith Observatory, Los Angeles":
            return "2800 E Observatory Rd, Los Angeles, CA 90027"
        case "Central Park, New York":
            return "Central Park, New York, NY 10024"
        case "Navy Pier, Chicago":
            return "600 E Grand Ave, Chicago, IL 60611"
        case "South Beach, Miami":
            return "South Beach, Miami Beach, FL 33139"
        case "Space Needle, Seattle":
            return "400 Broad St, Seattle, WA 98109"
        default:
            return booking.locationName
        }
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
                // Refresh booking after accepting
                await refreshBooking()
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
    
    private func finishBooking() {
        Task {
            do {
                let isCompleted = try await bookingService.markBookingCompletion(bookingId: currentBooking.id, isPilot: true)
                
                // Refresh booking to get latest status
                await refreshBooking()
                
                if isCompleted {
                    // Both parties confirmed, booking is completed
                    showCompletionSuccess = true
                    
                    // Update pilot stats
                    if let hours = currentBooking.estimatedFlightHours, let userId = authService.currentUser?.id {
                        try await rankingService.updateFlightHours(pilotId: userId, additionalHours: hours)
                    }
                } else {
                    // Waiting for customer confirmation
                    // The view will automatically update when booking is refreshed
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func confirmCompletion() {
        Task {
            do {
                let isCompleted = try await bookingService.markBookingCompletion(bookingId: currentBooking.id, isPilot: true)
                
                // Refresh booking to get latest status
                await refreshBooking()
                
                if isCompleted {
                    // Both parties confirmed, booking is completed
                    showCompletionSuccess = true
                    
                    // Update pilot stats
                    if let hours = currentBooking.estimatedFlightHours, let userId = authService.currentUser?.id {
                        try await rankingService.updateFlightHours(pilotId: userId, additionalHours: hours)
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func submitRating(rating: Int, comment: String?) {
        guard let currentUser = authService.currentUser else { return }
        let customerId = currentBooking.customerId
        
        Task {
            do {
                try await ratingService.submitRating(
                    bookingId: currentBooking.id,
                    fromUserId: currentUser.id,
                    toUserId: customerId,
                    rating: rating,
                    comment: comment
                )
                
                // Mark as rated
                try await bookingService.markRatingStatus(
                    bookingId: currentBooking.id,
                    isPilot: true,
                    hasRated: true
                )
                
                // Refresh booking to update rated status
                await refreshBooking()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func openAppleMaps() {
        let coordinate = booking.coordinate
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = booking.locationName
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    private func openGoogleMaps() {
        let coordinate = booking.coordinate
        let lat = coordinate.latitude
        let lng = coordinate.longitude
        
        // Google Maps URL scheme
        if let url = URL(string: "comgooglemaps://?q=\(lat),\(lng)&directionsmode=driving") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                // Fallback to web version if app is not installed
                if let webUrl = URL(string: "https://www.google.com/maps?q=\(lat),\(lng)&directionsmode=driving") {
                    UIApplication.shared.open(webUrl)
                }
            }
        }
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = detailedAddress
        showCopyConfirmation = true
        // Auto-dismiss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopyConfirmation = false
        }
    }
}

// MARK: - Directions Bottom Sheet

struct DirectionsBottomSheet: View {
    let onOpenAppleMaps: () -> Void
    let onOpenGoogleMaps: () -> Void
    let onCopyToClipboard: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Action buttons group
            VStack(spacing: 0) {
                Button(action: onOpenAppleMaps) {
                    Text("Open Apple Maps")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                
                Divider()
                
                Button(action: onOpenGoogleMaps) {
                    Text("Open Google Maps")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                
                Divider()
                
                Button(action: onCopyToClipboard) {
                    Text("Copy to Clipboard")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(14)
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            // Spacing between action buttons and cancel
            Spacer()
                .frame(height: 8)
            
            // Cancel button
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .background(Color(.systemGray6))
            .cornerRadius(14)
            .padding(.horizontal, 8)
            .padding(.bottom, 0)
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .ignoresSafeArea(edges: .bottom)
    }
}

