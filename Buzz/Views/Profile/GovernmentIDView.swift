//
//  GovernmentIDView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import LocalAuthentication
import Auth
import UIKit

struct GovernmentIDView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var identityService = IdentityVerificationService()
    @Environment(\.dismiss) var dismiss
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeleteAlert = false
    @State private var isAuthenticated = false
    @State private var showAuthPrompt = true
    
    var body: some View {
        VStack(spacing: 0) {
            if showAuthPrompt && !isAuthenticated {
                // Authentication prompt
                VStack(spacing: 24) {
                    Image(systemName: "faceid")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Verify Your Identity")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Please authenticate with Face ID to verify your identity. You'll need to provide your government-issued ID and a selfie photo.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    CustomButton(
                        title: "Authenticate with Face ID",
                        action: authenticateWithFaceID
                    )
                    .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Content
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    Text("Government ID")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 8)
                    
                    // Description
                    Text("Verify your identity using Stripe Identity. You'll need to provide both your government-issued ID and a selfie photo. This secure service helps ensure the safety and security of our platform.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if identityService.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    } else if let governmentID = identityService.governmentID {
                        // Show uploaded ID info
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("ID Uploaded")
                                    .font(.headline)
                            }
                            
                            HStack {
                                Text("Status:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(governmentID.verificationStatus.displayName)
                                    .fontWeight(.semibold)
                                    .foregroundColor(statusColor(governmentID.verificationStatus))
                            }
                            
                            HStack {
                                Text("Uploaded:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(governmentID.uploadedAt, style: .date)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Show Remove ID button only for rejected status
                            // For verified and pending, hide the button
                            if governmentID.verificationStatus == .rejected {
                                Button(action: {
                                    startStripeVerification()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Retry Verification")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                        // Status message based on verification status
                        VStack(alignment: .leading, spacing: 12) {
                            if governmentID.verificationStatus == .verified {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Identity Verified")
                                            .font(.headline)
                                            .foregroundColor(.green)
                                        
                                        Text("Your identity has been successfully verified. You can now accept bookings and start working as a pilot.")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(10)
                            } else if governmentID.verificationStatus == .rejected {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Verification Failed")
                                            .font(.headline)
                                            .foregroundColor(.red)
                                        
                                        Text("Your identity verification was not successful. Please try again to verify your ID.")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Button(action: {
                                            startStripeVerification()
                                        }) {
                                            HStack {
                                                Image(systemName: "arrow.clockwise")
                                                Text("Retry Verification")
                                            }
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.blue)
                                            .cornerRadius(8)
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(10)
                            } else {
                                // Pending status
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.orange)
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Verification Pending")
                                            .font(.headline)
                                            .foregroundColor(.orange)
                                        
                                        Text("Your identity verification is being processed. You cannot accept bookings until your identity is verified.")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.top, 8)
                    } else {
                        // Stripe Identity verification button
                        VStack(spacing: 16) {
                            Button(action: {
                                startStripeVerification()
                            }) {
                                HStack {
                                    Image(systemName: "person.badge.shield.checkmark.fill")
                                    Text("Verify Identity with Stripe")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            
                            Text("Stripe Identity securely verifies your identity by comparing your government-issued ID with a selfie photo. Your information is encrypted and protected.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Government ID")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Delete ID", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteID()
            }
        } message: {
            Text("Are you sure you want to remove your government ID?")
        }
        .task {
            await loadGovernmentID()
        }
    }
    
    private func authenticateWithFaceID() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Please authenticate to upload your driver's license for identity verification."
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        isAuthenticated = true
                        showAuthPrompt = false
                    } else {
                        errorMessage = authenticationError?.localizedDescription ?? "Authentication failed"
                        showError = true
                    }
                }
            }
        } else {
            // Fallback to device passcode if biometrics not available
            let context = LAContext()
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Please authenticate to upload your driver's license.") { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        isAuthenticated = true
                        showAuthPrompt = false
                    } else {
                        errorMessage = authenticationError?.localizedDescription ?? "Authentication failed"
                        showError = true
                    }
                }
            }
        }
    }
    
    private func statusColor(_ status: VerificationStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .verified: return .green
        case .rejected: return .red
        }
    }
    
    private func loadGovernmentID() async {
        guard let currentUser = authService.currentUser else { return }
        try? await identityService.fetchGovernmentID(userId: currentUser.id)
    }
    
    private func startStripeVerification() {
        guard isAuthenticated,
              let currentUser = authService.currentUser else {
            errorMessage = "Please authenticate first"
            showError = true
            return
        }
        
        Task {
            do {
                // Get user email for verification
                let email = currentUser.email ?? authService.userProfile?.email
                
                // Create verification session
                let clientSecret = try await identityService.createVerificationSession(
                    userId: currentUser.id,
                    email: email
                )
                
                // Get the root view controller to present the verification sheet
                guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = await windowScene.windows.first?.rootViewController else {
                    errorMessage = "Unable to present verification"
                    showError = true
                    return
                }
                
                // Find the topmost view controller
                var topController = rootViewController
                while let presented = topController.presentedViewController {
                    topController = presented
                }
                
                // Present Stripe Identity verification flow
                let result = try await identityService.presentVerificationFlow(
                    clientSecret: clientSecret,
                    from: topController
                )
                
                // Handle the result
                try await identityService.handleVerificationResult(
                    result,
                    userId: currentUser.id,
                    sessionId: extractSessionId(from: clientSecret)
                )
                
                // Reload to show updated status
                await loadGovernmentID()
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    /// Extracts session ID from client secret (format: vs_xxx_secret_yyy)
    private func extractSessionId(from clientSecret: String) -> String? {
        let components = clientSecret.components(separatedBy: "_secret_")
        return components.first
    }
    
    private func deleteID() {
        Task {
            do {
                try await identityService.deleteGovernmentID()
                await loadGovernmentID()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

