//
//  CreateBookingStep3PaymentView.swift
//  Buzz
//
//  Created for Payment step in booking flow
//

import SwiftUI

struct CreateBookingStep3PaymentView: View {
    @Binding var description: String
    @Binding var paymentAmount: String
    @Binding var estimatedHours: String
    @Binding var selectedSpecialization: BookingSpecialization?
    @Binding var requiredMinimumRank: Int
    @Binding var hasAutomotiveSubscription: Bool
    @Binding var isFirstAutomotiveBooking: Bool
    let automotiveSubscriptionPrices: [AutomotiveBookingPrice]
    let automotiveFirstTimePrices: [AutomotiveBookingPrice]
    let automotiveNonSubscriptionPrices: [AutomotiveBookingPrice]
    let propertySize: PropertySize
    let realEstateUnder5000Prices: [RealEstateBookingPrice]
    let realEstateAbove5000Prices: [RealEstateBookingPrice]
    
    let onBack: () -> Void
    let onCreate: () -> Void
    let isLoading: Bool
    let isFormValid: Bool
    
    @State private var hourlyRateInput = ""
    @State private var totalPaymentInput = ""
    @State private var showMinRateWarning = false
    @State private var paymentInputType: PaymentInputType = .totalPayment
    @State private var showSubscription = false
    @StateObject private var subscriptionService = SubscriptionService()
    
    private let minimumHourlyRate: Double = 25.0
    
    // Automotive product ID from Stripe (for subscription plans)
    private let automotiveProductId = "prod_TOW3rxsrI5xCs3"
    
    // Real Estate pricing
    private var realEstatePrice: Decimal {
        let prices = propertySize == .under5000 ? realEstateUnder5000Prices : realEstateAbove5000Prices
        if let priceInfo = prices.first(where: { $0.rankTier == requiredMinimumRank }) {
            return priceInfo.amountInDollars
        }
        // Fallback if prices not loaded
        return Decimal(500)
    }
    
    // Automotive pricing
    private var automotivePrice: Decimal {
        if hasAutomotiveSubscription {
            // Client has active subscription: use subscription-tier Stripe prices
            if let priceInfo = automotiveSubscriptionPrices.first(where: { $0.rankTier == requiredMinimumRank }) {
                return priceInfo.amountInDollars
            }
            // Fallback prices if Stripe prices not loaded
            switch requiredMinimumRank {
            case 4: return Decimal(4000) // Captain
            case 3: return Decimal(3800) // Commander
            case 2: return Decimal(3600) // Lieutenant
            case 1: return Decimal(3400) // Sub Lieutenant
            default: return Decimal(3400) // Ensign
            }
        } else if isFirstAutomotiveBooking {
            // First-time booking without subscription: use first-time Stripe prices
            if let priceInfo = automotiveFirstTimePrices.first(where: { $0.rankTier == requiredMinimumRank }) {
                return priceInfo.amountInDollars
            }
            // Fallback prices if Stripe prices not loaded
            switch requiredMinimumRank {
            case 4: return Decimal(4000) // Captain
            case 3: return Decimal(3800) // Commander
            case 2: return Decimal(3600) // Lieutenant
            case 1: return Decimal(3400) // Sub Lieutenant
            default: return Decimal(3400) // Ensign
            }
        } else {
            // Returning user without subscription: use non-subscription Stripe prices
            if let priceInfo = automotiveNonSubscriptionPrices.first(where: { $0.rankTier == requiredMinimumRank }) {
                return priceInfo.amountInDollars
            }
            // Fallback prices if Stripe prices not loaded
            switch requiredMinimumRank {
            case 4: return Decimal(7000) // Captain
            case 3: return Decimal(6800) // Commander
            case 2: return Decimal(6600) // Lieutenant
            case 1: return Decimal(6400) // Sub Lieutenant
            default: return Decimal(6400) // Ensign
            }
        }
    }
    
    private var rankName: String {
        PilotStats(pilotId: UUID(), totalFlightHours: 0, completedBookings: 0, tier: requiredMinimumRank).tierName
    }
    
    // Convert rank tier to lookup_key for subscription
    private var rankLookupKey: String? {
        switch requiredMinimumRank {
        case 4: return "captain"
        case 3: return "commander"
        case 2: return "lieutenant"
        case 1: return "sub-lieutenant"
        default: return nil
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Booking Details Section
                SectionCard3(number: 1, title: "Booking Details", subtitle: "Optional") {
                    TextField("Enter details about this booking. This could be something that you want pilots to be aware of before or during the flight.", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                
                // Payment Section
                SectionCard3(number: 2, title: "Payment") {
                    if selectedSpecialization == .automotive {
                        // Automotive fixed pricing
                        VStack(alignment: .leading, spacing: 16) {
                            // Selected Rank
                            HStack {
                                Text("Selected Rank:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(rankName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            // Payment Amount
                            HStack {
                                Text("Payment Amount:")
                                    .font(.headline)
                                Spacer()
                                Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: automotivePrice).doubleValue))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            // Pricing info messages
                            if isFirstAutomotiveBooking {
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.subheadline)
                                    Text("First-month special price")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                
                                if !hasAutomotiveSubscription {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("💡 Save on future bookings!")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.orange)
                                        
                                        Text("Subscribe to the Buzz Automotive package to lock in a lower price and have peace of mind Buzz will deliver 50 videos to you every month for the next 12 months. Without subscribing, your next booking will be priced at:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(automotiveNonSubscriptionPrices.sorted(by: { $0.rankTier > $1.rankTier })) { price in
                                                Text("• \(price.rank.capitalized): \(price.displayPrice)")
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 8)
                                        
                                        Button(action: {
                                            showSubscription = true
                                        }) {
                                            Text("Subscribe Now!")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(Color.blue)
                                                .cornerRadius(10)
                                        }
                                    }
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            } else if !hasAutomotiveSubscription {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .font(.subheadline)
                                        Text("Higher pricing - No subscription")
                                            .font(.subheadline)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    Text("Subscribe the Buzz Automotive Package to get lower prices on future bookings!")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: {
                                        showSubscription = true
                                    }) {
                                        Text("Subscribe Now!")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(Color.blue)
                                            .cornerRadius(10)
                                    }
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.subheadline)
                                    Text("Subscriber pricing")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    } else if selectedSpecialization == .realEstate {
                        // Real Estate fixed pricing based on property size
                        VStack(alignment: .leading, spacing: 16) {
                            // Selected Rank
                            HStack {
                                Text("Selected Rank:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(rankName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            // Property Size
                            HStack {
                                Text("Property Size:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(propertySize.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            // Payment Amount
                            HStack {
                                Text("Payment Amount:")
                                    .font(.headline)
                                Spacer()
                                Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: realEstatePrice).doubleValue))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.subheadline)
                                Text("Pricing based on rank and property size")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    } else {
                        // Other industries - payment input
                        VStack(alignment: .leading, spacing: 16) {
                            Picker("Payment Type", selection: $paymentInputType) {
                                ForEach(PaymentInputType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: paymentInputType) { _, _ in
                                hourlyRateInput = ""
                                totalPaymentInput = ""
                                paymentAmount = ""
                            }
                            
                            if paymentInputType == .totalPayment {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("💵")
                                            .font(.system(size: 20))
                                        Text("Total Payment ($)")
                                            .font(.subheadline)
                                        Spacer()
                                        TextField("0.00", text: $totalPaymentInput)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .onChange(of: totalPaymentInput) { _, newValue in
                                                let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                                if filtered != newValue {
                                                    totalPaymentInput = filtered
                                                } else {
                                                    paymentAmount = filtered
                                                    updateCalculatedValue()
                                                }
                                            }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    
                                    if showMinRateWarning {
                                        HStack(spacing: 4) {
                                            Text("⚠️")
                                            Text("Calculated hourly rate is below minimum of $\(String(format: "%.2f", minimumHourlyRate))/hr")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("⏱️")
                                            .font(.system(size: 20))
                                        Text("Hourly Rate ($)")
                                            .font(.subheadline)
                                        Spacer()
                                        TextField("0.00", text: $hourlyRateInput)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .onChange(of: hourlyRateInput) { _, newValue in
                                                let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                                if filtered != newValue {
                                                    hourlyRateInput = filtered
                                                } else {
                                                    if let rate = Double(filtered), rate > 0 {
                                                        showMinRateWarning = rate < minimumHourlyRate
                                                    } else {
                                                        showMinRateWarning = false
                                                    }
                                                    updateCalculatedValue()
                                                }
                                            }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    
                                    if showMinRateWarning {
                                        HStack(spacing: 4) {
                                            Text("⚠️")
                                            Text("Minimum hourly rate is $\(String(format: "%.2f", minimumHourlyRate))")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            
                            // Calculated value display
                            let defaultHours: Double = 2.0
                            
                            if paymentInputType == .totalPayment {
                                if !totalPaymentInput.isEmpty, let total = Double(totalPaymentInput), total > 0 {
                                    let hourlyRate = total / defaultHours
                                    HStack {
                                        Text("Calculated Hourly Rate:")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("$\(String(format: "%.2f", hourlyRate))/hr")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(hourlyRate < minimumHourlyRate ? .orange : .purple)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            } else {
                                if !hourlyRateInput.isEmpty, let rate = Double(hourlyRateInput), rate > 0 {
                                    let total = rate * defaultHours
                                    HStack {
                                        Text("Calculated Total Payment:")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("$\(String(format: "%.2f", total))")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.green)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                }
                
                // Navigation Buttons
                HStack(spacing: 12) {
                    Button("Back") {
                        onBack()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                    
                    CustomButton(
                        title: "Book",
                        action: onCreate,
                        isLoading: isLoading,
                        isDisabled: !isFormValid
                    )
                    .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 20)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Initialize input fields based on current paymentAmount
            if let amount = Double(paymentAmount), amount > 0 {
                if paymentInputType == .totalPayment {
                    totalPaymentInput = paymentAmount
                } else {
                    hourlyRateInput = paymentAmount
                }
            }
            
            // For Automotive, set payment amount based on rank
            if selectedSpecialization == .automotive {
                paymentAmount = String(format: "%.2f", NSDecimalNumber(decimal: automotivePrice).doubleValue)
            }
            // For Real Estate, set payment amount based on rank and property size
            else if selectedSpecialization == .realEstate {
                paymentAmount = String(format: "%.2f", NSDecimalNumber(decimal: realEstatePrice).doubleValue)
            }
        }
        .onChange(of: requiredMinimumRank) { _, _ in
            // Update payment amount when rank changes
            if selectedSpecialization == .automotive {
                paymentAmount = String(format: "%.2f", NSDecimalNumber(decimal: automotivePrice).doubleValue)
            } else if selectedSpecialization == .realEstate {
                paymentAmount = String(format: "%.2f", NSDecimalNumber(decimal: realEstatePrice).doubleValue)
            }
        }
        .sheet(isPresented: $showSubscription) {
            PlanSelectionView(
                subscriptionService: subscriptionService,
                onSubscriptionCreated: {
                    showSubscription = false
                    // Refresh subscription status if needed
                },
                productId: automotiveProductId,
                rankLookupKey: rankLookupKey
            )
        }
        .onAppear {
            // Load plans when subscription sheet might be shown
            if selectedSpecialization == .automotive {
                Task {
                    await subscriptionService.fetchAvailablePlans(productId: automotiveProductId)
                }
            }
        }
    }
    
    private func updateCalculatedValue() {
        // For non-Automotive industries, use default 2 hours for calculation
        let defaultHours: Double = 2.0
        
        if paymentInputType == .totalPayment {
            // Calculate hourly rate from total payment
            if let total = Double(totalPaymentInput), total > 0 {
                paymentAmount = totalPaymentInput
                // Validate minimum hourly rate
                let hourlyRate = total / defaultHours
                if hourlyRate < minimumHourlyRate {
                    showMinRateWarning = true
                } else {
                    showMinRateWarning = false
                }
            } else {
                paymentAmount = ""
                showMinRateWarning = false
            }
        } else {
            // Calculate total payment from hourly rate
            if let rate = Double(hourlyRateInput), rate > 0 {
                let total = rate * defaultHours
                paymentAmount = String(format: "%.2f", total)
                // Validate minimum hourly rate
                if rate < minimumHourlyRate {
                    showMinRateWarning = true
                } else {
                    showMinRateWarning = false
                }
            } else {
                paymentAmount = ""
                showMinRateWarning = false
            }
        }
    }
}

// MARK: - Section Card for Step 3

struct SectionCard3<Content: View>: View {
    let number: Int
    let title: String
    var subtitle: String? = nil
    let content: Content
    
    init(number: Int, title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.number = number
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                // Numbered badge
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                    
                    Text("\(number)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                if let subtitle = subtitle {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 20, weight: .semibold))
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                }
                
                Spacer()
            }
            
            content
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

