//
//  EmailEditView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct EmailEditView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var profileService = ProfileService()
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showTokenInput = false
    @State private var showSuccessView = false
    @State private var verificationToken = ""
    @State private var tokenExpiration: Date?
    @State private var timeRemaining: TimeInterval = 0
    @State private var isTokenVerified = false
    @State private var timer: Timer?
    
    var body: some View {
        let _ = print("DEBUG: EmailEditView body - showSuccessView: \(showSuccessView), showTokenInput: \(showTokenInput)")
        
        return VStack(spacing: 0) {
            if showSuccessView {
                // Success confirmation view with logout
                successConfirmationView
            } else if showTokenInput {
                // Token input view
                tokenInputView
            } else {
                // Email edit form
                emailEditFormView
            }
        }
        .navigationTitle("Email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !showSuccessView {
                    Button("Cancel") {
                        stopTimer()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            print("DEBUG: EmailEditView appeared")
            loadCurrentEmail()
        }
        .onDisappear {
            print("DEBUG: EmailEditView disappeared!")
            stopTimer()
        }
        .onChange(of: showSuccessView) { oldValue, newValue in
            print("DEBUG: showSuccessView changed from \(oldValue) to \(newValue)")
        }
        .onChange(of: showTokenInput) { oldValue, newValue in
            print("DEBUG: showTokenInput changed from \(oldValue) to \(newValue)")
        }
        .interactiveDismissDisabled(isLoading || showTokenInput || showSuccessView)
    }
    
    // MARK: - Email Edit Form View
    
    private var emailEditFormView: some View {
        VStack(spacing: 0) {
            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text("Email")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                
                // Error Message (shown inline)
                if showError && !errorMessage.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                            
                            Text("Error")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Spacer()
                            
                            Button(action: {
                                showError = false
                                errorMessage = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("This is the email address associated with your account. A verification code will be sent to your new email address.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("ℹ️ You'll verify your new email with a 6-digit code before logging out.")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !email.isEmpty {
                            Button(action: {
                                email = ""
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
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Update Button
            VStack {
                CustomButton(
                    title: "Update",
                    action: updateEmail,
                    isLoading: isLoading
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Token Input View
    
    private var tokenInputView: some View {
        VStack(spacing: 0) {
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    Text("Verify Your Email")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 8)
                    
                    // Error Message (shown inline)
                    if showError && !errorMessage.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title3)
                                    .foregroundColor(.red)
                                
                                Text("Error")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                
                                Spacer()
                                
                                Button(action: {
                                    showError = false
                                    errorMessage = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Instruction
                    VStack(alignment: .leading, spacing: 12) {
                        Text("We've sent a 6-digit verification code to:")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text(email)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Text("Enter the code below to verify your email change.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Token Input Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Verification Code")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("000000", text: $verificationToken)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                            .font(.system(size: 24, weight: .semibold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .onChange(of: verificationToken) { oldValue, newValue in
                                // Limit to 6 digits
                                if newValue.count > 6 {
                                    verificationToken = String(newValue.prefix(6))
                                }
                            }
                    }
                    
                    // Timer Display
                    if let expiration = tokenExpiration {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(timeRemaining < 300 ? .orange : .secondary)
                            Text(formatTimeRemaining(timeRemaining))
                                .font(.subheadline)
                                .foregroundColor(timeRemaining < 300 ? .orange : .secondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Resend Code Button
                    Button(action: resendCode) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Resend Code")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    .disabled(isLoading)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            
            // Verify Button
            VStack {
                CustomButton(
                    title: "Verify",
                    action: verifyToken,
                    isLoading: isLoading
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .disabled(verificationToken.count != 6)
            }
        }
    }
    
    // MARK: - Success Confirmation View
    
    private var successConfirmationView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // Success Icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                }
                
                // Title
                Text("Email Verified!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Message
                VStack(spacing: 12) {
                    Text("Your email has been successfully changed to:")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text(email)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("You can now log out. Next time, log in with your new email address.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 32)
                
                // Sign Out Button
                CustomButton(
                    title: "Sign Out",
                    action: {
                        Task {
                            try? await authService.signOut()
                            await MainActor.run {
                                dismiss()
                            }
                        }
                    },
                    isLoading: false
                )
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
            
            Spacer()
        }
    }
    
    private func loadCurrentEmail() {
        email = authService.userProfile?.email ?? ""
    }
    
    private func updateEmail() {
        // Validate email format
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            showError = true
            return
        }
        
        // Check if email is different from current
        if email == authService.currentUser?.email || email == authService.userProfile?.email {
            errorMessage = "This is already your current email address"
            showError = true
            return
        }
        
        isLoading = true
        
        print("DEBUG: Starting email change to: \(email)")
        
        Task {
            do {
                // Request email change and get expiration time
                let expiration = try await authService.changeEmail(newEmail: email)
                
                print("DEBUG: Email change token sent successfully!")
                
                // Ensure UI updates happen on the main thread
                await MainActor.run {
                    isLoading = false
                    tokenExpiration = expiration
                    showTokenInput = true
                    startTimer()
                    print("DEBUG: Showing token input view")
                }
            } catch {
                print("DEBUG: Email change failed with error: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                    
                    // Provide user-friendly error messages
                    let errorDescription = error.localizedDescription.lowercased()
                    if errorDescription.contains("rate limit") || errorDescription.contains("over_email_send_rate_limit") {
                        errorMessage = "You have made too many email change requests. Please try again in an hour."
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    
                    showError = true
                }
            }
        }
    }
    
    private func verifyToken() {
        guard verificationToken.count == 6 else {
            errorMessage = "Please enter a valid 6-digit code"
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await authService.verifyEmailChangeToken(token: verificationToken, newEmail: email)
                
                print("DEBUG: Token verified successfully!")
                
                await MainActor.run {
                    isLoading = false
                    stopTimer()
                    showSuccessView = true
                    print("DEBUG: Email verified, showing success view")
                }
            } catch {
                print("DEBUG: Token verification failed: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func resendCode() {
        guard let oldEmail = authService.currentUser?.email else { return }
        
        isLoading = true
        showError = false
        
        Task {
            do {
                let expiration = try await authService.resendEmailChangeToken(oldEmail: oldEmail, newEmail: email)
                
                await MainActor.run {
                    isLoading = false
                    tokenExpiration = expiration
                    verificationToken = ""
                    startTimer()
                    print("DEBUG: Code resent successfully")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to resend code. Please try again."
                    showError = true
                }
            }
        }
    }
    
    private func startTimer() {
        stopTimer() // Stop any existing timer
        
        guard let expiration = tokenExpiration else { return }
        
        // Update time remaining immediately
        timeRemaining = expiration.timeIntervalSinceNow
        
        // Create timer to update every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            DispatchQueue.main.async {
                self.timeRemaining = expiration.timeIntervalSinceNow
                
                if self.timeRemaining <= 0 {
                    self.stopTimer()
                    self.errorMessage = "Verification code has expired. Please request a new one."
                    self.showError = true
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        if seconds <= 0 {
            return "Code expired"
        }
        
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "Code expires in %d:%02d", minutes, secs)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

