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
                Text("This is the email address associated with your account.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
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
            loadCurrentEmail()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadCurrentEmail() {
        email = authService.userProfile?.email ?? ""
    }
    
    private func updateEmail() {
        guard let currentUser = authService.currentUser else { return }
        
        isLoading = true
        Task {
            let userId = currentUser.id
            do {
                try await profileService.updateProfile(
                    userId: userId,
                    firstName: nil,
                    lastName: nil,
                    callSign: nil,
                    email: email.isEmpty ? nil : email,
                    phone: nil,
                    gender: nil
                )
                await authService.checkAuthStatus()
                isLoading = false
                dismiss()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

