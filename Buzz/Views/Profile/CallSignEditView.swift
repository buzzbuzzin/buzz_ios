//
//  CallSignEditView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct CallSignEditView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var profileService = ProfileService()
    @Environment(\.dismiss) var dismiss
    
    @State private var callSign = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var callSignValidationError: String? = nil
    @State private var isCheckingCallSignAvailability = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text("Call Sign")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                
                // Description
                Text("This is your unique call sign that other users will see when referring to you.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Call Sign Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Call Sign")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Call Sign", text: $callSign)
                            .autocapitalization(.allCharacters)
                            .autocorrectionDisabled()
                            .textFieldStyle(PlainTextFieldStyle())
                            .onChange(of: callSign) { _, newValue in
                                // Filter to only allow letters and convert to uppercase
                                let filtered = newValue.uppercased().filter { $0.isLetter }
                                if filtered != newValue {
                                    callSign = filtered
                                } else {
                                    callSign = newValue.uppercased()
                                }
                                
                                // Validate callsign as user types
                                validateCallSign()
                            }
                        
                        if !callSign.isEmpty {
                            Button(action: {
                                callSign = ""
                                callSignValidationError = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(callSignValidationError != nil ? Color.red : Color.clear, lineWidth: 1)
                    )
                
                // Validation message or hint
                if let error = callSignValidationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                } else if !callSign.isEmpty {
                    if isCheckingCallSignAvailability {
                        Text("Checking availability...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Update Button
            VStack {
                CustomButton(
                    title: "Update",
                    action: updateCallSign,
                    isLoading: isLoading,
                    isDisabled: callSignValidationError != nil || isCheckingCallSignAvailability
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Call Sign")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentCallSign()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadCurrentCallSign() {
        callSign = authService.userProfile?.callSign ?? ""
    }
    
    private func validateCallSign() {
        let normalizedCallSign = callSign.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Reset validation error
        callSignValidationError = nil
        
        // Empty callsign is allowed
        guard !normalizedCallSign.isEmpty else {
            return
        }
        
        // Check if callsign contains only letters (should already be filtered, but double-check)
        if !normalizedCallSign.allSatisfy({ $0.isLetter }) {
            callSignValidationError = "Call sign can only contain letters"
            return
        }
        
        // Check for reserved word "Maverick" (case-insensitive)
        if normalizedCallSign == "MAVERICK" {
            callSignValidationError = "Call sign 'Maverick' is reserved and cannot be used"
            return
        }
        
        // Check uniqueness (only if changed from current)
        let currentCallSign = authService.userProfile?.callSign?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if normalizedCallSign != currentCallSign {
            checkCallSignAvailability()
        }
    }
    
    private func checkCallSignAvailability() {
        let normalizedCallSign = callSign.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !normalizedCallSign.isEmpty else {
            return
        }
        
        // Skip check if it's the same as current callsign
        let currentCallSign = authService.userProfile?.callSign?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if normalizedCallSign == currentCallSign {
            return
        }
        
        isCheckingCallSignAvailability = true
        
        Task {
            do {
                let isAvailable = try await profileService.checkCallSignAvailability(callSign: normalizedCallSign)
                
                await MainActor.run {
                    isCheckingCallSignAvailability = false
                    
                    if !isAvailable {
                        callSignValidationError = "This call sign is already taken"
                    } else {
                        callSignValidationError = nil
                    }
                }
            } catch {
                await MainActor.run {
                    isCheckingCallSignAvailability = false
                    // Don't show error for check failure - will be caught during update
                    callSignValidationError = nil
                }
            }
        }
    }
    
    private func updateCallSign() {
        // Final validation before update
        let normalizedCallSign = callSign.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If callsign is not empty, validate it
        if !normalizedCallSign.isEmpty {
            // Check for reserved word
            if normalizedCallSign == "MAVERICK" {
                errorMessage = "Call sign 'Maverick' is reserved and cannot be used"
                showError = true
                return
            }
            
            // Ensure callsign only contains letters
            if !normalizedCallSign.allSatisfy({ $0.isLetter }) {
                errorMessage = "Call sign can only contain letters"
                showError = true
                return
            }
        }
        
        guard let currentUser = authService.currentUser else { return }
        
        isLoading = true
        Task {
            let userId = currentUser.id
            do {
                // Double-check availability before update (only if changed)
                let currentCallSign = authService.userProfile?.callSign?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !normalizedCallSign.isEmpty && normalizedCallSign != currentCallSign {
                    let isAvailable = try await profileService.checkCallSignAvailability(callSign: normalizedCallSign)
                    
                    if !isAvailable {
                        await MainActor.run {
                            isLoading = false
                            callSignValidationError = "This call sign is already taken"
                            errorMessage = "This call sign is already taken. Please choose a different one."
                            showError = true
                        }
                        return
                    }
                }
                
                try await profileService.updateProfile(
                    userId: userId,
                    firstName: nil,
                    lastName: nil,
                    callSign: normalizedCallSign.isEmpty ? nil : normalizedCallSign,
                    email: nil,
                    phone: nil,
                    gender: nil
                )
                await authService.checkAuthStatus()
                isLoading = false
                dismiss()
            } catch {
                isLoading = false
                // Check if error is related to callsign uniqueness
                let errorDescription = error.localizedDescription
                if errorDescription.lowercased().contains("call") || errorDescription.lowercased().contains("unique") || errorDescription.lowercased().contains("duplicate") {
                    callSignValidationError = "This call sign is already taken"
                    errorMessage = "This call sign is already taken. Please choose a different one."
                } else {
                    errorMessage = errorDescription
                }
                showError = true
            }
        }
    }
}

