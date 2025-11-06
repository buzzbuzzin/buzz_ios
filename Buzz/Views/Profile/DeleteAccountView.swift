//
//  DeleteAccountView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct DeleteAccountView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var confirmationText = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showFinalConfirmAlert = false
    
    private let requiredText = "I understand I am deleting my account and this is irreversible."
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text("Delete Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                
                // Warning Description
                VStack(alignment: .leading, spacing: 12) {
                    Text("This action cannot be undone. This will permanently delete your account and remove all of your data from our servers.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("What will be deleted:")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Your profile and personal information")
                        Text("• All your bookings and history")
                        Text("• Your ratings and reviews")
                        Text("• All uploaded documents and licenses")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                // Confirmation Text Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("To confirm, please type:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(requiredText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    TextField("Type the text above", text: $confirmationText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    if !confirmationText.isEmpty && confirmationText != requiredText {
                        Text("Text does not match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Delete Button
            VStack {
                CustomButton(
                    title: "Delete Account",
                    action: {
                        if confirmationText == requiredText {
                            showFinalConfirmAlert = true
                        }
                    },
                    style: .destructive,
                    isLoading: isLoading,
                    isDisabled: confirmationText != requiredText
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Account", isPresented: $showFinalConfirmAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This action is permanent and cannot be undone. Are you absolutely sure you want to delete your account?")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func deleteAccount() {
        isLoading = true
        Task {
            do {
                try await authService.deleteAccount()
                // Account deleted, user will be signed out automatically
                // Navigation will be handled by auth state change
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

