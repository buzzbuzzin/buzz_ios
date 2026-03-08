//
//  ProctorTestSchedulingView.swift
//  Buzz
//
//  Scheduling view for proctored tests with payment integration
//

import SwiftUI
import Auth
import StripePaymentSheet
import Supabase
import PassKit

struct ProctorTestSchedulingView: View {
    let test: CourseTest
    let course: TrainingCourse
    let pilotId: UUID
    
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var examService = ExamService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    @State private var selectedTime: Date?
    @State private var locationType: ExamLocationType = .inPerson
    @State private var locationAddress = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isProcessingPayment = false
    
    // Stripe Payment Sheet
    @State private var paymentSheet: PaymentSheet?
    @State private var showPaymentSuccess = false
    @State private var presentPayment = false
    @State private var currentPaymentIntent: ExamPaymentIntentResponse?
    
    // Minimum scheduling date is tomorrow
    private var minimumDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }
    
    // Maximum scheduling date is 3 months from now
    private var maximumDate: Date {
        Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    }
    
    private var availableTimeSlots: [Date] {
        examService.getAvailableTimeSlots(for: selectedDate)
    }
    
    private var canProceed: Bool {
        guard selectedTime != nil else { return false }
        
        if locationType == .inPerson {
            return !locationAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        return true
    }
    
    private var scheduledDateTime: Date? {
        guard let time = selectedTime else { return nil }
        
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        return calendar.date(from: combinedComponents)
    }
    
    private var derivedExamType: ExamType {
        switch test.testType {
        case "practical":
            return .flightReview
        case "oral":
            return .rocA
        default:
            return .groundSchoolTest
        }
    }

    private var formattedScheduledDateTime: String {
        guard let dateTime = scheduledDateTime else {
            return "Not selected"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateTime)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Exam Summary Card
                ExamSummaryTestCard(test: test, course: course)
                    .padding(.horizontal)
                
                // Date Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Select Date")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    DatePicker(
                        "Exam Date",
                        selection: $selectedDate,
                        in: minimumDate...maximumDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)
                    .onChange(of: selectedDate) { _, _ in
                        // Reset selected time when date changes
                        selectedTime = nil
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // Time Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("2. Select Time")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text("Choose an available time slot for your exam")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(availableTimeSlots, id: \.self) { slot in
                            TimeSlotButton(
                                time: slot,
                                isSelected: selectedTime == slot,
                                action: {
                                    selectedTime = slot
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                    .padding(.horizontal)
                
                // Location Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("3. Select Location")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        LocationTypeButton(
                            type: .inPerson,
                            isSelected: locationType == .inPerson,
                            action: {
                                locationType = .inPerson
                            }
                        )
                        
                        LocationTypeButton(
                            type: .online,
                            isSelected: locationType == .online,
                            action: {
                                locationType = .online
                            }
                        )
                    }
                    .padding(.horizontal)
                    
                    // Address Input (for in-person)
                    if locationType == .inPerson {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enter the exam location address:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("Street address, City, State, ZIP", text: $locationAddress)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.fullStreetAddress)
                        }
                        .padding(.horizontal)
                    } else {
                        // Online Info Card
                        HStack(spacing: 12) {
                            Image(systemName: "video.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Online Exam via Zoom")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text("A Zoom meeting link will be sent to your email after booking confirmation.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("4. Confirm Details")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        SummaryRow(label: "Exam", value: test.testName)
                        SummaryRow(label: "Duration", value: "\(test.duration ?? 60) minutes")
                        SummaryRow(
                            label: "Date & Time",
                            value: formattedScheduledDateTime,
                            valueColor: scheduledDateTime == nil ? .orange : .primary
                        )
                        SummaryRow(label: "Format", value: locationType.displayName)
                        
                        if locationType == .inPerson && !locationAddress.isEmpty {
                            SummaryRow(label: "Location", value: locationAddress)
                        }
                        
                        Divider()
                        
                        SummaryRow(label: "Total", value: test.formattedPrice, isTotal: true)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // Proceed to Payment Button
                Button(action: {
                    if canProceed {
                        Task {
                            await processPayment()
                        }
                    } else {
                        showValidationError()
                    }
                }) {
                    HStack {
                        if isProcessingPayment {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "creditcard")
                            Text("Proceed to Payment")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canProceed && !isProcessingPayment ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canProceed || isProcessingPayment)
                .padding(.horizontal)
                
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("Schedule Exam")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Missing Information", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Payment Successful", isPresented: $showPaymentSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your exam has been scheduled successfully. You will receive a confirmation email shortly.")
        }
        .task(id: presentPayment) {
            guard presentPayment, let sheet = paymentSheet else { return }
            
            do {
                let result = try await sheet.present()
                handlePaymentCompletion(result)
            } catch {
                errorMessage = "Payment error: \(error.localizedDescription)"
                showError = true
            }
            
            presentPayment = false
            paymentSheet = nil
        }
    }
    
    private func showValidationError() {
        if selectedTime == nil {
            errorMessage = "Please select a time slot for your exam."
        } else if locationType == .inPerson && locationAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Please enter the address where the exam will be conducted."
        } else {
            errorMessage = "Please complete all required fields."
        }
        showError = true
    }

    private func isApplePaySupported() -> Bool {
        // Check if Apple Pay is available on this device
        guard PKPaymentAuthorizationController.canMakePayments() else {
            return false
        }

        // Check if the user has at least one payment card configured
        guard PKPaymentAuthorizationController.canMakePayments(usingNetworks: [.visa, .masterCard, .amex, .discover]) else {
            return false
        }

        return true
    }
    
    private func processPayment() async {
        guard let dateTime = scheduledDateTime,
              let priceInCents = test.priceOfSchedule,
              priceInCents > 0 else {
            // Free exam - just create appointment without payment
            await createFreeAppointment()
            return
        }
        
        isProcessingPayment = true
        
        do {
            // Create payment intent with test price
            let paymentIntent = try await createPaymentIntent(
                amount: priceInCents,
                scheduledDate: dateTime
            )
            
            // Store payment intent for use after payment completes
            currentPaymentIntent = paymentIntent

            // Configure payment sheet
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "Buzz Academy"
            configuration.allowsDelayedPaymentMethods = false

            // Enable Apple Pay if supported
            if isApplePaySupported() {
                configuration.applePay = .init(
                    merchantId: Config.appleMerchantID,
                    merchantCountryCode: "US"
                )
            }
            
            // Initialize payment sheet
            paymentSheet = PaymentSheet(
                paymentIntentClientSecret: paymentIntent.clientSecret,
                configuration: configuration
            )
            
            // Trigger presentation
            presentPayment = true
            isProcessingPayment = false
        } catch {
            isProcessingPayment = false
            errorMessage = "Failed to initialize payment: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func createPaymentIntent(amount: Int, scheduledDate: Date) async throws -> ExamPaymentIntentResponse {
        struct PaymentRequest: Codable {
            let test_id: String
            let pilot_id: String
            let amount: Int
            let scheduled_date: String
            let location_type: String
            let location_address: String?
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let request = PaymentRequest(
            test_id: test.id.uuidString,
            pilot_id: pilotId.uuidString,
            amount: amount,
            scheduled_date: dateFormatter.string(from: scheduledDate),
            location_type: locationType.rawValue,
            location_address: locationType == .inPerson ? locationAddress : nil
        )
        
        let supabase = SupabaseClient.shared.client
        let response: ExamPaymentIntentResponse = try await supabase.functions
            .invoke("create-test-exam-payment", options: FunctionInvokeOptions(
                body: request
            ))
        
        return response
    }
    
    private func createFreeAppointment() async {
        guard let dateTime = scheduledDateTime else { return }

        isProcessingPayment = true

        do {
            _ = try await examService.createExamAppointment(
                pilotId: pilotId,
                examType: derivedExamType,
                scheduledDate: dateTime,
                locationType: locationType,
                locationAddress: locationType == .inPerson ? locationAddress : nil,
                paymentIntentId: "free_\(UUID().uuidString)",
                chargeId: nil,
                paymentAmount: 0,
                pilotEmail: authService.currentUser?.email
            )
            isProcessingPayment = false
            showPaymentSuccess = true
        } catch {
            isProcessingPayment = false
            errorMessage = "Failed to create appointment: \(error.localizedDescription)"
            showError = true
        }
    }

    private func handlePaymentCompletion(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            // Payment successful - create the appointment record
            guard let dateTime = scheduledDateTime,
                  let paymentIntent = currentPaymentIntent else {
                errorMessage = "Payment succeeded but could not create appointment. Please contact support with your payment confirmation."
                showError = true
                return
            }

            Task {
                isProcessingPayment = true
                do {
                    _ = try await examService.createExamAppointment(
                        pilotId: pilotId,
                        examType: derivedExamType,
                        scheduledDate: dateTime,
                        locationType: locationType,
                        locationAddress: locationType == .inPerson ? locationAddress : nil,
                        paymentIntentId: paymentIntent.paymentIntentId,
                        chargeId: nil,
                        paymentAmount: paymentIntent.decimalAmount,
                        pilotEmail: authService.currentUser?.email
                    )
                    isProcessingPayment = false
                    showPaymentSuccess = true
                } catch {
                    isProcessingPayment = false
                    errorMessage = "Payment was successful but we couldn't create your appointment. Please contact support with payment ID: \(paymentIntent.paymentIntentId)"
                    showError = true
                }
            }

        case .cancelled:
            currentPaymentIntent = nil
            // User cancelled - do nothing

        case .failed(let error):
            currentPaymentIntent = nil
            errorMessage = "Payment failed: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Exam Summary Card (specific to ProctorTestSchedulingView)

struct ExamSummaryTestCard: View {
    let test: CourseTest
    let course: TrainingCourse
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 56, height: 56)
                
                Image(systemName: testIcon)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(test.testName)
                    .font(.headline)
                
                Text("\(test.duration ?? 60) minutes • \(test.formattedPrice)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var testIcon: String {
        switch test.testType {
        case "multiple_choice":
            return "doc.text.fill"
        case "oral":
            return "antenna.radiowaves.left.and.right"
        case "practical":
            return "airplane"
        case "written":
            return "pencil.and.outline"
        default:
            return "checkmark.seal.fill"
        }
    }
}
