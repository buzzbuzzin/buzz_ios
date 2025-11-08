//
//  CreateBookingStep2View.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI

enum PaymentInputType: String, CaseIterable {
    case totalPayment = "Total Payment"
    case hourlyRate = "Hourly Rate"
}

struct CreateBookingStep2View: View {
    @Binding var description: String
    @Binding var paymentAmount: String
    @Binding var estimatedHours: String
    @Binding var paymentInputType: PaymentInputType
    
    let onBack: () -> Void
    let onCreate: () -> Void
    let isLoading: Bool
    let isFormValid: Bool
    
    @State private var hourlyRateInput = ""
    @State private var totalPaymentInput = ""
    @State private var showMinRateWarning = false
    
    private let minimumHourlyRate: Double = 25.0
    
    var body: some View {
        Form {
            Section("Booking Details") {
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...6)
                
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
                                .onChange(of: totalPaymentInput) { oldValue, newValue in
                                    // Filter to only allow numbers and decimal point
                                    let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                    if filtered != newValue {
                                        totalPaymentInput = filtered
                                    } else {
                                        paymentAmount = filtered
                                        // Calculate hourly rate if hours are entered
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
                                .onChange(of: hourlyRateInput) { oldValue, newValue in
                                    // Filter to only allow numbers and decimal point
                                    let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                    if filtered != newValue {
                                        hourlyRateInput = filtered
                                    } else {
                                        // Validate minimum hourly rate
                                        if let rate = Double(filtered), rate > 0 {
                                            if rate < minimumHourlyRate {
                                                showMinRateWarning = true
                                            } else {
                                                showMinRateWarning = false
                                            }
                                        } else {
                                            showMinRateWarning = false
                                        }
                                        // Calculate total payment if hours are entered
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
                
                // Estimated Flight Hours
                HStack {
                    Text("Estimated Flight Hours")
                        .font(.subheadline)
                    Spacer()
                    TextField("0.0", text: $estimatedHours)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: estimatedHours) { oldValue, newValue in
                            // Filter to only allow numbers and decimal point
                            let filtered = newValue.filter { $0.isNumber || $0 == "." }
                            if filtered != newValue {
                                estimatedHours = filtered
                            } else {
                                // Calculate the other value when hours change
                                updateCalculatedValue()
                            }
                        }
                }
                
                // Display calculated value
                if !estimatedHours.isEmpty, let hours = Double(estimatedHours), hours > 0 {
                    Divider()
                    
                    if paymentInputType == .totalPayment {
                        // Show calculated hourly rate
                        if !totalPaymentInput.isEmpty, let total = Double(totalPaymentInput), total > 0 {
                            let hourlyRate = total / hours
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
                            let total = rate * hours
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
                        title: "Create Booking",
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
                    // Try to determine if it's hourly rate or total
                    // Default to total payment if hours exist
                    if let hours = Double(estimatedHours), hours > 0 {
                        totalPaymentInput = paymentAmount
                        paymentInputType = .totalPayment
                    } else {
                        hourlyRateInput = paymentAmount
                    }
                }
            }
        }
    }
    
    private func updateCalculatedValue() {
        guard let hours = Double(estimatedHours), hours > 0 else {
            paymentAmount = ""
            return
        }
        
        if paymentInputType == .totalPayment {
            // Calculate hourly rate from total payment
            if let total = Double(totalPaymentInput), total > 0 {
                paymentAmount = totalPaymentInput
                // Validate minimum hourly rate
                let hourlyRate = total / hours
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
                let total = rate * hours
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

