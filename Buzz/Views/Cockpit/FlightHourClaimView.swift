//
//  FlightHourClaimView.swift
//  Buzz
//
//  Created for flight hour claims feature
//

import SwiftUI
import PhotosUI
import Auth

struct FlightHourClaimView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var claimService = FlightHourClaimService()
    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var claimedFlights: Int = 0
    @State private var claimedHours: String = ""
    @State private var notes: String = ""

    // Photo picker
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    // UI State
    @State private var showSubmitConfirmation = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showHistory = true

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                formSection
                historySection
            }
            .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Flight Hour Claims")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Submit Flight Hour Claim",
            isPresented: $showSubmitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Submit") {
                submitClaim()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Submit a claim for \(claimedFlights) flights and \(claimedHours) hours? This will be reviewed by an admin.")
        }
        .alert("Claim Submitted", isPresented: $showSuccessAlert) {
            Button("OK") {
                resetForm()
            }
        } message: {
            Text("Your flight hour claim has been submitted and is pending review.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .task {
            if let userId = authService.currentUser?.id {
                await claimService.fetchClaims(pilotId: userId)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Flight Hour Claims")
                .font(.title2)
                .fontWeight(.bold)

            Text("Submit your pre-existing flight history for admin review. Approved claims will be added to your pilot stats.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Claim")
                .font(.headline)
                .padding(.horizontal)

            flightsField
            hoursField
            notesField
            evidenceField
            submitButton
        }
    }

    private var flightsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Number of Flights *")
                .font(.subheadline)
                .fontWeight(.medium)

            Stepper(value: $claimedFlights, in: 0...10000) {
                Text("\(claimedFlights) flights")
                    .font(.body)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }

    private var hoursField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Flight Hours *")
                .font(.subheadline)
                .fontWeight(.medium)

            TextField("e.g., 150.5", text: $claimedHours)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.subheadline)
                .fontWeight(.medium)

            TextEditor(text: $notes)
                .frame(minHeight: 80)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )

            Text("e.g., Logbook from 2019-2023, flew Cessna 172")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }

    private var evidenceField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Evidence Files *")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Upload scans of your logbook or other supporting documents (required)")
                .font(.caption)
                .foregroundColor(.secondary)

            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 10,
                matching: .images
            ) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text(selectedImages.isEmpty ? "Select Photos" : "\(selectedImages.count) photo(s) selected")
                }
                .foregroundColor(.orange)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
            .onChange(of: selectedItems) { _, newItems in
                Task {
                    selectedImages = []
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImages.append(image)
                        }
                    }
                }
            }

            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedImages.indices, id: \.self) { index in
                            Image(uiImage: selectedImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }

    private var submitButton: some View {
        Button(action: {
            showSubmitConfirmation = true
        }) {
            HStack {
                if claimService.isSaving {
                    ProgressView()
                        .tint(.white)
                }
                Text(claimService.isSaving ? "Submitting..." : "Submit Claim")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isFormValid ? Color.orange : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!isFormValid || claimService.isSaving)
        .padding(.horizontal)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { showHistory.toggle() }) {
                HStack {
                    Text("Claim History")
                        .font(.headline)
                    Spacer()
                    Image(systemName: showHistory ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)

            if showHistory {
                if claimService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if claimService.claims.isEmpty {
                    Text("No claims submitted yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(claimService.claims) { claim in
                        ClaimHistoryCard(claim: claim)
                            .padding(.horizontal)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var isFormValid: Bool {
        claimedFlights > 0 && (Double(claimedHours) ?? 0) > 0 && !selectedImages.isEmpty
    }

    private func submitClaim() {
        guard let userId = authService.currentUser?.id,
              let hours = Double(claimedHours) else {
            errorMessage = "Invalid form data"
            showErrorAlert = true
            return
        }

        Task {
            do {
                try await claimService.submitClaim(
                    pilotId: userId,
                    claimedFlights: claimedFlights,
                    claimedHours: hours,
                    notes: notes.isEmpty ? nil : notes,
                    evidenceImages: selectedImages
                )
                showSuccessAlert = true
                await claimService.fetchClaims(pilotId: userId)
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    private func resetForm() {
        claimedFlights = 0
        claimedHours = ""
        notes = ""
        selectedItems = []
        selectedImages = []
    }
}

// MARK: - Claim History Card

private struct ClaimHistoryCard: View {
    let claim: FlightHourClaim

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(claim.claimedFlights) flights, \(String(format: "%.1f", claim.claimedHours))h")
                    .font(.headline)
                Spacer()
                statusBadge
            }

            Text("Submitted \(claim.submittedAt, style: .date)")
                .font(.caption)
                .foregroundColor(.secondary)

            if let notes = claim.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            if let reviewerNotes = claim.reviewerNotes, !reviewerNotes.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "message.fill")
                        .font(.caption2)
                    Text("Admin: \(reviewerNotes)")
                        .font(.caption)
                }
                .foregroundColor(claim.status == "rejected" ? .red : .green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var statusBadge: some View {
        Text(claim.statusDisplay)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch claim.status {
        case "pending": return .yellow
        case "approved": return .green
        case "rejected": return .red
        default: return .gray
        }
    }
}
