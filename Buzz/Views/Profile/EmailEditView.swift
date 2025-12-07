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
    @State private var showSuccessView = false
    
    var body: some View {
        VStack(spacing: 0) {
            if showSuccessView {
                // Success confirmation view
                successConfirmationView
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
            print("DEBUG: EmailEditView disappeared! showSuccessView was: \(showSuccessView)")
        }
        .onChange(of: showSuccessView) { oldValue, newValue in
            print("DEBUG: showSuccessView changed from \(oldValue) to \(newValue)")
        }
        .interactiveDismissDisabled(isLoading || showSuccessView)
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
                    Text("This is the email address associated with your account. A confirmation email will be sent to your new email address.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("⚠️ Important: You will be automatically logged out after requesting the email change. After confirming via the email link, log back in with your new email address.")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.orange.opacity(0.1))
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
                Text("Email Change Request Complete")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Message
                VStack(spacing: 12) {
                    Text("The email change request is complete. You will need to check your email to confirm the change.")
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("Logging out is required for email change to take effect.")
                        .font(.body)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                    
                    Text("After confirming via the email link, log back in with your new email address.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                
                // Log Out Button
                CustomButton(
                    title: "Log Out",
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
        guard let currentUser = authService.currentUser else { return }
        
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
                // Use the auth service to change email which will:
                // 1. Update the auth.users email (with confirmation required)
                // 2. Send confirmation email to new address
                try await authService.changeEmail(newEmail: email)
                
                print("DEBUG: Email change succeeded!")
                
                // Small delay to ensure auth service completes
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Ensure UI updates happen on the main thread
                await MainActor.run {
                    print("DEBUG: Setting showSuccessView = true")
                    isLoading = false
                    showSuccessView = true
                    print("DEBUG: showSuccessView is now: \(showSuccessView)")
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
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

