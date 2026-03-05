//
//  CustomerBookingView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import MapKit
import Auth
import Supabase

struct CustomerBookingView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    @StateObject private var identityService = IdentityVerificationService()
    @State private var showCreateBooking = false
    @State private var showConversations = false
    @State private var isPromotionCardDismissed = false
    @State private var newlyCreatedBooking: Booking?
    @State private var navigateToBookingDetail = false
    @State private var promotionNavigationSelection: BundlePackage?
    @State private var isIdentityVerified = false
    @State private var showVerificationRequiredAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Hidden navigation links for Buzz Auto / Real Estate packages
                NavigationLink(
                    destination: FlightPackageView(),
                    tag: .auto,
                    selection: $promotionNavigationSelection
                ) {
                    EmptyView()
                }
                .hidden()
                
                NavigationLink(
                    destination: RealEstatePackageView(),
                    tag: .realEstate,
                    selection: $promotionNavigationSelection
                ) {
                    EmptyView()
                }
                .hidden()
                
                // Buzz Subscription Promotion Card
                if !isPromotionCardDismissed {
                    BuzzBundlesPromotionCard(
                        onDismiss: {
                            isPromotionCardDismissed = true
                        },
                        onSelectBundle: { bundle in
                            // Navigate after the promotion sheet dismisses
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                promotionNavigationSelection = bundle
                            }
                        }
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                }
                
                if bookingService.isLoading {
                    LoadingView(message: "Loading bookings...")
                } else {
                    // Active bookings: available, accepted, staffed, in_progress
                    let activeBookings = bookingService.myBookings.filter { booking in
                        booking.status == .available || booking.status == .accepted || booking.status == .staffed || booking.status == .inProgress
                    }
                    // Expired bookings
                    let expiredBookings = bookingService.myBookings.filter { $0.status == .expired }

                    if activeBookings.isEmpty && expiredBookings.isEmpty {
                        EmptyStateView(
                            icon: "doc.text.magnifyingglass",
                            title: "No Active Bookings",
                            message: "Create your first drone pilot booking",
                            actionTitle: "Create Booking",
                            action: { attemptCreateBooking() }
                        )
                    } else {
                        List {
                            if !activeBookings.isEmpty {
                                Section("Active") {
                                    ForEach(activeBookings) { booking in
                                        NavigationLink(destination: CustomerBookingDetailView(booking: booking)) {
                                            CustomerBookingCard(booking: booking)
                                        }
                                    }
                                }
                            }

                            if !expiredBookings.isEmpty {
                                Section("Expired") {
                                    ForEach(expiredBookings) { booking in
                                        NavigationLink(destination: CustomerBookingDetailView(booking: booking)) {
                                            CustomerBookingCard(booking: booking)
                                                .opacity(0.6)
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
                        attemptCreateBooking()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("customer.createBookingButton")
                }
            }
            .sheet(isPresented: $showCreateBooking, onDismiss: {
                // Refresh bookings when sheet is dismissed (after successful creation)
                Task {
                    await loadBookings()
                }
                // Navigate to booking detail if a booking was created
                if let booking = newlyCreatedBooking {
                    navigateToBookingDetail = true
                }
            }) {
                CreateBookingView(onBookingCreated: { booking in
                    newlyCreatedBooking = booking
                })
                    .environmentObject(authService)
            }
            .background(
                Group {
                    if let booking = newlyCreatedBooking {
                        NavigationLink(
                            destination: CustomerBookingDetailView(booking: booking),
                            isActive: $navigateToBookingDetail
                        ) {
                            EmptyView()
                        }
                    }
                }
            )
            .sheet(isPresented: $showConversations) {
                ConversationsListView()
            }
            .alert("Verification Required", isPresented: $showVerificationRequiredAlert) {
                Button("Go to Settings", role: .none) { }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You must verify your identity before creating bookings. Please complete identity verification in your Profile settings under Personal Info.")
            }
        }
        .task {
            await loadBookings()
            await checkIdentityVerification()
        }
        .onAppear {
            // Reset promotion card dismissal when view appears (so it shows again)
            isPromotionCardDismissed = false
        }
    }
    
    private func attemptCreateBooking() {
        if isIdentityVerified {
            showCreateBooking = true
        } else {
            showVerificationRequiredAlert = true
        }
    }

    private func checkIdentityVerification() async {
        guard let userId = authService.activeUserId else { return }
        isIdentityVerified = await identityService.isIdentityVerified(userId: userId)
    }

    private func loadBookings() async {
        guard let currentUserId = authService.activeUserId else { return }
        do {
            try await bookingService.fetchMyBookings(userId: currentUserId, isPilot: false)
        } catch {
            print("Error loading bookings: \(error.localizedDescription)")
            // Error is handled in BookingService, which will show demo data as fallback
        }
    }
}

// MARK: - Customer Booking Card

struct CustomerBookingCard: View {
    let booking: Booking
    @StateObject private var profileService = ProfileService()
    @State private var pilotProfile: UserProfile?
    
    // Check if pilot info should be visible (always show if pilot is assigned)
    private var shouldShowPilotInfo: Bool {
        return booking.pilotId != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(booking.locationName)
                        .font(.headline)
                    Spacer()
                    // Expiration badge
                    if booking.status == .available,
                       let expiresAt = booking.expiresAt,
                       expiresAt.timeIntervalSinceNow < 24 * 60 * 60 && expiresAt.timeIntervalSinceNow > 0 {
                        Label("Expiring", systemImage: "clock.badge.exclamationmark")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(6)
                    }
                    StatusBadge(status: booking.status)
                }

                // Show pilot callsign if assigned (text only, no picture)
                if let profile = pilotProfile,
                   (booking.status == .accepted || booking.status == .staffed || booking.status == .inProgress || booking.status == .completed),
                   shouldShowPilotInfo {
                    HStack(spacing: 4) {
                        Image(systemName: "airplane.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        if let callSign = profile.callSign, !callSign.isEmpty {
                            Text("@\(callSign)")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        } else {
                            Text("Pilot")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                } else if booking.status == .accepted || booking.status == .completed,
                          booking.pilotId != nil,
                          !shouldShowPilotInfo {
                    // Pilot is matched - this case should not occur since we always show pilot info
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
//                    Image(systemName: "star.fill")
//                        .font(.caption)
//                        .foregroundColor(.orange)
                    Text("Pilot Rank: \(booking.rankName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            
            if let description = booking.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
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
        Text(status.displayName.capitalized)
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
        case .staffed:
            return .cyan
        case .inProgress:
            return .orange
        case .completed:
            return .gray
        case .expired:
            return .secondary
        case .cancelled:
            return .red
        }
    }
}

// MARK: - Create Booking View

struct CreateBookingView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    @StateObject private var paymentService = PaymentService()
    @StateObject private var subscriptionService = SubscriptionService()
    @StateObject private var referralService = ReferralService()
    @Environment(\.dismiss) var dismiss
    
    let onBookingCreated: ((Booking) -> Void)?
    
    init(onBookingCreated: ((Booking) -> Void)? = nil) {
        self.onBookingCreated = onBookingCreated
        
        let isUITest = ProcessInfo.processInfo.arguments.contains("UI_TESTING") || ProcessInfo.processInfo.environment["UITEST_MODE"] == "1"
        if isUITest {
            _selectedLocation = State(initialValue: CLLocationCoordinate2D(latitude: 42.4434, longitude: -76.5017))
            _locationName = State(initialValue: "Test Location")
            _selectedSpecialization = State(initialValue: .realEstate)
            _paymentAmount = State(initialValue: "100")
        }
    }
    
    @State private var currentStep = 1
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var locationName = ""
    @State private var selectedDate = Date()
    @State private var startTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime: Date? = nil
    @State private var selectedSpecialization: BookingSpecialization?
    @State private var requiredMinimumRank: Int = 4 // Default to highest rank (Captain)
    @State private var description = ""
    @State private var paymentAmount = ""
    @State private var estimatedHours = "2"
    @State private var paymentInputType: PaymentInputType = .totalPayment
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var isProcessingPayment = false
    @State private var showSuccessAnimation = false
    @State private var shouldShowBookingDetail = false
    @State private var createdBooking: Booking?
    @State private var hasAutomotiveSubscription = false
    @State private var isFirstAutomotiveBooking = true
    @State private var isLoadingSubscription = false
    @State private var automotiveSubscriptionPrices: [AutomotiveBookingPrice] = []
    @State private var automotiveFirstTimePrices: [AutomotiveBookingPrice] = []
    @State private var automotiveNonSubscriptionPrices: [AutomotiveBookingPrice] = []
    @State private var propertySize: PropertySize = .under5000
    @State private var realEstateUnder5000Prices: [RealEstateBookingPrice] = []
    @State private var realEstateAbove5000Prices: [RealEstateBookingPrice] = []
    
    // Search & Rescue specific state
    @State private var isVoluntaryMission: Bool = true
    @State private var searchRescueHourlyRate: Decimal = 25.0 // Fixed $25/hour per pilot
    @State private var sarAssignmentType: SARAssignmentType? = nil
    @State private var sarGovernmentAgency: GovernmentAgency? = nil
    @State private var usesBeaconProgram: Bool = false
    @State private var numberOfPilots: Int = 1
    
    // Credits for booking
    @State private var availableCredits: Decimal = 0
    @State private var creditsToUse: Decimal = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Group {
                    if currentStep == 1 {
                        CreateBookingStep1IndustryView(
                            selectedSpecialization: $selectedSpecialization,
                            onNext: {
                                if isStep1Valid {
                                    // Load subscription status when moving to next step
                                    Task {
                                        await checkSubscriptionAndBookingHistory()
                                    }
                                    currentStep = 2
                                }
                            }
                        )
                    } else if currentStep == 2 {
                        CreateBookingStep2DetailsView(
                            selectedLocation: $selectedLocation,
                            locationName: $locationName,
                            selectedDate: $selectedDate,
                            startTime: $startTime,
                            endTime: $endTime,
                            selectedSpecialization: $selectedSpecialization,
                            requiredMinimumRank: $requiredMinimumRank,
                            propertySize: $propertySize,
                            sarAssignmentType: $sarAssignmentType,
                            sarGovernmentAgency: $sarGovernmentAgency,
                            estimatedHours: $estimatedHours,
                            numberOfPilots: $numberOfPilots,
                            customerRole: authService.userProfile?.role,
                            onBack: {
                                currentStep = 1
                            },
                            onNext: {
                                if isStep2Valid {
                                    currentStep = 3
                                }
                            }
                        )
                    } else if currentStep == 3 {
                        CreateBookingStep3PaymentView(
                            description: $description,
                            paymentAmount: $paymentAmount,
                            estimatedHours: $estimatedHours,
                            selectedSpecialization: $selectedSpecialization,
                            requiredMinimumRank: $requiredMinimumRank,
                            hasAutomotiveSubscription: $hasAutomotiveSubscription,
                            isFirstAutomotiveBooking: $isFirstAutomotiveBooking,
                            automotiveSubscriptionPrices: automotiveSubscriptionPrices,
                            automotiveFirstTimePrices: automotiveFirstTimePrices,
                            automotiveNonSubscriptionPrices: automotiveNonSubscriptionPrices,
                            propertySize: propertySize,
                            realEstateUnder5000Prices: realEstateUnder5000Prices,
                            realEstateAbove5000Prices: realEstateAbove5000Prices,
                            isVoluntaryMission: $isVoluntaryMission,
                            sarAssignmentType: $sarAssignmentType,
                            sarGovernmentAgency: $sarGovernmentAgency,
                            usesBeaconProgram: $usesBeaconProgram,
                            customerRole: authService.userProfile?.role,
                            onBack: {
                                currentStep = 2
                            },
                            onCreate: {
                                // Navigate to confirmation page instead of creating booking directly
                                currentStep = 4
                            },
                            isLoading: bookingService.isLoading || paymentService.isLoading || isProcessingPayment || isLoadingSubscription,
                            isFormValid: isStep3Valid
                        )
                    } else {
                        // Step 4: Confirmation page
                        if let location = selectedLocation,
                           let specialization = selectedSpecialization {
                            CreateBookingStep4ConfirmView(
                                locationName: locationName,
                                selectedLocation: location,
                                selectedDate: selectedDate,
                                startTime: startTime,
                                endTime: endTime,
                                selectedSpecialization: specialization,
                                requiredMinimumRank: requiredMinimumRank,
                                description: description,
                                paymentAmount: getFinalPaymentAmount(),
                                estimatedHours: getEstimatedHours(),
                                isVoluntary: specialization == .searchRescue && isVoluntaryMission,
                                sarAssignmentType: sarAssignmentType,
                                sarGovernmentAgency: sarGovernmentAgency,
                                usesBeaconProgram: usesBeaconProgram,
                                numberOfPilots: numberOfPilots,
                                availableCredits: availableCredits,
                                creditsToUse: $creditsToUse,
                                onCreditsChanged: { newCredits in
                                    creditsToUse = newCredits
                                },
                                onBack: {
                                    currentStep = 3
                                },
                                onPay: createBooking,
                                isLoading: bookingService.isLoading || paymentService.isLoading || isProcessingPayment || isLoadingSubscription
                            )
                        }
                    }
                }
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if currentStep == 1 {
                            Button("Cancel") {
                                dismiss()
                            }
                        } else if currentStep == 2 {
                            Button("Cancel") {
                                dismiss()
                            }
                        } else if currentStep == 3 {
                            Button("Cancel") {
                                dismiss()
                            }
                        } else if currentStep == 4 {
                            Button("Cancel") {
                                dismiss()
                            }
                        } else {
                            Button("Back") {
                                currentStep -= 1
                            }
                        }
                    }
                }
                .alert("Error", isPresented: $showError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
                
                // Navigation to booking detail after animation
                // This will be handled by dismissing the sheet and navigating from parent view
            }
            .fullScreenCover(isPresented: $showSuccessAnimation) {
                if let booking = createdBooking {
                    BookingSuccessAnimationView(
                        createdBooking: booking,
                        shouldShowBookingDetail: Binding(
                            get: { shouldShowBookingDetail },
                            set: { newValue in
                                shouldShowBookingDetail = newValue
                                if newValue {
                                    // Dismiss the create booking view and navigate to detail
                                    dismiss()
                                }
                            }
                        )
                    )
                }
            }
            .onChange(of: shouldShowBookingDetail) { _, newValue in
                if newValue {
                    // Dismiss this view so parent can navigate
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            }
            .task {
                // Fetch available referral credits for the user
                await fetchAvailableCredits()
            }
        }
    }
    
    /// Fetches available referral credits for the current user
    private func fetchAvailableCredits() async {
        guard let currentUser = authService.currentUser else { return }
        do {
            let credits = try await referralService.getAvailableCredits(userId: currentUser.id)
            await MainActor.run {
                availableCredits = credits
            }
        } catch {
            print("Error fetching referral credits: \(error)")
            // Don't show error to user, just proceed without credits
        }
    }
    
    private var navigationTitle: String {
        switch currentStep {
        case 1: return "Create Booking"
        case 2: return "Booking Details"
        case 3: return "Payment"
        case 4: return "Confirm and Pay"
        default: return "Create Booking"
        }
    }
    
    private var isStep1Valid: Bool {
        selectedSpecialization != nil
    }
    
    private var isStep2Valid: Bool {
        guard selectedLocation != nil,
              !locationName.isEmpty else {
            return false
        }
        
        // For Automotive industry, validate start time is not later than noon
        if selectedSpecialization == .automotive {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: startTime)
            if hour > 12 {
                return false
            }
        }
        
        // For Search & Rescue, validate assignment type is selected
        if selectedSpecialization == .searchRescue {
            guard sarAssignmentType != nil else {
                return false
            }
            
            // For government clients, agency is also required
            if authService.userProfile?.role == .government {
                guard sarGovernmentAgency != nil else {
                    return false
                }
            }
        }
        
        return true
    }
    
    private var isStep3Valid: Bool {
        // Description is now optional, so we don't check it here
        
        // For Automotive industry, payment is fixed based on rank
        if selectedSpecialization == .automotive {
            return true // Payment is set automatically
        }
        
        // For Search & Rescue, all validation is done in Step 2
        if selectedSpecialization == .searchRescue {
            return true
        }
        
        // For other industries, validate payment input
        // Use default 2 hours for validation
        let defaultHours: Double = 2.0
        if paymentInputType == .totalPayment {
            guard !paymentAmount.isEmpty,
                  let total = Double(paymentAmount),
                  total > 0 else {
                return false
            }
            let hourlyRate = total / defaultHours
            return hourlyRate >= 25.0
        } else {
            guard !paymentAmount.isEmpty,
                  let rate = Double(paymentAmount),
                  rate >= 25.0 else {
                return false
            }
            return true
        }
    }
    
    private func checkSubscriptionAndBookingHistory() async {
        guard let currentUser = authService.currentUser else {
            hasAutomotiveSubscription = false
            isFirstAutomotiveBooking = true
            return
        }
        
        isLoadingSubscription = true
        
        // Handle Automotive bookings
        if selectedSpecialization == .automotive {
            // Check subscription
            do {
                if let subscription = try await subscriptionService.fetchCurrentSubscription(customerId: currentUser.id) {
                    hasAutomotiveSubscription = subscription.isActive
                } else {
                    hasAutomotiveSubscription = false
                }
            } catch {
                print("Error checking subscription: \(error)")
                hasAutomotiveSubscription = false
            }
            
            // Check if this is first Automotive booking by querying database directly
            do {
                let supabase = SupabaseClient.shared.client
                let bookings: [Booking] = try await supabase
                    .from("bookings")
                    .select()
                    .eq("customer_id", value: currentUser.id.uuidString)
                    .eq("specialization", value: BookingSpecialization.automotive.rawValue)
                    .execute()
                    .value
                
                isFirstAutomotiveBooking = bookings.isEmpty
            } catch {
                print("Error checking booking history: \(error)")
                // Assume first booking if we can't check
                isFirstAutomotiveBooking = true
            }
            
            // Fetch automotive booking prices from Stripe
            let pricesResult = await subscriptionService.fetchAutomotiveBookingPrices()
            automotiveSubscriptionPrices = pricesResult.subscriptionPrices
            automotiveFirstTimePrices = pricesResult.firstTimePrices
            automotiveNonSubscriptionPrices = pricesResult.nonSubscriptionPrices
        }
        // Handle Real Estate bookings
        else if selectedSpecialization == .realEstate {
            // Fetch real estate booking prices from Stripe
            let pricesResult = await subscriptionService.fetchRealEstateBookingPrices()
            realEstateUnder5000Prices = pricesResult.under5000Prices
            realEstateAbove5000Prices = pricesResult.above5000Prices
        }
        
        isLoadingSubscription = false
    }
    
    private func getEstimatedHours() -> Double {
        // Use 5 hours for automotive bookings
        if selectedSpecialization == .automotive {
            return 5.0
        }
        // For S&R, use the user-selected hours
        if selectedSpecialization == .searchRescue {
            return Double(estimatedHours) ?? 2.0
        }
        // Default for other industries
        return 2.0
    }
    
    private func getFinalPaymentAmount() -> Decimal {
        guard let specialization = selectedSpecialization else {
            return Decimal(0)
        }
        
        if specialization == .automotive {
            // For Automotive, use fixed pricing based on rank
            return getAutomotivePrice(for: requiredMinimumRank)
        } else if specialization == .realEstate {
            // For Real Estate, use fixed pricing based on rank and property size
            return getRealEstatePrice(for: requiredMinimumRank, propertySize: propertySize)
        } else if specialization == .searchRescue {
            // For Search & Rescue, calculate: hourlyRate × hours × numberOfPilots
            if isVoluntaryMission {
                return Decimal(0)
            }
            let hourlyRate = getSARHourlyRate(for: requiredMinimumRank)
            let hours = Double(estimatedHours) ?? 2.0
            let totalAmount = hourlyRate * Decimal(hours) * Decimal(numberOfPilots)
            return totalAmount
        } else {
            // For other industries, use user-entered payment
            if let paymentValue = Double(paymentAmount) {
                return Decimal(paymentValue)
            }
            return Decimal(0)
        }
    }
    
    /// Get S&R hourly rate based on rank: 25, 35, 45, 55, 65
    private func getSARHourlyRate(for rank: Int) -> Decimal {
        switch rank {
        case 4: return Decimal(65) // Captain
        case 3: return Decimal(55) // Commander
        case 2: return Decimal(45) // Lieutenant
        case 1: return Decimal(35) // Sub Lieutenant
        default: return Decimal(25) // Ensign
        }
    }
    
    private func getRealEstatePrice(for rank: Int, propertySize: PropertySize) -> Decimal {
        let prices = propertySize == .under5000 ? realEstateUnder5000Prices : realEstateAbove5000Prices
        
        if let priceInfo = prices.first(where: { $0.rankTier == rank }) {
            return priceInfo.amountInDollars
        }
        
        // Fallback prices if Stripe prices not loaded (shouldn't happen in normal flow)
        // These are placeholder values - actual prices come from Stripe
        return Decimal(500)
    }
    
    private func createBooking() {
        let isUITest = ProcessInfo.processInfo.arguments.contains("UI_TESTING") || ProcessInfo.processInfo.environment["UITEST_MODE"] == "1"
        
        // In UI test/demo mode, create a lightweight local booking to keep flows offline
        if isUITest || DemoModeManager.shared.isDemoModeEnabled {
            let booking = Booking(
                id: UUID(),
                customerId: authService.activeUserId ?? UUID(),
                pilotId: nil,
                locationLat: selectedLocation?.latitude ?? 0,
                locationLng: selectedLocation?.longitude ?? 0,
                locationName: locationName.isEmpty ? "Test Location" : locationName,
                scheduledDate: selectedDate,
                endDate: endTime,
                specialization: selectedSpecialization,
                description: description,
                paymentAmount: getFinalPaymentAmount(),
                tipAmount: nil,
                status: .available,
                createdAt: Date(),
                estimatedFlightHours: getEstimatedHours(),
                pilotRated: nil,
                customerRated: nil,
                requiredMinimumRank: requiredMinimumRank
            )
            createdBooking = booking
            onBookingCreated?(booking)
            showSuccessAnimation = true
            return
        }
        
        guard let currentUser = authService.currentUser,
              let location = selectedLocation,
              let specialization = selectedSpecialization else {
            errorMessage = "Please fill in all fields correctly"
            showError = true
            return
        }
        
        // Use default 2 hours for estimated flight hours
        let hours: Double = getEstimatedHours()
        
        // Calculate payment amount
        let payment: Decimal = getFinalPaymentAmount()
        
        // For Search & Rescue, payment is handled post-completion, so $0 is valid
        if payment == 0 && specialization != .searchRescue {
            errorMessage = "Please enter a valid payment amount"
            showError = true
            return
        }
        
        // For Search & Rescue
        if specialization == .searchRescue {
            // If voluntary mission, create booking without payment
            if isVoluntaryMission {
                Task {
                    await createSearchRescueBooking(
                        customerId: currentUser.id,
                        location: location,
                        hours: hours
                    )
                }
            } else {
                // For paid S&R missions, process payment via Stripe first
                Task {
                    await processPaymentAndCreateSARBooking(
                        customerId: currentUser.id,
                        paymentAmount: payment,
                        location: location,
                        hours: hours
                    )
                }
            }
            return
        }
        
        // Process payment first, then create booking
        Task {
            await processPaymentAndCreateBooking(
                customerId: currentUser.id,
                paymentAmount: payment,
                location: location,
                specialization: specialization,
                hours: hours
            )
        }
    }
    
    private func getAutomotivePrice(for rank: Int) -> Decimal {
        if hasAutomotiveSubscription {
            // Client has active subscription: use subscription-tier Stripe prices
            if let priceInfo = automotiveSubscriptionPrices.first(where: { $0.rankTier == rank }) {
                return priceInfo.amountInDollars
            }
            // Fallback prices if Stripe prices not loaded
            switch rank {
            case 4: return Decimal(4000) // Captain
            case 3: return Decimal(3800) // Commander
            case 2: return Decimal(3600) // Lieutenant
            case 1: return Decimal(3400) // Sub Lieutenant
            default: return Decimal(3400) // Ensign (default to Sub Lieutenant price)
            }
        } else if isFirstAutomotiveBooking {
            // First-time booking without subscription: use first-time Stripe prices
            if let priceInfo = automotiveFirstTimePrices.first(where: { $0.rankTier == rank }) {
                return priceInfo.amountInDollars
            }
            // Fallback prices if Stripe prices not loaded
            switch rank {
            case 4: return Decimal(4000) // Captain
            case 3: return Decimal(3800) // Commander
            case 2: return Decimal(3600) // Lieutenant
            case 1: return Decimal(3400) // Sub Lieutenant
            default: return Decimal(3400) // Ensign (default to Sub Lieutenant price)
            }
        } else {
            // Returning user without subscription: use non-subscription Stripe prices
            if let priceInfo = automotiveNonSubscriptionPrices.first(where: { $0.rankTier == rank }) {
                return priceInfo.amountInDollars
            }
            // Fallback prices if Stripe prices not loaded
            switch rank {
            case 4: return Decimal(7000) // Captain
            case 3: return Decimal(6800) // Commander
            case 2: return Decimal(6600) // Lieutenant
            case 1: return Decimal(6400) // Sub Lieutenant
            default: return Decimal(6400) // Ensign (default to Sub Lieutenant price)
            }
        }
    }
    
    /// Get the hourly rate for S&R missions based on Beacon selection and rank
    private func getSearchRescueHourlyRate() -> Decimal {
        let isGovernment = authService.userProfile?.role == .government
        
        if isGovernment && usesBeaconProgram {
            // Government + Beacon = fixed $25/hour
            return Decimal(25)
        } else {
            // Non-Beacon = rank-based pricing: 25, 35, 45, 55, 65
            return getSARHourlyRate(for: requiredMinimumRank)
        }
    }
    
    /// Create a Search & Rescue booking without upfront payment
    /// Payment is calculated and collected after mission completion based on hours worked and pilots involved
    private func createSearchRescueBooking(
        customerId: UUID,
        location: CLLocationCoordinate2D,
        hours: Double
    ) async {
        isProcessingPayment = true
        
        do {
            // Combine date with start time
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
            let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
            
            var startDateTimeComponents = DateComponents()
            startDateTimeComponents.year = dateComponents.year
            startDateTimeComponents.month = dateComponents.month
            startDateTimeComponents.day = dateComponents.day
            startDateTimeComponents.hour = startTimeComponents.hour
            startDateTimeComponents.minute = startTimeComponents.minute
            
            let startDateTime = calendar.date(from: startDateTimeComponents) ?? selectedDate
            
            // Use provided end time if available, otherwise calculate from start time + estimated hours
            var endDateTime: Date
            if let providedEndTime = endTime {
                let endTimeComponents = calendar.dateComponents([.hour, .minute], from: providedEndTime)
                var endDateTimeComponents = DateComponents()
                endDateTimeComponents.year = dateComponents.year
                endDateTimeComponents.month = dateComponents.month
                endDateTimeComponents.day = dateComponents.day
                endDateTimeComponents.hour = endTimeComponents.hour
                endDateTimeComponents.minute = endTimeComponents.minute
                endDateTime = calendar.date(from: endDateTimeComponents) ?? startDateTime
            } else {
                // Calculate end time from start time + estimated hours
                endDateTime = calendar.date(byAdding: .hour, value: Int(hours), to: startDateTime) ?? startDateTime
            }
            
            // Get the appropriate hourly rate based on Beacon selection
            let hourlyRate = isVoluntaryMission ? Decimal(0) : getSearchRescueHourlyRate()
            
            // Create Search & Rescue booking without payment (payment happens after completion)
            let newBooking = try await bookingService.createSearchRescueBooking(
                customerId: customerId,
                location: location,
                locationName: locationName.isEmpty ? "Selected Location" : locationName,
                scheduledDate: startDateTime,
                endDate: endDateTime,
                description: description.isEmpty ? nil : description,
                isVoluntary: isVoluntaryMission,
                hourlyRate: hourlyRate,
                estimatedFlightHours: hours,
                assignmentType: sarAssignmentType,
                governmentAgency: sarGovernmentAgency,
                usesBeaconProgram: usesBeaconProgram,
                requiredMinimumRank: requiredMinimumRank,
                numberOfPilots: numberOfPilots
            )
            
            await MainActor.run {
                createdBooking = newBooking
                onBookingCreated?(newBooking)
                showSuccessAnimation = true
                isProcessingPayment = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isProcessingPayment = false
            }
        }
    }
    
    /// Process payment via Stripe and then create a paid S&R booking
    private func processPaymentAndCreateSARBooking(
        customerId: UUID,
        paymentAmount: Decimal,
        location: CLLocationCoordinate2D,
        hours: Double
    ) async {
        isProcessingPayment = true
        
        do {
            // Generate transfer group (using booking ID that we'll create)
            let bookingId = UUID()
            let transferGroup = "booking_\(bookingId.uuidString)"
            
            // Create PaymentIntent with credits if applicable
            let paymentIntentResponse = try await paymentService.createPaymentIntentWithCredits(
                amount: paymentAmount,
                creditsToUse: creditsToUse,
                currency: "usd",
                customerId: customerId,
                transferGroup: transferGroup
            )
            
            // Present PaymentSheet
            let paymentResult = try await paymentService.presentPaymentSheet(
                paymentIntentClientSecret: paymentIntentResponse.clientSecret,
                customerId: paymentIntentResponse.customerId,
                customerEphemeralKeySecret: paymentIntentResponse.ephemeralKeySecret
            )
            
            switch paymentResult {
            case .completed:
                // Payment successful, now create the booking
                let calendar = Calendar.current
                let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
                let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
                
                var startDateTimeComponents = DateComponents()
                startDateTimeComponents.year = dateComponents.year
                startDateTimeComponents.month = dateComponents.month
                startDateTimeComponents.day = dateComponents.day
                startDateTimeComponents.hour = startTimeComponents.hour
                startDateTimeComponents.minute = startTimeComponents.minute
                
                let startDateTime = calendar.date(from: startDateTimeComponents) ?? selectedDate
                
                var endDateTime: Date
                if let providedEndTime = endTime {
                    let endTimeComponents = calendar.dateComponents([.hour, .minute], from: providedEndTime)
                    var endDateTimeComponents = DateComponents()
                    endDateTimeComponents.year = dateComponents.year
                    endDateTimeComponents.month = dateComponents.month
                    endDateTimeComponents.day = dateComponents.day
                    endDateTimeComponents.hour = endTimeComponents.hour
                    endDateTimeComponents.minute = endTimeComponents.minute
                    endDateTime = calendar.date(from: endDateTimeComponents) ?? startDateTime
                } else {
                    endDateTime = calendar.date(byAdding: .hour, value: Int(hours), to: startDateTime) ?? startDateTime
                }
                
                let hourlyRate = getSearchRescueHourlyRate()
                
                // Create Search & Rescue booking with payment info
                let newBooking = try await bookingService.createSearchRescueBooking(
                    customerId: customerId,
                    location: location,
                    locationName: locationName.isEmpty ? "Selected Location" : locationName,
                    scheduledDate: startDateTime,
                    endDate: endDateTime,
                    description: description.isEmpty ? nil : description,
                    isVoluntary: false,
                    hourlyRate: hourlyRate,
                    estimatedFlightHours: hours,
                    assignmentType: sarAssignmentType,
                    governmentAgency: sarGovernmentAgency,
                    usesBeaconProgram: usesBeaconProgram,
                    requiredMinimumRank: requiredMinimumRank,
                    numberOfPilots: numberOfPilots
                )
                
                await MainActor.run {
                    createdBooking = newBooking
                    onBookingCreated?(newBooking)
                    showSuccessAnimation = true
                    isProcessingPayment = false
                }
                
            case .cancelled:
                await MainActor.run {
                    isProcessingPayment = false
                }
                
            case .failed(let error):
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isProcessingPayment = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isProcessingPayment = false
            }
        }
    }
    
    private func processPaymentAndCreateBooking(
        customerId: UUID,
        paymentAmount: Decimal,
        location: CLLocationCoordinate2D,
        specialization: BookingSpecialization,
        hours: Double
    ) async {
        isProcessingPayment = true
        
        do {
            // Generate transfer group (using booking ID that we'll create)
            let bookingId = UUID()
            let transferGroup = "booking_\(bookingId.uuidString)"
            
            // Create PaymentIntent with credits if applicable
            let paymentIntentResponse = try await paymentService.createPaymentIntentWithCredits(
                amount: paymentAmount,
                creditsToUse: creditsToUse,
                currency: "usd",
                customerId: customerId,
                transferGroup: transferGroup
            )
            
            // Present PaymentSheet
            let paymentResult = try await paymentService.presentPaymentSheet(
                paymentIntentClientSecret: paymentIntentResponse.clientSecret,
                customerId: paymentIntentResponse.customerId,
                customerEphemeralKeySecret: paymentIntentResponse.ephemeralKeySecret
            )
            
            switch paymentResult {
            case .completed:
                // Payment successful, get charge_id from PaymentIntent
                let chargeId = try await getChargeId(from: paymentIntentResponse.paymentIntentId)
                
                // Combine date with start time
                let calendar = Calendar.current
                let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
                let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
                
                var startDateTimeComponents = DateComponents()
                startDateTimeComponents.year = dateComponents.year
                startDateTimeComponents.month = dateComponents.month
                startDateTimeComponents.day = dateComponents.day
                startDateTimeComponents.hour = startTimeComponents.hour
                startDateTimeComponents.minute = startTimeComponents.minute
                
                let startDateTime = calendar.date(from: startDateTimeComponents) ?? selectedDate
                
                // Use provided end time if available, otherwise calculate from start time + estimated hours
                var endDateTime: Date
                if let providedEndTime = endTime {
                    let endTimeComponents = calendar.dateComponents([.hour, .minute], from: providedEndTime)
                    var endDateTimeComponents = DateComponents()
                    endDateTimeComponents.year = dateComponents.year
                    endDateTimeComponents.month = dateComponents.month
                    endDateTimeComponents.day = dateComponents.day
                    endDateTimeComponents.hour = endTimeComponents.hour
                    endDateTimeComponents.minute = endTimeComponents.minute
                    endDateTime = calendar.date(from: endDateTimeComponents) ?? startDateTime
                } else {
                    // Calculate end time from start time + estimated hours
                    endDateTime = calendar.date(byAdding: .hour, value: Int(hours), to: startDateTime) ?? startDateTime
                    // Add minutes for fractional hours
                    let fractionalHours = hours - Double(Int(hours))
                    if fractionalHours > 0 {
                        let minutes = Int(fractionalHours * 60)
                        endDateTime = calendar.date(byAdding: .minute, value: minutes, to: endDateTime) ?? endDateTime
                    }
                }
                
                // Create booking with payment info
                let newBooking = try await bookingService.createBooking(
                    customerId: customerId,
                    location: location,
                    locationName: locationName.isEmpty ? "Selected Location" : locationName,
                    scheduledDate: startDateTime,
                    endDate: endDateTime,
                    specialization: specialization,
                    description: description.isEmpty ? nil : description,
                    paymentAmount: paymentAmount,
                    estimatedFlightHours: hours,
                    requiredMinimumRank: requiredMinimumRank,
                    paymentIntentId: paymentIntentResponse.paymentIntentId,
                    chargeId: chargeId
                )
                
                // Apply booking credits if used (deduct from user's balance and update booking)
                if creditsToUse > 0 {
                    let originalAmountCents = paymentIntentResponse.originalAmount ?? Int(NSDecimalNumber(decimal: paymentAmount * 100).intValue)
                    let finalAmountCents = paymentIntentResponse.finalAmount ?? Int(NSDecimalNumber(decimal: (paymentAmount - creditsToUse) * 100).intValue)
                    
                    let _ = try await paymentService.applyBookingCredits(
                        bookingId: newBooking.id,
                        customerId: customerId,
                        creditsUsed: creditsToUse,
                        originalAmount: originalAmountCents,
                        finalAmount: finalAmountCents
                    )
                }
                
                isProcessingPayment = false
                // Store the created booking for navigation
                createdBooking = newBooking
                // Call completion handler to notify parent
                onBookingCreated?(newBooking)
                // Show animated success flow
                showSuccessAnimation = true
                // After animation, navigate to booking detail
                // The animation will set shouldShowBookingDetail = true
                
            case .cancelled:
                isProcessingPayment = false
                errorMessage = "Payment was cancelled"
                showError = true
                
            case .failed(let error):
                isProcessingPayment = false
                errorMessage = "Payment failed: \(error.localizedDescription)"
                showError = true
            }
        } catch {
            isProcessingPayment = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func getChargeId(from paymentIntentId: String) async throws -> String {
        let supabase = SupabaseClient.shared.client
        
        struct PaymentIntentDetails: Codable {
            let charge_id: String
        }
        
        let response: PaymentIntentDetails = try await supabase.functions
            .invoke("get-payment-intent", options: FunctionInvokeOptions(
                body: ["payment_intent_id": paymentIntentId]
            ))
        
        return response.charge_id
    }
}

// MARK: - Customer Booking Detail View

struct CustomerBookingDetailView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    @StateObject private var ratingService = RatingService()
    @StateObject private var profileService = ProfileService()
    let booking: Booking
    @State private var currentBooking: Booking
    @State private var region: MKCoordinateRegion
    @State private var showCancelAlert = false
    @State private var showCancelSuccess = false
    @State private var showRatingSheet = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var pilotName = "Pilot"
    @State private var pilotProfile: UserProfile?
    @State private var pilotRating: Double? = nil
    @State private var showMessageSheet = false
    @State private var showEditSheet = false
    @State private var showFinishBookingAlert = false
    @State private var showCompletionConfirmation = false
    @State private var showCompletionSuccess = false
    @State private var showSearchRescueCompletion = false
    @State private var showExtendBookingSheet = false
    @State private var showCreateDisputeSheet = false
    @Environment(\.dismiss) var dismiss

    // Check if pilot info should be visible (always show if pilot is assigned)
    private var shouldShowPilotInfo: Bool {
        return currentBooking.pilotId != nil
    }

    init(booking: Booking) {
        self.booking = booking
        _currentBooking = State(initialValue: booking)
        _region = State(initialValue: MKCoordinateRegion(
            center: booking.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Expiration Warning Banner
                if currentBooking.status == .available,
                   let expiresAt = currentBooking.expiresAt,
                   expiresAt.timeIntervalSinceNow < 24 * 60 * 60 && expiresAt.timeIntervalSinceNow > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundColor(.orange)
                        Text("This booking expires soon")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(expiresAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Map
                Map(coordinateRegion: .constant(region), annotationItems: [currentBooking]) { booking in
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
                    
                    Text(currentBooking.locationName)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // Description
                if let description = booking.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Description", systemImage: "text.alignleft")
                            .font(.headline)
                        
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
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
                    
                    StatusBadge(status: currentBooking.status)
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
                
                // Pilot Info Section (for accepted/staffed/inProgress/completed bookings)
                if (currentBooking.status == .accepted || currentBooking.status == .staffed || currentBooking.status == .inProgress || currentBooking.status == .completed), currentBooking.pilotId != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Pilot", systemImage: "airplane.circle.fill")
                            .font(.headline)
                        
                        if shouldShowPilotInfo {
                            // Show full pilot info
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
                                
                                // Pilot Callsign
                                VStack(alignment: .leading, spacing: 4) {
                                    if let callSign = pilotProfile?.callSign, !callSign.isEmpty {
                                        Text("@\(callSign)")
                                            .font(.headline)
                                    } else {
                                        Text("Pilot")
                                            .font(.headline)
                                    }
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
                        // Pilot info will always show when assigned (no 24-hour constraint)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                }
                
                // Tip Display
                if let tip = currentBooking.tipAmount, tip > 0 {
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
                if currentBooking.status == .completed || currentBooking.tipAmount != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Total Payment", systemImage: "creditcard.fill")
                            .font(.headline)
                        
                        let total = currentBooking.paymentAmount + (currentBooking.tipAmount ?? 0)
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
                // Hide these buttons when waiting for completion confirmation
                // Show buttons only if: status is available OR (status is accepted AND neither party has completed)
                let showActionButtons = currentBooking.status == .available || 
                    (currentBooking.status == .accepted && 
                     currentBooking.customerCompleted != true && 
                     currentBooking.pilotCompleted != true)
                
                if showActionButtons {
                    VStack(spacing: 12) {
                        // Finish Booking Button (for accepted bookings)
                        if currentBooking.status == .accepted {
                            CustomButton(
                                title: "Finish Booking",
                                action: { showFinishBookingAlert = true },
                                style: .primary,
                                isLoading: bookingService.isLoading
                            )
                        }
                        
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
                
                // Show waiting message if customer has completed but pilot hasn't
                if currentBooking.status == .accepted && currentBooking.customerCompleted == true && currentBooking.pilotCompleted != true {
                    VStack(spacing: 12) {
                        Text("Booking finish is waiting to be confirmed by pilot")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                
                // Completion Confirmation (when pilot has marked as finished)
                if currentBooking.status == .accepted && currentBooking.pilotCompleted == true && currentBooking.customerCompleted != true {
                    VStack(spacing: 12) {
                        Text("Pilot has marked this booking as finished")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        
                        // For S&R bookings, show completion sheet with hours entry
                        if currentBooking.isSearchRescueCrewBooking {
                            CustomButton(
                                title: "Complete Mission",
                                action: { showSearchRescueCompletion = true },
                                style: .primary,
                                isLoading: bookingService.isLoading
                            )
                        } else {
                            CustomButton(
                                title: "Confirm Completion",
                                action: { showCompletionConfirmation = true },
                                style: .primary,
                                isLoading: bookingService.isLoading
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // For Search & Rescue - allow customer to complete at any time when pilots have joined
                if currentBooking.isSearchRescueCrewBooking &&
                   currentBooking.status == .accepted &&
                   currentBooking.customerCompleted != true {
                    VStack(spacing: 12) {
                        Text("When your mission is complete, enter the hours worked to calculate payment")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        CustomButton(
                            title: "Complete Mission",
                            action: { showSearchRescueCompletion = true },
                            style: .primary,
                            isLoading: bookingService.isLoading
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Update Date button (for available bookings with expiration)
                if currentBooking.status == .available && currentBooking.expiresAt != nil {
                    Button(action: { showExtendBookingSheet = true }) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                            Text("Update Date")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                // Rate Pilot Button (for completed bookings)
                if currentBooking.status == .completed && currentBooking.customerRated != true {
                    CustomButton(
                        title: "Rate Pilot",
                        action: { showRatingSheet = true },
                        style: .primary
                    )
                    .padding(.horizontal)
                }

                // File Dispute button (for completed bookings)
                if currentBooking.status == .completed {
                    Button(action: { showCreateDisputeSheet = true }) {
                        HStack {
                            Image(systemName: "exclamationmark.bubble.fill")
                            Text("File Dispute")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            await refreshBooking()
            if currentBooking.pilotId != nil {
                await loadPilotProfile()
            }
        }
        .navigationTitle("Booking Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Cancel Booking", isPresented: $showCancelAlert) {
            Button("No", role: .cancel) {}
            Button("Yes", role: .destructive) {
                cancelBooking()
            }
        } message: {
            let cancellationMessage: String
            if let scheduledDate = currentBooking.scheduledDate {
                let now = Date()
                let timeUntilBooking = scheduledDate.timeIntervalSince(now)
                let hoursUntilBooking = timeUntilBooking / 3600
                
                if hoursUntilBooking <= 48 && hoursUntilBooking >= 0 {
                    // Within 48 hours - show refund warning
                    if currentBooking.status == .accepted {
                        cancellationMessage = "A pilot has already accepted this booking. Are you sure you want to cancel? This will notify the pilot.\n\n⚠️ Warning: Cancelling within 48 hours of the scheduled booking time will result in only half of the original payment being refunded."
                    } else {
                        cancellationMessage = "Are you sure you want to cancel this booking?\n\n⚠️ Warning: Cancelling within 48 hours of the scheduled booking time will result in only half of the original payment being refunded."
                    }
                } else {
                    // More than 48 hours away - normal cancellation
                    if currentBooking.status == .accepted {
                        cancellationMessage = "A pilot has already accepted this booking. Are you sure you want to cancel? This will notify the pilot."
                    } else {
                        cancellationMessage = "Are you sure you want to cancel this booking?"
                    }
                }
            } else {
                // No scheduled date - normal cancellation
                if currentBooking.status == .accepted {
                    cancellationMessage = "A pilot has already accepted this booking. Are you sure you want to cancel? This will notify the pilot."
                } else {
                    cancellationMessage = "Are you sure you want to cancel this booking?"
                }
            }
            return Text(cancellationMessage)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Booking Cancelled", isPresented: $showCancelSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your booking has been cancelled successfully.")
        }
        .alert("Finish Booking", isPresented: $showFinishBookingAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Finish") {
                finishBooking()
            }
        } message: {
            Text("Mark this booking as finished? The pilot will be notified to confirm completion.")
        }
        .alert("Confirm Completion", isPresented: $showCompletionConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm") {
                confirmCompletion()
            }
        } message: {
            Text("Confirm that this booking is complete? This will finalize the booking and allow you to rate the pilot.")
        }
        .sheet(isPresented: $showRatingSheet) {
            RatingView(
                userName: pilotName,
                isPilotRatingCustomer: false,
                onRatingSubmitted: { rating, comment, tip in
                    submitRating(rating: rating, comment: comment, tip: tip)
                },
                customTitle: currentBooking.status == .completed ? "Booking is completed" : nil,
                paymentAmount: currentBooking.paymentAmount,
                userRating: pilotRating
            )
        }
        .sheet(isPresented: $showMessageSheet) {
            MessageView(
                customerProfile: pilotProfile,
                booking: currentBooking
            )
        }
        .sheet(isPresented: $showEditSheet) {
            EditBookingView(booking: currentBooking)
        }
        .sheet(isPresented: $showSearchRescueCompletion) {
            SearchRescueCompletionView(booking: currentBooking) {
                Task {
                    await refreshBooking()
                }
            }
        }
        .sheet(isPresented: $showExtendBookingSheet) {
            ExtendBookingView(booking: currentBooking) {
                Task {
                    await refreshBooking()
                }
            }
        }
        .sheet(isPresented: $showCreateDisputeSheet) {
            CreateDisputeView(bookingId: currentBooking.id)
        }
        .task {
            // Load pilot profile and refresh booking
            await loadPilotProfile()
            await refreshBooking()
        }
        .onAppear {
            // Refresh booking when view appears to get latest status
            Task {
                await refreshBooking()
            }
        }
    }
    
    private func refreshBooking() async {
        do {
            let updatedBooking = try await bookingService.getBooking(bookingId: booking.id)
            currentBooking = updatedBooking
        } catch {
            // Ignore NSURLErrorCancelled (-999) - this is a benign cancellation during view updates
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            print("Error refreshing booking: \(error)")
        }
    }
    
    private func loadPilotProfile() async {
        guard let pilotId = currentBooking.pilotId else { return }
        
        // Try to get sample pilot profile first (for demo)
        if let sampleProfile = profileService.getSamplePilotProfile(pilotId: pilotId) {
            pilotProfile = sampleProfile
            // Use only callsign for customer-facing display to maintain pilot privacy
            pilotName = sampleProfile.callSign ?? "Pilot"
        } else {
            // Fallback to real profile fetch
        do {
            pilotProfile = try await profileService.getProfile(userId: pilotId)
            // Use only callsign for customer-facing display to maintain pilot privacy
            pilotName = pilotProfile?.callSign ?? "Pilot"
        } catch {
            // Ignore NSURLErrorCancelled (-999) - benign cancellation during view updates
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            print("Error loading pilot profile: \(error)")
            pilotName = "Pilot"
            }
        }
        
        // Fetch pilot rating
        let ratingService = RatingService()
        do {
            if let ratingSummary = try await ratingService.getUserRatingSummary(userId: pilotId) {
                pilotRating = ratingSummary.averageRating
            }
        } catch {
            // Ignore NSURLErrorCancelled (-999) - benign cancellation during view updates
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            print("Error loading pilot rating: \(error)")
        }
    }
    
    private func cancelBooking() {
        Task {
            do {
                try await bookingService.cancelBooking(bookingId: currentBooking.id)
                showCancelSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func submitRating(rating: Int, comment: String?, tip: Decimal?) {
        guard let currentUser = authService.currentUser,
              let pilotId = currentBooking.pilotId else { return }
        
        Task {
            do {
                // Submit rating
                try await ratingService.submitRating(
                    bookingId: currentBooking.id,
                    fromUserId: currentUser.id,
                    toUserId: pilotId,
                    rating: rating,
                    comment: comment
                )
                
                // Add tip if provided
                if let tipAmount = tip {
                    try await bookingService.addTip(bookingId: currentBooking.id, tipAmount: tipAmount)
                    
                    // If booking is already completed, we need to create a transfer for the tip
                    // For now, tip is stored and will be included in balance display
                    // In production, you might want to create an additional transfer
                }
                
                // Mark as rated
                try await bookingService.markRatingStatus(
                    bookingId: currentBooking.id,
                    isPilot: false,
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
    
    private func finishBooking() {
        Task {
            do {
                let isCompleted = try await bookingService.markBookingCompletion(bookingId: currentBooking.id, isPilot: false)
                
                // Refresh booking to get latest status
                await refreshBooking()
                
                if isCompleted {
                    // Both parties confirmed, booking is completed
                    showCompletionSuccess = true
                } else {
                    // Waiting for pilot confirmation
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
                let isCompleted = try await bookingService.markBookingCompletion(bookingId: currentBooking.id, isPilot: false)
                
                // Refresh booking to get latest status
                await refreshBooking()
                
                if isCompleted {
                    // Both parties confirmed, booking is completed - show rating sheet directly
                    showCompletionSuccess = true
                    showRatingSheet = true
                }
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
    @State private var showIndustryWarning = false
    @ObservedObject private var configService = BookingConfigService.shared
    
    init(booking: Booking) {
        self.booking = booking
        _locationName = State(initialValue: booking.locationName)
        _selectedLocation = State(initialValue: CLLocationCoordinate2D(latitude: booking.locationLat, longitude: booking.locationLng))
        _selectedDate = State(initialValue: booking.scheduledDate ?? Date())
        _startTime = State(initialValue: booking.scheduledDate ?? Date())
        _endTime = State(initialValue: booking.endDate ?? Date())
        _selectedSpecialization = State(initialValue: booking.specialization)
        _requiredMinimumRank = State(initialValue: booking.requiredMinimumRank ?? 0)
        _description = State(initialValue: booking.description ?? "")
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
                            Text("Pilot Rank")
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
                                    handleSpecializationSelection(specialization)
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
            .alert("Coming Soon", isPresented: $showIndustryWarning) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(configService.config.comingSoonMessage)
            }
            .task { await configService.ensureConfigLoaded() }
        }
    }
    
    private func handleSpecializationSelection(_ specialization: BookingSpecialization) {
        // Check if this is a supported industry
        if configService.config.isSpecializationEnabled(specialization, forEditing: true) {
            // Toggle selection: if already selected, deselect it
            if selectedSpecialization == specialization {
                selectedSpecialization = nil
            } else {
                selectedSpecialization = specialization
            }
        } else {
            // Show warning for unsupported industries
            showIndustryWarning = true
            // Don't select unsupported industries
        }
    }

    private var isFormValid: Bool {
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
                    description: description.isEmpty ? nil : description,
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

// MARK: - Buzz Subscription Promotion Card

enum BundlePackage: String, Identifiable {
    case auto
    case realEstate
    
    var id: String { rawValue }
}

struct BuzzBundlesPromotionCard: View {
    let onDismiss: () -> Void
    let onSelectBundle: (BundlePackage) -> Void
    @State private var showBundlePage = false
    
    var body: some View {
        Button(action: {
            showBundlePage = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                    
                    Text("Buzz Subscription")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                }
                
                Text("Discover our premium flight packages for easier and cheaper booking!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Easier and cheaper booking price")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Dedicated customer service")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Premium booking experience")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Spacer()
                    Text("Explore Packages →")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showBundlePage) {
            ClientBundlePage { bundle in
                showBundlePage = false
                onSelectBundle(bundle)
            }
        }
    }
}

// MARK: - Client Bundle Page

struct ClientBundlePage: View {
    @Environment(\.dismiss) var dismiss
    let onSelectBundle: (BundlePackage) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                        
                        Text("Buzz Subscription")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Choose from our premium packages designed to make your booking experience easier and more affordable. More are coming soon!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // Bundle Cards
                    VStack(spacing: 16) {
                        // Automotive Bundle Card
                        Button(action: {
                            onSelectBundle(.auto)
                        }) {
                            BundleCard(
                                icon: "car.circle.fill",
                                title: "Buzz Auto",
                                description: "Perfect for car dealerships. Get up to 50 cinematic videos per month with dedicated drone & pilot access.",
                                color: .blue
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Buzz Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Bundle Card

struct BundleCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(color)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(alignment: .center, spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("Easier booking")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                HStack(alignment: .center, spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("Better pricing")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                HStack(alignment: .center, spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("Premium service")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 2)
        )
    }
}
