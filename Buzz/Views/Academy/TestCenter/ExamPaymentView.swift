//
//  ExamPaymentView.swift
//  Buzz
//
//  Exam payment view with Stripe integration
//

import SwiftUI
import Auth
import StripePaymentSheet

struct ExamPaymentView: View {
    let examType: ExamType
    let priceInfo: ExamPriceResponse
    let scheduledDate: Date
    let locationType: ExamLocationType
    let locationAddress: String?
    
    @EnvironmentObject var authService: AuthService
    @StateObject private var examService = ExamService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var isProcessingPayment = false
    @State private var paymentIntentResponse: ExamPaymentIntentResponse?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var createdAppointment: ExamAppointment?
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: scheduledDate)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success View
                if showSuccess, let appointment = createdAppointment {
                    SuccessView(appointment: appointment) {
                        // Dismiss back to Test Center
                        dismiss()
                    }
                } else {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                        
                        Text("Complete Payment")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Review your booking and complete payment")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Booking Summary
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Booking Summary")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            BookingDetailRow(icon: examType.icon, label: "Exam", value: examType.displayName, iconColor: examType.color)
                            BookingDetailRow(icon: "calendar", label: "Date & Time", value: formattedDate)
                            BookingDetailRow(icon: "clock", label: "Duration", value: "\(examType.durationMinutes) minutes")
                            BookingDetailRow(icon: locationType.icon, label: "Format", value: locationType.displayName)
                            
                            if let address = locationAddress {
                                BookingDetailRow(icon: "mappin.and.ellipse", label: "Location", value: address)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Price Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Payment Details")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text(examType.displayName)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(priceInfo.formattedPrice)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Total")
                                    .font(.headline)
                                Spacer()
                                Text(priceInfo.formattedPrice)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Payment Notice
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.green)
                        
                        Text("Secure payment powered by Stripe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Pay Button
                    Button(action: {
                        Task {
                            await processPayment()
                        }
                    }) {
                        HStack {
                            if isProcessingPayment {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Processing...")
                            } else {
                                Image(systemName: "creditcard")
                                Text("Pay \(priceInfo.formattedPrice)")
                            }
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isProcessingPayment ? Color.gray : examType.color)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessingPayment)
                    .padding(.horizontal)
                    
                    // Cancellation Policy
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cancellation Policy")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text("You may cancel or reschedule your exam up to 24 hours before the scheduled time for a full refund. Cancellations made less than 24 hours before the exam are non-refundable.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Payment")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(showSuccess)
        .alert("Payment Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func processPayment() async {
        guard let currentUser = authService.currentUser else {
            errorMessage = "You must be logged in to make a payment."
            showError = true
            return
        }
        
        isProcessingPayment = true
        
        do {
            // Create PaymentIntent
            let paymentIntent = try await examService.createExamPaymentIntent(
                examType: examType,
                pilotId: currentUser.id,
                scheduledDate: scheduledDate,
                locationType: locationType,
                locationAddress: locationAddress
            )
            
            paymentIntentResponse = paymentIntent
            
            // Present Stripe PaymentSheet
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "Buzz Academy"
            
            if let customerId = paymentIntent.customerId,
               let ephemeralKey = paymentIntent.ephemeralKeySecret {
                configuration.customer = .init(id: customerId, ephemeralKeySecret: ephemeralKey)
            }
            
            let paymentSheet = PaymentSheet(
                paymentIntentClientSecret: paymentIntent.clientSecret,
                configuration: configuration
            )
            
            // Present payment sheet
            let result = try await paymentSheet.present()
            
            switch result {
            case .completed:
                // Payment successful - create appointment
                let appointment = try await examService.createExamAppointment(
                    pilotId: currentUser.id,
                    examType: examType,
                    scheduledDate: scheduledDate,
                    locationType: locationType,
                    locationAddress: locationAddress,
                    paymentIntentId: paymentIntent.paymentIntentId,
                    chargeId: nil,
                    paymentAmount: paymentIntent.decimalAmount
                )
                
                createdAppointment = appointment
                isProcessingPayment = false
                showSuccess = true
                
            case .cancelled:
                isProcessingPayment = false
                // User cancelled - do nothing
                
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
}

// MARK: - Supporting Views

struct BookingDetailRow: View {
    let icon: String
    let label: String
    let value: String
    var iconColor: Color = .blue
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct SuccessView: View {
    let appointment: ExamAppointment
    let onDone: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Success Animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
            }
            
            Text("Booking Confirmed!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Your \(appointment.examType.displayName) has been scheduled successfully.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Appointment Details Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: appointment.examType.icon)
                        .foregroundColor(appointment.examType.color)
                    Text(appointment.examType.displayName)
                        .fontWeight(.semibold)
                }
                
                Divider()
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text(appointment.formattedDate)
                }
                
                HStack {
                    Image(systemName: appointment.locationType.icon)
                        .foregroundColor(.blue)
                    Text(appointment.locationType.displayName)
                }
                
                if let address = appointment.locationAddress {
                    HStack(alignment: .top) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.blue)
                        Text(address)
                            .font(.caption)
                    }
                }
                
                if appointment.locationType == .online {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.orange)
                        Text("Zoom link will be sent via email")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Confirmation Message
            VStack(spacing: 8) {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.blue)
                Text("A confirmation email has been sent to your registered email address.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            Spacer()
            
            Button(action: onDone) {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    NavigationStack {
        ExamPaymentView(
            examType: .flightReview,
            priceInfo: ExamPriceResponse(
                productId: "prod_test",
                priceId: "price_test",
                unitAmount: 4999,
                currency: "usd",
                productName: "Flight Review"
            ),
            scheduledDate: Date().addingTimeInterval(86400 * 3),
            locationType: .inPerson,
            locationAddress: "123 Main St, San Francisco, CA 94102"
        )
        .environmentObject(AuthService())
    }
}

