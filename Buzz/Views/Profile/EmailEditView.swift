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
    @State private var showSuccessAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text("Email")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                
                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("This is the email address associated with your account. A confirmation email will be sent to your new email address.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Important: After confirming your new email, you must log out and log back in with your new email address.")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
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
        .navigationTitle("Email")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                // Refresh auth status to get the latest email from Supabase
                await authService.checkAuthStatus()
                // Then load the current email
                loadCurrentEmail()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Confirmation Email Sent", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("A confirmation email has been sent to \(email). Please check your inbox and click the confirmation link.\n\nAfter confirming, you must log out and log back in with your new email address for the change to take full effect.")
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
        Task {
            do {
                // Use the auth service to change email which will:
                // 1. Update the auth.users email (with confirmation required)
                // 2. Send confirmation email to new address
                // 3. Update profile table
                try await authService.changeEmail(newEmail: email)
                isLoading = false
                showSuccessAlert = true
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

