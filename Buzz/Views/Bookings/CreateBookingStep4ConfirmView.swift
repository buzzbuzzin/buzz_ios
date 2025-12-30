//
//  CreateBookingStep4ConfirmView.swift
//  Buzz
//
//  Created for Confirmation step in booking flow
//

import SwiftUI
import MapKit

struct CreateBookingStep4ConfirmView: View {
    let locationName: String
    let selectedLocation: CLLocationCoordinate2D
    let selectedDate: Date
    let startTime: Date
    let endTime: Date?
    let selectedSpecialization: BookingSpecialization
    let requiredMinimumRank: Int
    let description: String
    let paymentAmount: Decimal
    let estimatedHours: Double
    
    // Credits support
    let availableCredits: Decimal
    @Binding var creditsToUse: Decimal
    let onCreditsChanged: (Decimal) -> Void
    
    let onBack: () -> Void
    let onPay: () -> Void
    let isLoading: Bool
    
    @State private var useCredits = false
    
    private var rankName: String {
        PilotStats(pilotId: UUID(), totalFlightHours: 0, completedBookings: 0, tier: requiredMinimumRank).tierName
    }
    
    private func formatStartTime() -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return timeFormatter.string(from: startTime)
    }
    
    /// Maximum credits that can be applied (cannot exceed payment amount or available credits)
    private var maxApplicableCredits: Decimal {
        // Can't apply more credits than the payment amount minus minimum Stripe charge ($0.50)
        let maxFromPayment = max(0, paymentAmount - Decimal(0.50))
        return min(availableCredits, maxFromPayment)
    }
    
    /// Final amount after credits applied
    private var finalAmount: Decimal {
        max(paymentAmount - creditsToUse, Decimal(0.50)) // Stripe minimum is $0.50
    }
    
    /// Discount amount
    private var discountAmount: Decimal {
        creditsToUse
    }
    
    private var formattedDateRange: String {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        
        let startDateString = dateFormatter.string(from: selectedDate)
        let startTimeString = timeFormatter.string(from: startTime)
        
        if let endTime = endTime {
            let endDateString = dateFormatter.string(from: endTime)
            let endTimeString = timeFormatter.string(from: endTime)
            
            if calendar.isDate(selectedDate, inSameDayAs: endTime) {
                return "\(startDateString), \(startTimeString) – \(endTimeString)"
            } else {
                return "\(startDateString), \(startTimeString) – \(endDateString), \(endTimeString)"
            }
        } else {
            // Calculate end time from start time + estimated hours
            if let calculatedEndTime = calendar.date(byAdding: .hour, value: Int(estimatedHours), to: startTime) {
                let fractionalHours = estimatedHours - Double(Int(estimatedHours))
                let minutes = Int(fractionalHours * 60)
                if let finalEndTime = calendar.date(byAdding: .minute, value: minutes, to: calculatedEndTime) {
                    let endTimeString = timeFormatter.string(from: finalEndTime)
                    return "\(startDateString), \(startTimeString) – \(endTimeString)"
                }
            }
            return "\(startDateString), \(startTimeString)"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Listing Information Card
                VStack(alignment: .leading, spacing: 20) {
                    // Specialization Image/Icon
                    HStack(spacing: 12) {
                        // Specialization Icon
                        Image(selectedSpecialization.backgroundImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(selectedSpecialization.displayName)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("Pilot Rank: \(rankName)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Booking Details
                    VStack(spacing: 20) {
                        // Dates
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Dates")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formattedDateRange)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            Spacer()
                        }
                        
                        // Start Time
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start Time")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formatStartTime())
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            Spacer()
                        }
                        
                        // Location
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Location")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(locationName)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            Spacer()
                        }
                        
                        // Description
                        if !description.isEmpty {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Description")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(description)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                            }
                        }
                        
                        // Duration
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Estimated Duration")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f hours", estimatedHours))
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            Spacer()
                        }
                    }
                    
                    Divider()
                    
                    // Credits Section (only show if user has credits)
                    if availableCredits > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "gift.fill")
                                    .foregroundColor(.green)
                                Text("Referral Credits")
                                    .font(.headline)
                                Spacer()
                                Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: availableCredits).doubleValue)) available")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                            
                            Toggle(isOn: $useCredits) {
                                Text("Apply credits to this booking")
                                    .font(.subheadline)
                            }
                            .tint(.green)
                            .onChange(of: useCredits) { newValue in
                                if newValue {
                                    // Apply maximum possible credits
                                    creditsToUse = maxApplicableCredits
                                } else {
                                    creditsToUse = 0
                                }
                                onCreditsChanged(creditsToUse)
                            }
                            
                            if useCredits && maxApplicableCredits > 0 {
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("Credits to apply:")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("-$\(String(format: "%.2f", NSDecimalNumber(decimal: creditsToUse).doubleValue))")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.green)
                                    }
                                    
                                    // Slider for credit amount if available credits > paymentAmount
                                    if availableCredits > maxApplicableCredits {
                                        Slider(
                                            value: Binding(
                                                get: { NSDecimalNumber(decimal: creditsToUse).doubleValue },
                                                set: { 
                                                    creditsToUse = Decimal($0)
                                                    onCreditsChanged(creditsToUse)
                                                }
                                            ),
                                            in: 0...NSDecimalNumber(decimal: maxApplicableCredits).doubleValue,
                                            step: 1.0
                                        )
                                        .tint(.green)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        
                        Divider()
                    }
                    
                    // Price Breakdown
                    VStack(spacing: 8) {
                        // Original Price
                        HStack {
                            Text("Subtotal")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: paymentAmount).doubleValue))")
                                .font(.subheadline)
                        }
                        
                        // Credits discount (if applied)
                        if creditsToUse > 0 {
                            HStack {
                                Text("Referral credit")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                Spacer()
                                Text("-$\(String(format: "%.2f", NSDecimalNumber(decimal: creditsToUse).doubleValue))")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Divider()
                        
                        // Total Price
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total price")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: finalAmount).doubleValue)) including taxes")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                    Text("USD")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .underline()
                                }
                            }
                            Spacer()
                        }
                        
                        // Savings message
                        if creditsToUse > 0 {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("You're saving $\(String(format: "%.2f", NSDecimalNumber(decimal: creditsToUse).doubleValue)) with referral credits!")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
                .padding(.top)
                
                // Payment Button Section
                VStack(spacing: 0) {
                    Divider()
                        .padding(.top, 24)
                    
                    VStack(spacing: 12) {
                        // Pay Button
                        Button(action: onPay) {
                            HStack {
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Confirm and Pay")
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 16)
                            .background(Color.pink)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading)
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // Back Button
                        Button(action: onBack) {
                            Text("Back")
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // Terms Agreement Text
                        HStack(spacing: 4) {
                            Text("By selecting the button, I agree to the")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("booking terms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .underline()
                            Text(".")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationTitle("Confirm and Pay")
        .navigationBarTitleDisplayMode(.inline)
    }
}
