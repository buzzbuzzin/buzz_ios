//
//  ExamSchedulingView.swift
//  Buzz
//
//  Exam scheduling view with calendar, time picker, and location selection
//

import SwiftUI
import Auth

struct ExamSchedulingView: View {
    let examType: ExamType
    let priceInfo: ExamPriceResponse
    var onBookingComplete: (() -> Void)?
    
    @EnvironmentObject var authService: AuthService
    @StateObject private var examService = ExamService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    @State private var selectedTime: Date?
    @State private var locationType: ExamLocationType = .inPerson
    @State private var locationAddress = ""
    @State private var showPaymentView = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var config: ExamTypeConfig {
        examService.getConfig(for: examType)
    }
    
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
                ExamSummaryCard(examType: examType, config: config, priceInfo: priceInfo)
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
                    Text("3. \(config.allowsOnline ? "Select Format" : "Enter Location")")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if config.allowsOnline {
                        // Format Selection for ROC-A
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
                    }
                    
                    // Address Input (for in-person)
                    if locationType == .inPerson {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enter the address where the exam will be conducted:")
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
                        SummaryRow(label: "Exam", value: config.displayName)
                        SummaryRow(label: "Duration", value: "\(config.durationMinutes) minutes")
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
                        
                        SummaryRow(label: "Total", value: priceInfo.formattedPrice, isTotal: true)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // Proceed to Payment Button
                Button(action: {
                    if canProceed {
                        showPaymentView = true
                    } else {
                        showValidationError()
                    }
                }) {
                    HStack {
                        Image(systemName: "creditcard")
                        Text("Proceed to Payment")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canProceed ? examType.color : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canProceed)
                .padding(.horizontal)
                
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("Schedule Exam")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showPaymentView) {
            if let dateTime = scheduledDateTime {
                ExamPaymentView(
                    examType: examType,
                    priceInfo: priceInfo,
                    scheduledDate: dateTime,
                    locationType: locationType,
                    locationAddress: locationType == .inPerson ? locationAddress : nil,
                    onBookingComplete: {
                        showPaymentView = false
                        if let onComplete = onBookingComplete {
                            onComplete()
                        }
                    }
                )
            }
        }
        .alert("Missing Information", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            // Load configs if not already loaded
            await examService.ensureConfigsLoaded()
        }
        .onAppear {
            // Set default location type based on exam
            if !config.allowsOnline {
                locationType = .inPerson
            }
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
}

// MARK: - Supporting Views

struct ExamSummaryCard: View {
    let examType: ExamType
    let config: ExamTypeConfig
    let priceInfo: ExamPriceResponse
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(examType.color.opacity(0.2))
                    .frame(width: 56, height: 56)
                
                Image(systemName: config.icon)
                    .font(.system(size: 24))
                    .foregroundColor(examType.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(config.displayName)
                    .font(.headline)
                
                Text("\(config.durationMinutes) minutes • \(priceInfo.formattedPrice)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TimeSlotButton: View {
    let time: Date
    let isSelected: Bool
    let action: () -> Void
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    var body: some View {
        Button(action: action) {
            Text(timeString)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

struct LocationTypeButton: View {
    let type: ExamLocationType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(type == .inPerson ? "Meet at a specified location" : "Join via video conference")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    var isTotal: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(isTotal ? .headline : .subheadline)
                .foregroundColor(isTotal ? .primary : .secondary)
            
            Spacer()
            
            Text(value)
                .font(isTotal ? .headline : .subheadline)
                .fontWeight(isTotal ? .bold : .regular)
                .foregroundColor(isTotal ? .green : valueColor)
                .lineLimit(1)
        }
    }
}

#Preview {
    NavigationStack {
        ExamSchedulingView(
            examType: .rocA,
            priceInfo: ExamPriceResponse(
                productId: "prod_test",
                priceId: "price_test",
                unitAmount: 4999,
                currency: "usd",
                productName: "ROC-A Exam"
            )
        )
        .environmentObject(AuthService())
    }
}

