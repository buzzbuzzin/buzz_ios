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
    
    let onBack: () -> Void
    let onCreate: () -> Void
    let isLoading: Bool
    let isFormValid: Bool
    
    @State private var hourlyRateInput = ""
    @State private var totalPaymentInput = ""
    @State private var showMinRateWarning = false
    @State private var paymentInputType: PaymentInputType = .totalPayment
    
    private let minimumHourlyRate: Double = 25.0
    
    // Automotive pricing
    private var automotivePrice: Decimal {
        if hasAutomotiveSubscription || isFirstAutomotiveBooking {
            // First-time user or has subscription: lower prices
            switch requiredMinimumRank {
            case 4: return Decimal(4000) // Captain
            case 3: return Decimal(3800) // Commander
            case 2: return Decimal(3600) // Lieutenant
            case 1: return Decimal(3400) // Sub Lieutenant
            default: return Decimal(3400) // Ensign
            }
        } else {
            // Returning user without subscription: higher prices
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
    
    var body: some View {
        Form {
            Section("Booking Details") {
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            // Payment Section - Different for Automotive vs other industries
            if selectedSpecialization == .automotive {
                Section("Payment") {
                    // Show fixed pricing for Automotive
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Selected Rank:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(rankName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Payment Amount:")
                                .font(.headline)
                            Spacer()
                            Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: automotivePrice).doubleValue))")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        
                        // Show pricing message
                        if isFirstAutomotiveBooking {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("First-time customer pricing")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                
                                if !hasAutomotiveSubscription {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("💡 Save on future bookings!")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.orange)
                                        
                                        Text("Purchase the Buzz Automotive Package to lock in these lower prices for all future bookings. Without the package, your next booking will be priced at:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("• Captain: $7,000")
                                            Text("• Commander: $6,800")
                                            Text("• Lieutenant: $6,600")
                                            Text("• Sub Lieutenant: $6,400")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 8)
                                    }
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.top, 8)
                        } else if !hasAutomotiveSubscription {
                            // Returning user without subscription
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text("Higher pricing - No subscription")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                
                                Text("Purchase the Buzz Automotive Package to get lower prices on future bookings!")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        } else {
                            // Has subscription
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("Subscriber pricing")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                // Other industries - use existing payment input system
                Section("Payment") {
                    // Payment Input Type Selector
                    Picker("Payment Type", selection: $paymentInputType) {
                        ForEach(PaymentInputType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: paymentInputType) { _, _ in
                        // Clear inputs when switching types
                        hourlyRateInput = ""
                        totalPaymentInput = ""
                        paymentAmount = ""
                    }
                    
                    // Input field based on selection
                    if paymentInputType == .totalPayment {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Total Payment ($)")
                                    .font(.subheadline)
                                Spacer()
                                TextField("0.00", text: $totalPaymentInput)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .onChange(of: totalPaymentInput) { _, newValue in
                                        // Filter to only allow numbers and decimal point
                                        let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                        if filtered != newValue {
                                            totalPaymentInput = filtered
                                        } else {
                                            paymentAmount = filtered
                                            updateCalculatedValue()
                                        }
                                    }
                            }
                            
                            if showMinRateWarning {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text("Calculated hourly rate is below minimum of $\(String(format: "%.2f", minimumHourlyRate))/hr")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Hourly Rate ($)")
                                    .font(.subheadline)
                                Spacer()
                                TextField("0.00", text: $hourlyRateInput)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .onChange(of: hourlyRateInput) { _, newValue in
                                        // Filter to only allow numbers and decimal point
                                        let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                        if filtered != newValue {
                                            hourlyRateInput = filtered
                                        } else {
                                            if let rate = Double(filtered), rate > 0 {
                                                if rate < minimumHourlyRate {
                                                    showMinRateWarning = true
                                                } else {
                                                    showMinRateWarning = false
                                                }
                                            } else {
                                                showMinRateWarning = false
                                            }
                                            updateCalculatedValue()
                                        }
                                    }
                            }
                            
                            if showMinRateWarning {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text("Minimum hourly rate is $\(String(format: "%.2f", minimumHourlyRate))")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    
                    // Display calculated value (using default 2 hours)
                    let defaultHours: Double = 2.0
                    Divider()
                    
                    if paymentInputType == .totalPayment {
                        // Show calculated hourly rate
                        if !totalPaymentInput.isEmpty, let total = Double(totalPaymentInput), total > 0 {
                            let hourlyRate = total / defaultHours
                            HStack {
                                Text("Calculated Hourly Rate:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("$\(String(format: "%.2f", hourlyRate))/hr")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(hourlyRate < minimumHourlyRate ? .orange : .purple)
                                    if hourlyRate < minimumHourlyRate {
                                        Text("Below minimum")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                    } else {
                        // Show calculated total payment
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
                        }
                    }
                }
            }
            
            Section {
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
                        title: "Pay",
                        action: onCreate,
                        isLoading: isLoading,
                        isDisabled: !isFormValid
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
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
        }
        .onChange(of: requiredMinimumRank) { _, _ in
            // Update payment amount when rank changes for Automotive
            if selectedSpecialization == .automotive {
                paymentAmount = String(format: "%.2f", NSDecimalNumber(decimal: automotivePrice).doubleValue)
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

