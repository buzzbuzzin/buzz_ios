//
//  VeteranVerificationView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI

enum MilitaryBranch: String, CaseIterable {
    case army = "Army"
    case navy = "Navy"
    case airForce = "Air Force"
    case marineCorps = "Marine Corps"
    case coastGuard = "Coast Guard"
    case spaceForce = "Space Force"
    case nationalGuard = "National Guard"
    case reserves = "Reserves"
    case other = "Other"
    
    var displayName: String {
        return rawValue
    }
}

struct VeteranVerificationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var profileService: ProfileService
    @ObservedObject var badgeService: BadgeService
    let userId: UUID
    
    @State private var serviceName = ""
    @State private var serviceCountry = ""
    @State private var selectedBranch: MilitaryBranch?
    @State private var serviceNumber = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case serviceName
        case serviceCountry
        case serviceNumber
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Header message
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "shield.fill")
                                .font(.title2)
                                .foregroundColor(.purple)
                            Text("Thank You for Your Service")
                                .font(.headline)
                        }
                        
                        Text("Buzz is founded by veterans and we appreciate your service. Veterans can receive multiple benefits, not limited to:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Discount prices in Shop", systemImage: "tag.fill")
                            Label("Training courses", systemImage: "book.fill")
                            Label("Exclusive veteran benefits", systemImage: "star.fill")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 8)
                }
                
                // Form fields
                Section("Veteran Information") {
                    TextField("Full Name on Service/Veteran Card", text: $serviceName)
                        .textContentType(.name)
                        .focused($focusedField, equals: .serviceName)
                    
                    TextField("Service Country", text: $serviceCountry)
                        .textContentType(.countryName)
                        .focused($focusedField, equals: .serviceCountry)
                    
                    Picker("Military Branch", selection: $selectedBranch) {
                        Text("Select Branch").tag(nil as MilitaryBranch?)
                        ForEach(MilitaryBranch.allCases, id: \.self) { branch in
                            Text(branch.displayName).tag(branch as MilitaryBranch?)
                        }
                    }
                    
                    TextField("Service Number", text: $serviceNumber)
                        .textContentType(.none)
                        .keyboardType(.default)
                        .focused($focusedField, equals: .serviceNumber)
                }
                
                // Submit button
                Section {
                    Button(action: submitVerification) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Submit Verification")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                    }
                    .disabled(!isFormValid || isLoading)
                    .listRowBackground(isFormValid && !isLoading ? Color.purple : Color.gray.opacity(0.3))
                }
            }
            .navigationTitle("Veteran Verification")
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
        }
    }
    
    private var isFormValid: Bool {
        !serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !serviceCountry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedBranch != nil &&
        !serviceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func submitVerification() {
        guard isFormValid else { return }
        
        isLoading = true
        focusedField = nil
        
        Task {
            do {
                if DemoModeManager.shared.isDemoModeEnabled {
                    // In demo mode, just simulate the update
                    print("Demo Mode: Would update veteran verification with:")
                    print("  Service Name: \(serviceName)")
                    print("  Service Country: \(serviceCountry)")
                    print("  Military Branch: \(selectedBranch?.displayName ?? "N/A")")
                    print("  Service Number: \(serviceNumber)")
                    
                    // Refresh badges to show the badge as earned
                    try? await badgeService.fetchPilotBadges(pilotId: userId)
                    try? await badgeService.fetchAvailableBadges(pilotId: userId)
                } else {
                    // Update the profile with veteran information
                    try await profileService.updateVeteranVerification(
                        userId: userId,
                        serviceName: serviceName.trimmingCharacters(in: .whitespacesAndNewlines),
                        serviceCountry: serviceCountry.trimmingCharacters(in: .whitespacesAndNewlines),
                        militaryBranch: selectedBranch?.rawValue ?? "",
                        serviceNumber: serviceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    
                    // Refresh badges - the database trigger should automatically award the badge
                    try await badgeService.fetchPilotBadges(pilotId: userId)
                    try await badgeService.fetchAvailableBadges(pilotId: userId)
                }
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

