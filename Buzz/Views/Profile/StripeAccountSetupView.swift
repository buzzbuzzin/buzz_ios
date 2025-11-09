//
//  StripeAccountSetupView.swift
//  Buzz
//
//  Created for Stripe Connect Express account setup
//

import SwiftUI
import UIKit
import SafariServices
import Auth

struct StripeAccountSetupView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var stripeConnectService = StripeConnectService()
    @Environment(\.dismiss) var dismiss
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var accountId: String?
    @State private var accountStatus: StripeConnectService.StripeAccountStatus?
    @State private var isLoadingAccount = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text("Payment Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                
                // Description
                Text("Set up your Stripe Express account to receive payments for completed bookings. You'll need to provide business information and link a bank account.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if isLoadingAccount || stripeConnectService.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                } else if accountId != nil {
                    // Show account status
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: accountStatus?.canReceivePayments == true ? "checkmark.circle.fill" : "clock.fill")
                                .foregroundColor(accountStatus?.canReceivePayments == true ? .green : .orange)
                            Text("Account Created")
                                .font(.headline)
                        }
                        
                        HStack {
                            Text("Status:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(accountStatus?.displayName ?? "Unknown")
                                .fontWeight(.semibold)
                                .foregroundColor(statusColor(accountStatus))
                        }
                        
                        if accountStatus?.canReceivePayments != true {
                            Text("Complete onboarding to start receiving payments")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Status message
                    if accountStatus?.canReceivePayments == true {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Account Active")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                    
                                    Text("Your payment account is set up and ready. You'll receive payments automatically when bookings are completed.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Complete Onboarding")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                    
                                    Text("Finish setting up your account to receive payments. This includes verifying your identity and linking a bank account.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }
                } else {
                    // No account created yet
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Get Started")
                                    .font(.headline)
                                
                                Text("Create your payment account to start receiving payments for completed bookings.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // Action button
                if accountStatus?.canReceivePayments != true {
                    CustomButton(
                        title: accountId == nil ? "Set Up Payment Account" : "Complete Onboarding",
                        action: startOnboarding
                    )
                }
                
                // Info section
                VStack(alignment: .leading, spacing: 12) {
                    Text("What you'll need:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        StripeInfoRow(icon: "person.fill", text: "Personal information")
                        StripeInfoRow(icon: "building.2.fill", text: "Business details (if applicable)")
                        StripeInfoRow(icon: "banknote.fill", text: "Bank account information")
                        StripeInfoRow(icon: "doc.text.fill", text: "Tax information")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("Payment Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            print("👀 StripeAccountSetupView: View appeared, loading account status")
            loadAccountStatus()
        }
        .onChange(of: accountId) { oldValue, newValue in
            print("🔄 StripeAccountSetupView: Account ID changed from \(oldValue ?? "nil") to \(newValue ?? "nil")")
            if newValue != nil && oldValue == nil {
                // Account was just created, refresh status
                Task {
                    await loadAccountStatusAsync()
                }
            }
        }
        .refreshable {
            await loadAccountStatusAsync()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await loadAccountStatusAsync()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
    
    private func statusColor(_ status: StripeConnectService.StripeAccountStatus?) -> Color {
        guard let status = status else { return .secondary }
        switch status {
        case .notCreated:
            return .secondary
        case .onboarding, .pending:
            return .orange
        case .active:
            return .green
        case .restricted:
            return .red
        }
    }
    
    private func loadAccountStatusAsync() async {
        guard let userId = authService.currentUser?.id else {
            print("⚠️ StripeAccountSetupView: No user ID available")
            return
        }
        
        print("🔄 StripeAccountSetupView: Loading account status for user \(userId)")
        
        await MainActor.run {
            isLoadingAccount = true
        }
        
        do {
            let id = try await stripeConnectService.getAccountId(userId: userId)
            print("📋 StripeAccountSetupView: Account ID from profile: \(id ?? "nil")")
            
            await MainActor.run {
                self.accountId = id
            }
            
            if let accountId = id {
                print("✅ StripeAccountSetupView: Account exists, checking status...")
                // Check actual account status
                do {
                    let status = try await stripeConnectService.checkAccountStatus(accountId: accountId)
                    print("📊 StripeAccountSetupView: Account status: \(status.displayName)")
                    await MainActor.run {
                        self.accountStatus = status
                        self.isLoadingAccount = false
                    }
                } catch {
                    print("❌ Error checking account status: \(error)")
                    // If status check fails, default to onboarding
                    await MainActor.run {
                        self.accountStatus = .onboarding
                        self.isLoadingAccount = false
                    }
                }
            } else {
                print("ℹ️ StripeAccountSetupView: No account ID found in profile")
                await MainActor.run {
                    self.accountStatus = .notCreated
                    self.isLoadingAccount = false
                }
            }
        } catch {
            print("❌ StripeAccountSetupView: Error loading account: \(error)")
            await MainActor.run {
                self.isLoadingAccount = false
                // Don't show error if account just doesn't exist yet
                if !error.localizedDescription.contains("not found") {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
    
    private func loadAccountStatus() {
        Task {
            await loadAccountStatusAsync()
        }
    }
    
    private func startOnboarding() {
        guard let userId = authService.currentUser?.id else {
            errorMessage = "User not authenticated"
            showError = true
            return
        }
        
        Task {
            do {
                let email = authService.currentUser?.email ?? authService.userProfile?.email
                
                // Get root view controller
                guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = await windowScene.windows.first?.rootViewController else {
                    await MainActor.run {
                        errorMessage = "Unable to present onboarding"
                        showError = true
                    }
                    return
                }
                
                // Find topmost view controller
                var topController = rootViewController
                while let presented = topController.presentedViewController {
                    topController = presented
                }
                
                // Start onboarding flow
                try await stripeConnectService.startOnboardingFlow(
                    userId: userId,
                    email: email,
                    from: topController
                )
                
                // Reload account status after onboarding with a delay
                // Give Stripe time to process the onboarding completion
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                await MainActor.run {
                    loadAccountStatus()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Stripe Info Row

struct StripeInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

