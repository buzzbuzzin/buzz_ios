//
//  ChangePasswordView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct ChangePasswordView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var showConfirmAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text("Change Password")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                
                // Description
                Text("Enter your current password and choose a new one.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Current Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Password")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    SecureField("Current Password", text: $currentPassword)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                // New Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Password")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    SecureField("New Password", text: $newPassword)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                // Confirm Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm New Password")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    SecureField("Confirm New Password", text: $confirmPassword)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                if !newPassword.isEmpty && newPassword != confirmPassword {
                    Text("Passwords do not match")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Update Button
            VStack {
                CustomButton(
                    title: "Change Password",
                    action: {
                        showConfirmAlert = true
                    },
                    isLoading: isLoading,
                    isDisabled: !isFormValid
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Change Password", isPresented: $showConfirmAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Change", role: .destructive) {
                changePassword()
            }
        } message: {
            Text("Are you sure you want to change your password?")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Password changed successfully")
        }
    }
    
    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 6
    }
    
    private func changePassword() {
        guard isFormValid else { return }
        
        isLoading = true
        Task {
            do {
                // First verify current password
                let isValid = try await authService.verifyCurrentPassword(password: currentPassword)
                
                if !isValid {
                    isLoading = false
                    errorMessage = "Current password is incorrect"
                    showError = true
                    return
                }
                
                // Change password
                try await authService.changePassword(newPassword: newPassword)
                
                isLoading = false
                showSuccess = true
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

