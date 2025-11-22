//
//  PasswordResetFlowView.swift
//  Buzz
//
//  Created for password reset flow with OTP verification
//

import SwiftUI

struct PasswordResetFlowView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var currentStep: ResetStep = .email
    @State private var email = ""
    @State private var otpCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    enum ResetStep {
        case email
        case otp
        case password
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Content based on current step
                switch currentStep {
                case .email:
                    emailStepView
                case .otp:
                    otpStepView
                case .password:
                    passwordStepView
                }
            }
            .navigationTitle("Reset Password")
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
    
    // MARK: - Email Step
    
    private var emailStepView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("Enter your email address")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("We'll send you a 6-digit code to reset your password")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            CustomButton(
                title: "Send Code",
                action: sendOTP,
                isLoading: isLoading,
                isDisabled: !isEmailValid
            )
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 40)
    }
    
    // MARK: - OTP Step
    
    private var otpStepView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("Enter verification code")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("We sent a 6-digit code to \(email)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                TextField("Enter 6-digit code", text: $otpCode)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .onChange(of: otpCode) { _, newValue in
                        // Limit to 6 digits
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered.count <= 6 {
                            otpCode = filtered
                        } else {
                            otpCode = String(filtered.prefix(6))
                        }
                    }
            }
            .padding(.horizontal)
            
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
    
    // MARK: - Password Step
    
    private var passwordStepView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("Set new password")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("Choose a strong password for your account")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("New Password", text: $newPassword)
                        .textContentType(.newPassword)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    Text("Min 8 chars: uppercase, lowercase, digit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("Confirm New Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    if !confirmPassword.isEmpty && newPassword != confirmPassword {
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal)
            
            CustomButton(
                title: "Confirm New Password",
                action: resetPassword,
                isLoading: isLoading,
                isDisabled: !isPasswordFormValid
            )
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 40)
    }
    
    // MARK: - Validation
    
    private var isEmailValid: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }
    
    private var isPasswordFormValid: Bool {
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        isValidPassword(newPassword)
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        // Minimum 8 characters
        guard password.count >= 8 else { return false }
        
        // Check for at least one lowercase letter
        let hasLowercase = password.rangeOfCharacter(from: CharacterSet.lowercaseLetters) != nil
        
        // Check for at least one uppercase letter
        let hasUppercase = password.rangeOfCharacter(from: CharacterSet.uppercaseLetters) != nil
        
        // Check for at least one digit
        let hasDigit = password.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
        
        return hasLowercase && hasUppercase && hasDigit
    }
    
    // MARK: - Actions
    
    private func sendOTP() {
        guard isEmailValid else {
            errorMessage = "Please enter a valid email address"
            showError = true
            return
        }
        
        isLoading = true
        Task {
            do {
                try await authService.sendPasswordResetOTP(email: email)
                isLoading = false
                currentStep = .otp
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
                try await authService.verifyPasswordResetOTP(email: email, token: otpCode)
                isLoading = false
                currentStep = .password
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func resetPassword() {
        guard isPasswordFormValid else {
            if !isValidPassword(newPassword) {
                errorMessage = "Password must be at least 8 characters and include uppercase, lowercase, and a digit"
            } else if newPassword != confirmPassword {
                errorMessage = "Passwords do not match"
            } else {
                errorMessage = "Please fill in all fields"
            }
            showError = true
            return
        }
        
        isLoading = true
        Task {
            do {
                try await authService.resetPasswordWithOTP(newPassword: newPassword)
                isLoading = false
                // User is now authenticated, dismiss the view
                dismiss()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

