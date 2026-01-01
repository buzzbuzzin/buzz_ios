//
//  SearchRescueCompletionView.swift
//  Buzz
//
//  Created for Search & Rescue mission completion flow
//

import SwiftUI

/// View for customers to enter hours worked and complete payment for S&R missions
struct SearchRescueCompletionView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    @StateObject private var paymentService = PaymentService()
    @Environment(\.dismiss) var dismiss
    
    let booking: Booking
    let onComplete: () -> Void
    
    @State private var hoursWorked: String = ""
    @State private var isProcessingPayment: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var crewCount: Int = 0
    @State private var isLoadingCrew: Bool = true
    
    private var hourlyRate: Decimal {
        booking.hourlyRate ?? 25
    }
    
    private var hoursDouble: Double {
        Double(hoursWorked) ?? 0
    }
    
    private var amountPerPilot: Decimal {
        Decimal(hoursDouble) * hourlyRate
    }
    
    private var totalAmount: Decimal {
        amountPerPilot * Decimal(crewCount)
    }
    
    private var isFormValid: Bool {
        hoursDouble > 0 && crewCount > 0
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Mission Complete!")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Enter the hours worked to calculate payment")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Mission Info
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                            Text(booking.locationName)
                                .font(.headline)
                        }
                        
                        if let description = booking.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.blue)
                            if isLoadingCrew {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("\(crewCount) pilot\(crewCount == 1 ? "" : "s") participated")
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Hours Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Hours Worked")
                            .font(.headline)
                        
                        HStack {
                            TextField("0", text: $hoursWorked)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 32, weight: .bold))
                                .multilineTextAlignment(.center)
                                .frame(width: 100)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            
                            Text("hours")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Enter the total hours spent on this mission")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Payment Calculation
                    if booking.isVoluntary != true && hoursDouble > 0 {
                        VStack(spacing: 16) {
                            Text("Payment Calculation")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Hourly Rate")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("$\(NSDecimalNumber(decimal: hourlyRate).doubleValue, specifier: "%.2f")/hr")
                                }
                                
                                HStack {
                                    Text("Hours Worked")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(hoursDouble, specifier: "%.1f") hours")
                                }
                                
                                HStack {
                                    Text("Pilots")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(crewCount)")
                                }
                                
                                Divider()
                                
                                HStack {
                                    Text("Amount per Pilot")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("$\(NSDecimalNumber(decimal: amountPerPilot).doubleValue, specifier: "%.2f")")
                                }
                                
                                HStack {
                                    Text("Total Payment")
                                        .font(.headline)
                                    Spacer()
                                    Text("$\(NSDecimalNumber(decimal: totalAmount).doubleValue, specifier: "%.2f")")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Voluntary Mission Message
                    if booking.isVoluntary == true {
                        VStack(spacing: 12) {
                            Image(systemName: "heart.fill")
                                .font(.title)
                                .foregroundColor(.green)
                            
                            Text("This was a voluntary mission")
                                .font(.headline)
                            
                            Text("No payment required. Thank you for supporting the community!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 40)
                    
                    // Complete Button
                    Button(action: {
                        Task {
                            await completeMission()
                        }
                    }) {
                        HStack {
                            if isProcessingPayment {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: booking.isVoluntary == true ? "checkmark.circle.fill" : "creditcard.fill")
                                Text(booking.isVoluntary == true ? "Complete Mission" : "Pay & Complete")
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid || booking.isVoluntary == true ? Color.blue : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled((!isFormValid && booking.isVoluntary != true) || isProcessingPayment)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Complete Mission")
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
            .task {
                await loadCrewCount()
            }
        }
    }
    
    private func loadCrewCount() async {
        isLoadingCrew = true
        
        do {
            let crewInfo = try await bookingService.fetchBookingCrew(
                bookingId: booking.id,
                requesterId: authService.activeUserId,
                requesterType: "customer"
            )
            crewCount = crewInfo.crewCount
        } catch {
            print("Error loading crew: \(error)")
            crewCount = 1 // Default to 1 if error
        }
        
        isLoadingCrew = false
    }
    
    private func completeMission() async {
        guard let customerId = authService.activeUserId else { return }
        
        isProcessingPayment = true
        
        do {
            // Update booking with final hours worked
            try await bookingService.updateSearchRescueHours(
                bookingId: booking.id,
                hoursWorked: hoursDouble
            )
            
            // For paid missions, process payment
            if booking.isVoluntary != true && totalAmount > 0 {
                // Create payment intent and process payment
                let transferGroup = "booking_\(booking.id.uuidString)"
                
                let paymentIntentResponse = try await paymentService.createPaymentIntent(
                    amount: totalAmount,
                    currency: "usd",
                    customerId: customerId,
                    transferGroup: transferGroup
                )
                
                // Present payment sheet
                let paymentResult = try await paymentService.presentPaymentSheet(
                    paymentIntentClientSecret: paymentIntentResponse.clientSecret,
                    customerId: paymentIntentResponse.customerId,
                    customerEphemeralKeySecret: paymentIntentResponse.ephemeralKeySecret
                )
                
                switch paymentResult {
                case .completed:
                    // Payment successful, update booking with payment info
                    try await bookingService.completeSearchRescuePayment(
                        bookingId: booking.id,
                        paymentIntentId: paymentIntentResponse.paymentIntentId,
                        totalAmount: totalAmount,
                        hoursWorked: hoursDouble,
                        pilotCount: crewCount
                    )
                    
                    await MainActor.run {
                        isProcessingPayment = false
                        onComplete()
                        dismiss()
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
            } else {
                // Voluntary mission - just complete without payment
                try await bookingService.completeVoluntaryMission(bookingId: booking.id)
                
                await MainActor.run {
                    isProcessingPayment = false
                    onComplete()
                    dismiss()
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
}

