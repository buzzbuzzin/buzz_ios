//
//  CreateDisputeView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/20/26.
//

import SwiftUI

struct CreateDisputeView: View {
    @StateObject private var bookingService = BookingService()
    @Environment(\.dismiss) var dismiss

    let bookingId: UUID
    @State private var selectedReason: DisputeReason = .incorrectCharge
    @State private var description = ""
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Reason") {
                    Picker("Select a reason", selection: $selectedReason) {
                        Text("Incorrect Charge").tag(DisputeReason.incorrectCharge)
                        Text("Service Not Provided").tag(DisputeReason.serviceNotProvided)
                        Text("Quality Issue").tag(DisputeReason.qualityIssue)
                        Text("Safety Concern").tag(DisputeReason.safetyConcern)
                        Text("Other").tag(DisputeReason.other)
                    }
                }

                Section("Description (Optional)") {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }

                Section {
                    Button(action: submitDispute) {
                        HStack {
                            Spacer()
                            if bookingService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text("Submit Dispute")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(bookingService.isLoading)
                }
            }
            .navigationTitle("File Dispute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Dispute Filed", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your dispute has been submitted and is under review.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func submitDispute() {
        Task {
            do {
                _ = try await bookingService.createDispute(
                    bookingId: bookingId,
                    reason: selectedReason.rawValue,
                    description: description.isEmpty ? nil : description
                )
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
