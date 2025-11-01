//
//  SignUpView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var userType: UserType = .pilot
    @State private var callSign = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSigningUp = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Join Buzz")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Start your drone pilot journey")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // User Type Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("I am a...")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            UserTypeButton(
                                title: "Pilot",
                                icon: "airplane",
                                isSelected: userType == .pilot
                            ) {
                                userType = .pilot
                            }
                            
                            UserTypeButton(
                                title: "Customer",
                                icon: "person.fill",
                                isSelected: userType == .customer
                            ) {
                                userType = .customer
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Form Fields
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        
                        SecureField("Password", text: $password)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        
                        if userType == .pilot {
                            TextField("Call Sign", text: $callSign)
                                .textContentType(.nickname)
                                .autocapitalization(.allCharacters)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            
                            Text("Your unique pilot identifier")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Sign Up Button
                    CustomButton(
                        title: "Sign Up",
                        action: signUp,
                        isLoading: authService.isLoading || isSigningUp,
                        isDisabled: !isFormValid
                    )
                    .padding(.horizontal)
                    
                    if isSigningUp {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Creating your account...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                    
                    // Sign In Link
                    HStack {
                        Text("Already have an account?")
                            .foregroundColor(.secondary)
                        Button("Sign In") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    // User is now authenticated, dismiss the signup view
                    dismiss()
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 6 &&
        (userType == .customer || !callSign.isEmpty)
    }
    
    private func signUp() {
        isSigningUp = true
        Task {
            do {
                try await authService.signUpWithEmail(
                    email: email,
                    password: password,
                    userType: userType,
                    callSign: userType == .pilot ? callSign : nil
                )
                
                // Success! The app will automatically navigate to main view
                // because authService.isAuthenticated is now true
                isSigningUp = false
                
            } catch {
                isSigningUp = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct UserTypeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

