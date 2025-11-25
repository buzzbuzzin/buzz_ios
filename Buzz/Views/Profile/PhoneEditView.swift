//
//  PhoneEditView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct PhoneEditView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var profileService = ProfileService()
    @Environment(\.dismiss) var dismiss
    
    @State private var currentStep: PhoneUpdateStep = .input
    @State private var selectedCountryCode = "+1" // Default to US
    @State private var phoneNumber = ""
    @State private var otpCode = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    enum PhoneUpdateStep {
        case input
        case verification
        case success
    }
    
    // Common country codes
    let countryCodes = [
        ("+1", "🇺🇸 US/CA"),
        ("+44", "🇬🇧 UK"),
        ("+86", "🇨🇳 China"),
        ("+91", "🇮🇳 India"),
        ("+81", "🇯🇵 Japan"),
        ("+82", "🇰🇷 Korea"),
        ("+33", "🇫🇷 France"),
        ("+49", "🇩🇪 Germany"),
        ("+61", "🇦🇺 Australia"),
        ("+7", "🇷🇺 Russia"),
        ("+55", "🇧🇷 Brazil"),
        ("+52", "🇲🇽 Mexico"),
        ("+39", "🇮🇹 Italy"),
        ("+34", "🇪🇸 Spain"),
        ("+31", "🇳🇱 Netherlands"),
        ("+46", "🇸🇪 Sweden"),
        ("+47", "🇳🇴 Norway"),
        ("+45", "🇩🇰 Denmark"),
        ("+41", "🇨🇭 Switzerland"),
        ("+43", "🇦🇹 Austria"),
        ("+32", "🇧🇪 Belgium"),
        ("+351", "🇵🇹 Portugal"),
        ("+48", "🇵🇱 Poland"),
        ("+420", "🇨🇿 Czech"),
        ("+36", "🇭🇺 Hungary"),
        ("+30", "🇬🇷 Greece"),
        ("+358", "🇫🇮 Finland"),
        ("+353", "🇮🇪 Ireland"),
        ("+64", "🇳🇿 New Zealand"),
        ("+65", "🇸🇬 Singapore"),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            switch currentStep {
            case .input:
                phoneInputView
            case .verification:
                otpVerificationView
            case .success:
                successView
            }
        }
        .navigationTitle("Phone")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentPhone()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Phone Input View
    
    private var phoneInputView: some View {
        VStack(spacing: 0) {
            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text("Phone")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                
                // Description
                Text("This is the phone number associated with your account.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Phone Field with Country Code
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone Number")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        // Country Code Picker
                        Menu {
                            ForEach(countryCodes, id: \.0) { code, name in
                                Button(action: {
                                    selectedCountryCode = code
                                }) {
                                    HStack {
                                        Text("\(name) \(code)")
                                        if selectedCountryCode == code {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(selectedCountryCode)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        
                        // Phone Number Input
                        HStack {
                            TextField("Phone Number", text: $phoneNumber)
                                .keyboardType(.phonePad)
                                .textFieldStyle(PlainTextFieldStyle())
                            
                            if !phoneNumber.isEmpty {
                                Button(action: {
                                    phoneNumber = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    Text("Enter phone number without country code")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Update Button
            VStack {
                CustomButton(
                    title: "Update",
                    action: sendOTP,
                    isLoading: isLoading,
                    isDisabled: phoneNumber.isEmpty
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - OTP Verification View
    
    private var otpVerificationView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                Spacer()
                
                VStack(spacing: 16) {
                    Text("Enter verification code")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text("We sent a 6-digit code to \(fullPhoneNumber)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // 6-Box OTP Input
                OTPInputView(otpCode: $otpCode)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                CustomButton(
                    title: "Verify",
                    action: verifyOTP,
                    isLoading: isLoading,
                    isDisabled: otpCode.count != 6
                )
                .padding(.horizontal)
                
                Button("Resend Code") {
                    sendOTP()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding(.top, 8)
                
                Spacer()
            }
            .padding(.top, 40)
        }
    }
    
    // MARK: - Success View
    
    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 12) {
                Text("Phone Verified!")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Your phone number has been successfully verified and updated.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            CustomButton(
                title: "Done",
                action: {
                    dismiss()
                },
                isLoading: false
            )
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 40)
    }
    
    // MARK: - Computed Properties
    
    private var fullPhoneNumber: String {
        return "\(selectedCountryCode)\(phoneNumber)"
    }
    
    // MARK: - Actions
    
    private func loadCurrentPhone() {
        if let currentPhone = authService.userProfile?.phone, !currentPhone.isEmpty {
            // Parse existing phone number
            parsePhoneNumber(currentPhone)
        }
    }
    
    private func parsePhoneNumber(_ phone: String) {
        // Find matching country code
        for (code, _) in countryCodes {
            if phone.hasPrefix(code) {
                selectedCountryCode = code
                phoneNumber = String(phone.dropFirst(code.count))
                return
            }
        }
        // If no match found, assume it's already formatted
        phoneNumber = phone
    }
    
    private func sendOTP() {
        guard !phoneNumber.isEmpty else {
            errorMessage = "Please enter a phone number"
            showError = true
            return
        }
        
        isLoading = true
        Task {
            do {
                try await authService.sendPhoneUpdateOTP(phone: fullPhoneNumber)
                isLoading = false
                currentStep = .verification
                otpCode = "" // Reset OTP code
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func verifyOTP() {
        guard otpCode.count == 6 else {
            errorMessage = "Please enter the 6-digit code"
            showError = true
            return
        }
        
        isLoading = true
        Task {
            do {
                try await authService.verifyPhoneUpdateOTP(phone: fullPhoneNumber, token: otpCode)
                isLoading = false
                currentStep = .success
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
