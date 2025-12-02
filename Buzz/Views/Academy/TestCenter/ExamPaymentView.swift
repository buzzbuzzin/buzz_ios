//
//  ExamPaymentView.swift
//  Buzz
//
//  Exam payment view with Stripe integration
//

import SwiftUI
import Auth
import StripePaymentSheet
import EventKit
import EventKitUI

struct ExamPaymentView: View {
    let examType: ExamType
    let priceInfo: ExamPriceResponse
    let scheduledDate: Date
    let locationType: ExamLocationType
    let locationAddress: String?
    var onBookingComplete: (() -> Void)?
    
    @EnvironmentObject var authService: AuthService
    @StateObject private var examService = ExamService()
    @StateObject private var paymentService = PaymentService()
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
                        if let onComplete = onBookingComplete {
                            onComplete()
                        } else {
                            dismiss()
                        }
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
                    
                    // Reschedule Policy
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reschedule Policy")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text("Exam fees are non-refundable. You may reschedule your exam up to 24 hours before the scheduled time at no additional cost. Rescheduling is not available within 24 hours of your exam.")
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
    
    // MARK: - Test Mode Flag
    // TODO: Remove this before production release!
    private let testModeBypassPayment = true
    
    private func processPayment() async {
        guard let currentUser = authService.currentUser else {
            errorMessage = "You must be logged in to make a payment."
            showError = true
            return
        }
        
        isProcessingPayment = true
        
        do {
            // TEST MODE: Bypass payment for testing Zoom integration
            if testModeBypassPayment {
                print("⚠️ TEST MODE: Bypassing payment flow")
                let appointment = try await examService.createExamAppointment(
                    pilotId: currentUser.id,
                    examType: examType,
                    scheduledDate: scheduledDate,
                    locationType: locationType,
                    locationAddress: locationAddress,
                    paymentIntentId: "test_pi_\(UUID().uuidString)",
                    chargeId: nil,
                    paymentAmount: priceInfo.decimalAmount,
                    pilotEmail: currentUser.email
                )
                
                createdAppointment = appointment
                isProcessingPayment = false
                showSuccess = true
                return
            }
            
            // Create PaymentIntent
            let paymentIntent = try await examService.createExamPaymentIntent(
                examType: examType,
                pilotId: currentUser.id,
                scheduledDate: scheduledDate,
                locationType: locationType,
                locationAddress: locationAddress
            )
            
            paymentIntentResponse = paymentIntent
            
            // Present PaymentSheet using PaymentService (same as booking flow - includes Apple Pay)
            let result = try await paymentService.presentPaymentSheet(
                paymentIntentClientSecret: paymentIntent.clientSecret,
                customerId: paymentIntent.customerId,
                customerEphemeralKeySecret: paymentIntent.ephemeralKeySecret
            )
            
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
                    paymentAmount: paymentIntent.decimalAmount,
                    pilotEmail: currentUser.email
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
    
    @State private var showCalendarAlert = false
    @State private var calendarAlertMessage = ""
    @State private var calendarAdded = false
    
    private let eventStore = EKEventStore()
    
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
                    if appointment.hasValidZoomLink, let meetingLink = appointment.meetingLink {
                        // Show actual Zoom link with copy button
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "video.fill")
                                    .foregroundColor(.blue)
                                Text("Zoom Meeting Link")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Text(meetingLink)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                Spacer()
                                
                                Button(action: {
                                    UIPasteboard.general.string = meetingLink
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if let password = appointment.zoomMeetingPassword, !password.isEmpty {
                                HStack {
                                    Text("Password: \(password)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: {
                                        UIPasteboard.general.string = password
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.orange)
                            Text("Zoom link will be sent via email")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Add to Calendar Button
            Button(action: {
                addToCalendar()
            }) {
                HStack {
                    Image(systemName: calendarAdded ? "checkmark.circle.fill" : "calendar.badge.plus")
                    Text(calendarAdded ? "Added to Calendar" : "Add to Calendar")
                }
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding()
                .background(calendarAdded ? Color.green.opacity(0.2) : Color(.systemGray5))
                .foregroundColor(calendarAdded ? .green : .primary)
                .cornerRadius(12)
            }
            .disabled(calendarAdded)
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
        .alert("Calendar", isPresented: $showCalendarAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(calendarAlertMessage)
        }
    }
    
    private func addToCalendar() {
        eventStore.requestFullAccessToEvents { granted, error in
            DispatchQueue.main.async {
                if granted {
                    createCalendarEvent()
                } else {
                    calendarAlertMessage = "Calendar access denied. Please enable calendar access in Settings to add this event."
                    showCalendarAlert = true
                }
            }
        }
    }
    
    private func createCalendarEvent() {
        let event = EKEvent(eventStore: eventStore)
        
        // Set event title
        event.title = "\(appointment.examType.displayName) - Buzz"
        
        // Set start and end times
        event.startDate = appointment.scheduledDate
        event.endDate = appointment.endDate
        
        // Set location
        if appointment.locationType == .online {
            if let meetingLink = appointment.meetingLink {
                event.location = meetingLink
            } else {
                event.location = "Online via Zoom"
            }
        } else if let address = appointment.locationAddress {
            event.location = address
        }
        
        // Set notes with details
        var notes = "Exam Type: \(appointment.examType.displayName)\n"
        notes += "Duration: \(appointment.durationMinutes) minutes\n"
        notes += "Format: \(appointment.locationType.displayName)\n"
        
        if appointment.locationType == .online {
            if let meetingLink = appointment.meetingLink {
                notes += "\nZoom Link: \(meetingLink)\n"
            }
            if let password = appointment.zoomMeetingPassword, !password.isEmpty {
                notes += "Password: \(password)\n"
            }
        }
        
        notes += "\nBooked via Buzz App"
        event.notes = notes
        
        // Add 30-minute reminder
        event.addAlarm(EKAlarm(relativeOffset: -1800)) // 30 minutes before
        
        // Add to default calendar
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            calendarAdded = true
            calendarAlertMessage = "Event added to your calendar!"
            showCalendarAlert = true
        } catch {
            calendarAlertMessage = "Failed to add event: \(error.localizedDescription)"
            showCalendarAlert = true
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

