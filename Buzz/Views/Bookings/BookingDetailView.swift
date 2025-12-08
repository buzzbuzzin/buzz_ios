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
    @State private var customerRating: Double? = nil
    @State private var showMessageSheet = false
    @State private var showCopyConfirmation = false
    @State private var isIdentityVerified = false
    @State private var showVerificationRequiredAlert = false
    @State private var showDirectionsSheet = false
    @State private var showFinishBookingAlert = false
    @State private var showCompletionConfirmation = false
    @State private var showCompletionSuccess = false
    @State private var currentBooking: Booking
    
    // Crew-related state (for automotive bookings)
    @State private var crewInfo: BookingCrewResponse?
    @State private var isLoadingCrew = false
    @State private var showJoinCrewAlert = false
    @State private var joinCrewResult: JoinCrewResponse?
    @State private var showJoinCrewSuccess = false
    
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
                        Label("Charted by", systemImage: "person.fill")
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
                    
                    if let description = booking.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No description provided")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                    }
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
                
                // Start Time
                if let scheduledDate = booking.scheduledDate {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Start Time", systemImage: "calendar.badge.clock")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatStartTime(scheduledDate))
                                .font(.body)
                            
                            Text("Zulu: \(formatZuluTime(scheduledDate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                }
                
                // Status
                VStack(alignment: .leading, spacing: 8) {
                    Label("Status", systemImage: "info.circle.fill")
                        .font(.headline)
                    
                    Text(booking.status.displayName.capitalized)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusColor.opacity(0.2))
                        .foregroundColor(statusColor)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // Crew Status Section (for automotive bookings)
                if currentBooking.isAutomotiveCrewBooking {
                    Divider()
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Crew Status", systemImage: "person.3.fill")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        if isLoadingCrew {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading crew info...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else if let crew = crewInfo {
                            VStack(alignment: .leading, spacing: 8) {
                                // Crew count progress
                                HStack {
                                    Text("\(crew.crewCount)/\(crew.maxCrew) pilots joined")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    if crew.isReady == true {
                                        Label("Ready", systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else if crew.hasQualifiedLead == true {
                                        Label("Has Lead", systemImage: "star.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    } else {
                                        Label("Needs Lieutenant+", systemImage: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                                
                                // Progress bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 8)
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(crew.isReady == true ? Color.green : Color.blue)
                                            .frame(width: geometry.size.width * CGFloat(crew.crewCount) / CGFloat(crew.maxCrew), height: 8)
                                    }
                                }
                                .frame(height: 8)
                                
                                // Lead pilot info (if available)
                                if let lead = crew.leadPilot {
                                    HStack(spacing: 8) {
                                        // Lead profile picture
                                        if let pictureUrl = lead.profilePictureUrl,
                                           let url = URL(string: pictureUrl) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 32, height: 32)
                                                        .clipShape(Circle())
                                                default:
                                                    Image(systemName: "person.circle.fill")
                                                        .font(.system(size: 32))
                                                        .foregroundColor(.blue)
                                                }
                                            }
                                        } else {
                                            Image(systemName: "person.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(.blue)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Lead: \(lead.callSign ?? "Unknown Callsign")")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            if let rankName = lead.rankName {
                                                Text(rankName)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                                
                                // Show crew members list for pilots
                                if authService.userProfile?.userType == .pilot,
                                   let crewMembers = crew.crew, !crewMembers.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Crew Members:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.top, 4)
                                        
                                        ForEach(crewMembers) { member in
                                            HStack {
                                                Circle()
                                                    .fill(member.role == .lead ? Color.orange : Color.blue)
                                                    .frame(width: 8, height: 8)
                                                
                                                Text(member.callSign ?? "Pilot")
                                                    .font(.caption)
                                                
                                                Text("(\(member.rankName))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                
                                                if member.role == .lead {
                                                    Text("Lead")
                                                        .font(.caption2)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.orange)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.orange.opacity(0.2))
                                                        .cornerRadius(4)
                                                }
                                                
                                                Spacer()
                                                
                                                // Only show payout for the current user
                                                if member.pilotId == authService.currentUser?.id {
                                                    Text(String(format: "$%.0f", NSDecimalNumber(decimal: member.payoutAmount).doubleValue))
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.green)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            Text("Crew info unavailable")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Posted Date
                Text("Posted on \(booking.createdAt.formatted(date: .long, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                // Action Button
                if authService.userProfile?.userType == .pilot {
                    VStack(spacing: 12) {
                        if currentBooking.status == .available {
                            // Check if pilot is already in crew (for automotive bookings)
                            let isAlreadyInCrew = crewInfo?.crew?.contains(where: { $0.pilotId == authService.currentUser?.id }) ?? false
                            
                            if isIdentityVerified {
                                if currentBooking.isAutomotiveCrewBooking {
                                    // Automotive booking - show Join Crew button
                                    if isAlreadyInCrew {
                                        VStack(spacing: 8) {
                                            HStack {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                                Text("You've joined this crew")
                                                    .fontWeight(.semibold)
                                            }
                                            .foregroundColor(.green)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(Color.green.opacity(0.1))
                                            .cornerRadius(12)
                                            .padding(.horizontal)
                                            
                                            if let crew = crewInfo {
                                                Text("Waiting for \(crew.maxCrew - crew.crewCount) more pilot(s) to join")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    } else {
                                        CustomButton(
                                            title: "Join Crew",
                                            action: { showJoinCrewAlert = true },
                                            isLoading: bookingService.isLoading
                                        )
                                        .padding(.horizontal)
                                        
                                        // Show crew requirements info
                                        VStack(spacing: 4) {
                                            Text("Automotive bookings require a crew of 4 pilots")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("At least one Lieutenant or above must lead")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal)
                                    }
                                } else {
                                    // Non-automotive booking - regular accept
                                    CustomButton(
                                        title: "Accept Booking",
                                        action: { showAcceptAlert = true },
                                        isLoading: bookingService.isLoading
                                    )
                                    .padding(.horizontal)
                                }
                            } else {
                                VStack(spacing: 8) {
                                    CustomButton(
                                        title: currentBooking.isAutomotiveCrewBooking ? "Join Crew" : "Accept Booking",
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
        .alert("Join Crew", isPresented: $showJoinCrewAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Join") {
                joinCrew()
            }
        } message: {
            Text("Join this automotive booking crew? You'll be paid based on your current rank when the booking is completed.")
        }
        .alert("Joined Crew!", isPresented: $showJoinCrewSuccess) {
            Button("OK") {
                Task {
                    await loadCrewInfo()
                }
            }
        } message: {
            if let result = joinCrewResult, let member = result.crewMember, let status = result.crewStatus {
                Text("You've joined the crew! Crew: \(status.currentCount)/\(status.maxCount)")
            } else {
                Text("Successfully joined the crew!")
            }
        }
        .sheet(isPresented: $showRatingSheet) {
            RatingView(
                userName: customerProfile?.fullName ?? "Customer",
                isPilotRatingCustomer: true,
                onRatingSubmitted: { rating, comment, _ in
                    submitRating(rating: rating, comment: comment)
                },
                customTitle: currentBooking.status == .completed ? "Booking is completed" : nil,
                paymentAmount: currentBooking.paymentAmount,
                userRating: customerRating
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
            if currentBooking.isAutomotiveCrewBooking {
                await loadCrewInfo()
            }
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
        
        // Fetch customer rating
        do {
            if let ratingSummary = try await ratingService.getUserRatingSummary(userId: booking.customerId) {
                customerRating = ratingSummary.averageRating
            }
        } catch {
            print("Error loading customer rating: \(error)")
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
                let userId = authService.currentUser?.id
                let isCompleted = try await bookingService.markBookingCompletion(bookingId: currentBooking.id, isPilot: true, userId: userId)
                
                // Refresh booking to get latest status
                await refreshBooking()
                
                if isCompleted {
                    // Both parties confirmed, booking is completed
                    showCompletionSuccess = true
                    
                    // Update pilot stats (for non-automotive bookings only)
                    // Automotive bookings update ALL crew members' stats in BookingService
                    if !currentBooking.isAutomotiveCrewBooking,
                       let hours = currentBooking.estimatedFlightHours, 
                       let userId = userId {
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
                let userId = authService.currentUser?.id
                let isCompleted = try await bookingService.markBookingCompletion(bookingId: currentBooking.id, isPilot: true, userId: userId)
                
                // Refresh booking to get latest status
                await refreshBooking()
                
                if isCompleted {
                    // Both parties confirmed, booking is completed
                    showCompletionSuccess = true
                    
                    // Update pilot stats (for non-automotive bookings only)
                    // Automotive bookings update ALL crew members' stats in BookingService
                    if !currentBooking.isAutomotiveCrewBooking,
                       let hours = currentBooking.estimatedFlightHours, 
                       let userId = userId {
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
    
    private func formatStartTime(_ date: Date) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = timeFormatter.string(from: date)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        let dateString = dateFormatter.string(from: date)
        
        return "\(timeString), \(dateString)"
    }
    
    private func formatZuluTime(_ date: Date) -> String {
        let utcTimeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone(abbreviation: "UTC") ?? .current
        let calendar = Calendar(identifier: .gregorian)
        let utcComponents = calendar.dateComponents(in: utcTimeZone, from: date)
        
        let day = utcComponents.day ?? 0
        let hour = utcComponents.hour ?? 0
        let minute = utcComponents.minute ?? 0
        
        return String(format: "%02d%02d%02dZ", day, hour, minute)
    }
    
    // MARK: - Crew Functions (Automotive Bookings)
    
    private func loadCrewInfo() async {
        guard currentBooking.isAutomotiveCrewBooking else { return }
        
        isLoadingCrew = true
        do {
            let requesterType = authService.userProfile?.userType == .pilot ? "pilot" : "customer"
            crewInfo = try await bookingService.fetchBookingCrew(
                bookingId: currentBooking.id,
                requesterId: authService.currentUser?.id,
                requesterType: requesterType
            )
            isLoadingCrew = false
        } catch {
            isLoadingCrew = false
            print("Error loading crew info: \(error)")
        }
    }
    
    private func joinCrew() {
        guard let currentUser = authService.currentUser else { return }
        
        Task {
            do {
                let result = try await bookingService.joinAutomotiveBooking(
                    bookingId: currentBooking.id,
                    pilotId: currentUser.id
                )
                joinCrewResult = result
                
                if result.success {
                    showJoinCrewSuccess = true
                    // Reload crew info
                    await loadCrewInfo()
                    // Refresh booking in case status changed
                    await refreshBooking()
                    
                    // Send notification if booking was just accepted (crew complete)
                    if let crewStatus = result.crewStatus, crewStatus.bookingAccepted {
                        let role = result.crewMember?.role ?? "crew"
                        await NotificationManager.shared.notifyCrewBookingAccepted(
                            bookingId: currentBooking.id,
                            crewCount: crewStatus.currentCount,
                            role: role,
                            scheduledDate: currentBooking.scheduledDate
                        )
                    }
                } else if let error = result.error {
                    errorMessage = error
                    showError = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
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

