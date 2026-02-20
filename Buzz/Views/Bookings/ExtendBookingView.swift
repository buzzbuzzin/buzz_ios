//
//  ExtendBookingView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/20/26.
//

import SwiftUI

struct ExtendBookingView: View {
    @StateObject private var bookingService = BookingService()
    @Environment(\.dismiss) var dismiss

    let booking: Booking
    var onUpdate: (() -> Void)?
    @State private var newScheduledDate: Date
    @State private var newEndDate: Date
    @State private var hasEndDate: Bool
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    init(booking: Booking, onUpdate: (() -> Void)? = nil) {
        self.booking = booking
        self.onUpdate = onUpdate
        let defaultDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        _newScheduledDate = State(initialValue: booking.scheduledDate ?? defaultDate)
        _newEndDate = State(initialValue: booking.endDate ?? defaultDate)
        _hasEndDate = State(initialValue: booking.endDate != nil)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("New Scheduled Date") {
                    DatePicker(
                        "Start Date & Time",
                        selection: $newScheduledDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section {
                    Toggle("Set End Date", isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker(
                            "End Date & Time",
                            selection: $newEndDate,
                            in: newScheduledDate...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                Section {
                    Button(action: updateBooking) {
                        HStack {
                            Spacer()
                            if bookingService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text("Update Booking")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(bookingService.isLoading)
                }
            }
            .navigationTitle("Update Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Booking Updated", isPresented: $showSuccess) {
                Button("OK") {
                    onUpdate?()
                    dismiss()
                }
            } message: {
                Text("Your booking date has been updated successfully.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func updateBooking() {
        Task {
            do {
                try await bookingService.extendBooking(
                    bookingId: booking.id,
                    newScheduledDate: newScheduledDate,
                    newEndDate: hasEndDate ? newEndDate : nil
                )
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
