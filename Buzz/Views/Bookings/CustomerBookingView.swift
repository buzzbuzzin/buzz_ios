//
//  CustomerBookingView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import MapKit
import Auth

struct CustomerBookingView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    @State private var showCreateBooking = false
    @State private var showConversations = false
    
    var body: some View {
        NavigationView {
            VStack {
                if bookingService.isLoading {
                    LoadingView(message: "Loading bookings...")
                } else {
                    // Filter: Only show available, accepted, and cancelled bookings (not completed)
                    let filteredBookings = bookingService.myBookings.filter { booking in
                        booking.status == .available || booking.status == .accepted || booking.status == .cancelled
                    }
                    
                    if filteredBookings.isEmpty {
                        EmptyStateView(
                            icon: "doc.text.magnifyingglass",
                            title: "No Active Bookings",
                            message: "Create your first drone pilot booking",
                            actionTitle: "Create Booking",
                            action: { showCreateBooking = true }
                        )
                    } else {
                        List {
                            ForEach(filteredBookings) { booking in
                                NavigationLink(destination: CustomerBookingDetailView(booking: booking)) {
                                    CustomerBookingCard(booking: booking)
                                }
                            }
                        }
                        .refreshable {
                            await loadBookings()
                        }
                    }
                }
            }
            .navigationTitle("My Bookings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showConversations = true
                    } label: {
                        Image(systemName: "message.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateBooking = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateBooking) {
                CreateBookingView()
            }
            .sheet(isPresented: $showConversations) {
                ConversationsListView()
            }
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

// MARK: - Customer Booking Card

struct CustomerBookingCard: View {
    let booking: Booking
    @StateObject private var profileService = ProfileService()
    @State private var pilotProfile: UserProfile?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(booking.locationName)
                        .font(.headline)
                    Spacer()
                    StatusBadge(status: booking.status)
                }
                
                // Show pilot name if assigned (text only, no picture)
                if let profile = pilotProfile,
                   booking.status == .accepted || booking.status == .completed {
                    HStack(spacing: 4) {
                        Image(systemName: "airplane.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(profile.fullName)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        if let callSign = profile.callSign {
                            Text("(\(callSign))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Category badge
                if let specialization = booking.specialization {
                    Label(specialization.displayName, systemImage: specialization.icon)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                
                // Required Minimum Rank
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Min Rank: \(booking.rankName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            
            Text(booking.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Label(
                    String(format: "$%.2f", NSDecimalNumber(decimal: booking.paymentAmount).doubleValue),
                    systemImage: "dollarsign.circle.fill"
                )
                .font(.subheadline)
                .foregroundColor(.green)
                
                Spacer()
                    
                    if let hours = booking.estimatedFlightHours {
                        Label(
                            String(format: "%.1f hrs", hours),
                            systemImage: "clock.fill"
                        )
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
        }
        .padding(.vertical, 8)
        .task {
            await loadPilotProfile()
        }
    }
    
    private func loadPilotProfile() async {
        guard let pilotId = booking.pilotId else { return }
        
        // Try to get sample pilot profile first (for demo)
        if let sampleProfile = profileService.getSamplePilotProfile(pilotId: pilotId) {
            pilotProfile = sampleProfile
        } else {
            // Fallback to real profile fetch
            do {
                pilotProfile = try await profileService.getProfile(userId: pilotId)
            } catch {
                print("Error loading pilot profile: \(error)")
            }
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: BookingStatus
    
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }
    
    private var statusColor: Color {
        switch status {
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
}

// MARK: - Create Booking View

struct CreateBookingView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    @Environment(\.dismiss) var dismiss
    
    @State private var currentStep = 1
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var locationName = ""
    @State private var selectedDate = Date()
    @State private var startTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var selectedSpecialization: BookingSpecialization?
    @State private var requiredMinimumRank: Int = 0 // Default to lowest rank (Ensign)
    @State private var description = ""
    @State private var paymentAmount = ""
    @State private var estimatedHours = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            Group {
                if currentStep == 1 {
                    CreateBookingStep1View(
                        selectedLocation: $selectedLocation,
                        locationName: $locationName,
                        selectedDate: $selectedDate,
                        startTime: $startTime,
                        endTime: $endTime,
                        selectedSpecialization: $selectedSpecialization,
                        requiredMinimumRank: $requiredMinimumRank,
                        onNext: {
                            if isStep1Valid {
                                currentStep = 2
                            }
                        }
                    )
                } else {
                    CreateBookingStep2View(
                        description: $description,
                        paymentAmount: $paymentAmount,
                        estimatedHours: $estimatedHours,
                        onBack: {
                            currentStep = 1
                        },
                        onCreate: createBooking,
                        isLoading: bookingService.isLoading,
                        isFormValid: isStep2Valid
                    )
                }
            }
            .navigationTitle(currentStep == 1 ? "Create Booking" : "Booking Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep == 1 {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Booking created successfully!")
            }
        }
    }
    
    private var isStep1Valid: Bool {
        selectedLocation != nil && selectedSpecialization != nil
    }
    
    private var isStep2Valid: Bool {
        !description.isEmpty &&
        !paymentAmount.isEmpty &&
        !estimatedHours.isEmpty &&
        Double(paymentAmount) != nil &&
        Double(estimatedHours) != nil
    }
    
    private func createBooking() {
        guard let currentUser = authService.currentUser,
              let location = selectedLocation,
              let specialization = selectedSpecialization,
              let payment = Double(paymentAmount),
              let hours = Double(estimatedHours) else {
            errorMessage = "Please fill in all fields correctly"
            showError = true
            return
        }
        
        // Combine date with start time
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        
        var startDateTimeComponents = DateComponents()
        startDateTimeComponents.year = dateComponents.year
        startDateTimeComponents.month = dateComponents.month
        startDateTimeComponents.day = dateComponents.day
        startDateTimeComponents.hour = startTimeComponents.hour
        startDateTimeComponents.minute = startTimeComponents.minute
        
        let startDateTime = calendar.date(from: startDateTimeComponents) ?? selectedDate
        
        var endDateTimeComponents = DateComponents()
        endDateTimeComponents.year = dateComponents.year
        endDateTimeComponents.month = dateComponents.month
        endDateTimeComponents.day = dateComponents.day
        endDateTimeComponents.hour = endTimeComponents.hour
        endDateTimeComponents.minute = endTimeComponents.minute
        
        let endDateTime = calendar.date(from: endDateTimeComponents) ?? startTime
        
        let userId = currentUser.id
        
        Task {
            do {
                try await bookingService.createBooking(
                    customerId: userId,
                    location: location,
                    locationName: locationName.isEmpty ? "Selected Location" : locationName,
                    scheduledDate: startDateTime,
                    endDate: endDateTime,
                    specialization: specialization,
                    description: description,
                    paymentAmount: Decimal(payment),
                    estimatedFlightHours: hours,
                    requiredMinimumRank: requiredMinimumRank
                )
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Customer Booking Detail View

struct CustomerBookingDetailView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    @StateObject private var ratingService = RatingService()
    @StateObject private var profileService = ProfileService()
    let booking: Booking
    @State private var region: MKCoordinateRegion
    @State private var showCancelAlert = false
    @State private var showRatingSheet = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var pilotName = "Pilot"
    @State private var pilotProfile: UserProfile?
    @State private var showMessageSheet = false
    @State private var showEditSheet = false
    
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
                    
                    StatusBadge(status: booking.status)
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // Created Date
                VStack(alignment: .leading, spacing: 8) {
                    Label("Created", systemImage: "calendar")
                        .font(.headline)
                    
                    Text(booking.createdAt.formatted(date: .long, time: .shortened))
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // Pilot Info Section (for accepted/completed bookings)
                if (booking.status == .accepted || booking.status == .completed), let pilotId = booking.pilotId {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Pilot", systemImage: "airplane.circle.fill")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            // Pilot Profile Picture
                            Group {
                                if let profile = pilotProfile,
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
                            
                            // Pilot Name
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pilotProfile?.fullName ?? "Pilot")
                                    .font(.headline)
                            }
                            
                            Spacer()
                            
                            // Message Button (only for accepted/completed bookings)
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
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                }
                
                // Tip Display
                if let tip = booking.tipAmount, tip > 0 {
                    HStack {
                        Label("Tip Added", systemImage: "heart.fill")
                            .font(.subheadline)
                            .foregroundColor(.pink)
                        Spacer()
                        Text(String(format: "+$%.2f", NSDecimalNumber(decimal: tip).doubleValue))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.pink)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                }
                
                // Total Payment
                if booking.status == .completed || booking.tipAmount != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Total Payment", systemImage: "creditcard.fill")
                            .font(.headline)
                        
                        let total = booking.paymentAmount + (booking.tipAmount ?? 0)
                        Text(String(format: "$%.2f", NSDecimalNumber(decimal: total).doubleValue))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                }
                
                // Edit and Cancel Buttons (for available and accepted bookings)
                if booking.status == .available || booking.status == .accepted {
                    VStack(spacing: 12) {
                        CustomButton(
                            title: "Edit Booking",
                            action: { showEditSheet = true },
                            style: .primary,
                            isLoading: false
                        )
                        
                        CustomButton(
                            title: "Cancel Booking",
                            action: { showCancelAlert = true },
                            style: .destructive,
                            isLoading: bookingService.isLoading
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Rate Pilot Button (for completed bookings)
                if booking.status == .completed && booking.customerRated != true {
                    CustomButton(
                        title: "Rate Pilot",
                        action: { showRatingSheet = true },
                        style: .primary
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Booking Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Cancel Booking", isPresented: $showCancelAlert) {
            Button("No", role: .cancel) {}
            Button("Yes", role: .destructive) {
                cancelBooking()
            }
        } message: {
            if booking.status == .accepted {
                Text("A pilot has already accepted this booking. Are you sure you want to cancel? This will notify the pilot.")
            } else {
                Text("Are you sure you want to cancel this booking?")
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showRatingSheet) {
            RatingView(
                userName: pilotName,
                isPilotRatingCustomer: false,
                onRatingSubmitted: { rating, comment, tip in
                    submitRating(rating: rating, comment: comment, tip: tip)
                }
            )
        }
        .sheet(isPresented: $showMessageSheet) {
            MessageView(
                customerProfile: pilotProfile,
                booking: booking
            )
        }
        .sheet(isPresented: $showEditSheet) {
            EditBookingView(booking: booking)
        }
        .task {
            // Load pilot profile
            await loadPilotProfile()
        }
    }
    
    private func loadPilotProfile() async {
        guard let pilotId = booking.pilotId else { return }
        
        // Try to get sample pilot profile first (for demo)
        if let sampleProfile = profileService.getSamplePilotProfile(pilotId: pilotId) {
            pilotProfile = sampleProfile
            pilotName = sampleProfile.fullName
        } else {
            // Fallback to real profile fetch
        do {
            pilotProfile = try await profileService.getProfile(userId: pilotId)
            pilotName = pilotProfile?.fullName ?? "Pilot"
        } catch {
            print("Error loading pilot profile: \(error)")
            pilotName = "Pilot"
            }
        }
    }
    
    private func cancelBooking() {
        Task {
            do {
                try await bookingService.cancelBooking(bookingId: booking.id)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func submitRating(rating: Int, comment: String?, tip: Decimal?) {
        guard let currentUser = authService.currentUser,
              let pilotId = booking.pilotId else { return }
        
        Task {
            do {
                // Submit rating
                try await ratingService.submitRating(
                    bookingId: booking.id,
                    fromUserId: currentUser.id,
                    toUserId: pilotId,
                    rating: rating,
                    comment: comment
                )
                
                // Add tip if provided
                if let tipAmount = tip {
                    try await bookingService.addTip(bookingId: booking.id, tipAmount: tipAmount)
                }
                
                // Mark as rated
                try await bookingService.markRatingStatus(
                    bookingId: booking.id,
                    isPilot: false,
                    hasRated: true
                )
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Edit Booking View

struct EditBookingView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @StateObject private var bookingService = BookingService()
    
    let booking: Booking
    
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var locationName: String
    @State private var selectedDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var selectedSpecialization: BookingSpecialization?
    @State private var requiredMinimumRank: Int
    @State private var description: String
    @State private var paymentAmount: String
    @State private var estimatedHours: String
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var showRankInfo = false
    
    init(booking: Booking) {
        self.booking = booking
        _locationName = State(initialValue: booking.locationName)
        _selectedLocation = State(initialValue: CLLocationCoordinate2D(latitude: booking.locationLat, longitude: booking.locationLng))
        _selectedDate = State(initialValue: booking.scheduledDate ?? Date())
        _startTime = State(initialValue: booking.scheduledDate ?? Date())
        _endTime = State(initialValue: booking.endDate ?? Date())
        _selectedSpecialization = State(initialValue: booking.specialization)
        _requiredMinimumRank = State(initialValue: booking.requiredMinimumRank ?? 0)
        _description = State(initialValue: booking.description)
        _paymentAmount = State(initialValue: String(format: "%.2f", NSDecimalNumber(decimal: booking.paymentAmount).doubleValue))
        _estimatedHours = State(initialValue: booking.estimatedFlightHours.map { String(format: "%.1f", $0) } ?? "")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Location Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Location")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                            Text(locationName)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    // Date Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Date")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        DatePicker(
                            "Booking Date",
                            selection: $selectedDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.compact)
                        .padding(.horizontal)
                    }
                    
                    // Time Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Time")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Start Time")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                DatePicker("", selection: $startTime, displayedComponents: [.hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("End Time")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                DatePicker("", selection: $endTime, displayedComponents: [.hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Required Minimum Rank Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Required Minimum Pilot Rank")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                showRankInfo = true
                            }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .font(.subheadline)
                            }
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            Text("Minimum Rank")
                                .font(.subheadline)
                            Spacer()
                            Picker("", selection: $requiredMinimumRank) {
                                ForEach(0...4, id: \.self) { rank in
                                    Text(PilotStats(pilotId: UUID(), totalFlightHours: 0, completedBookings: 0, tier: rank).tierName)
                                        .tag(rank)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120, alignment: .trailing)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Specialization Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Specialization")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(BookingSpecialization.allCases, id: \.self) { specialization in
                                SpecializationCard(
                                    specialization: specialization,
                                    isSelected: selectedSpecialization == specialization
                                ) {
                                    selectedSpecialization = specialization
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Description Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Description")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        TextEditor(text: $description)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    
                    // Payment & Hours Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Payment & Duration")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("Payment Amount ($)")
                                    .font(.subheadline)
                                Spacer()
                                TextField("0.00", text: $paymentAmount)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                            
                            HStack {
                                Text("Estimated Hours")
                                    .font(.subheadline)
                                Spacer()
                                TextField("0.0", text: $estimatedHours)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Save Button
                    CustomButton(
                        title: "Save Changes",
                        action: saveBooking,
                        isLoading: bookingService.isLoading,
                        isDisabled: !isFormValid
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Edit Booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Booking updated successfully!")
            }
            .sheet(isPresented: $showRankInfo) {
                RankInfoView()
            }
        }
    }
    
    private var isFormValid: Bool {
        !description.isEmpty &&
        !paymentAmount.isEmpty &&
        !estimatedHours.isEmpty &&
        Double(paymentAmount) != nil &&
        Double(estimatedHours) != nil &&
        selectedSpecialization != nil
    }
    
    private func saveBooking() {
        guard let specialization = selectedSpecialization,
              let payment = Double(paymentAmount),
              let hours = Double(estimatedHours) else {
            errorMessage = "Please fill in all fields correctly"
            showError = true
            return
        }
        
        // Combine date with start time
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        
        var startDateTimeComponents = DateComponents()
        startDateTimeComponents.year = dateComponents.year
        startDateTimeComponents.month = dateComponents.month
        startDateTimeComponents.day = dateComponents.day
        startDateTimeComponents.hour = startTimeComponents.hour
        startDateTimeComponents.minute = startTimeComponents.minute
        
        let startDateTime = calendar.date(from: startDateTimeComponents) ?? selectedDate
        
        var endDateTimeComponents = DateComponents()
        endDateTimeComponents.year = dateComponents.year
        endDateTimeComponents.month = dateComponents.month
        endDateTimeComponents.day = dateComponents.day
        endDateTimeComponents.hour = endTimeComponents.hour
        endDateTimeComponents.minute = endTimeComponents.minute
        
        let endDateTime = calendar.date(from: endDateTimeComponents) ?? startTime
        
        Task {
            do {
                try await bookingService.updateBooking(
                    bookingId: booking.id,
                    location: selectedLocation ?? booking.coordinate,
                    locationName: locationName,
                    scheduledDate: startDateTime,
                    endDate: endDateTime,
                    specialization: specialization,
                    description: description,
                    paymentAmount: Decimal(payment),
                    estimatedFlightHours: hours,
                    requiredMinimumRank: requiredMinimumRank
                )
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

