//
//  OnboardingVerificationView.swift
//  Buzz
//

import SwiftUI
import Combine
import LocalAuthentication
import UIKit
import Auth

struct OnboardingVerificationView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject var verificationGate: VerificationGate
    @StateObject private var identityService = IdentityVerificationService()

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isStartingVerification = false
    @State private var isSigningOut = false

    private let pollTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 40)

                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.blue)

                Text("One more step")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Verify your government-issued ID to finish setting up your Buzz account. This keeps the platform safe for everyone who flies with us.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                statusContent
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Spacer()

                Button(action: signOut) {
                    if isSigningOut {
                        ProgressView()
                    } else {
                        Text("Sign Out")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(isSigningOut)
                .padding(.bottom, 24)
            }
        }
        .task {
            await verificationGate.refresh(userId: authService.activeUserId)
            await loadGovernmentID()
        }
        .onReceive(pollTimer) { _ in
            guard identityService.governmentID?.verificationStatus == .pending else { return }
            Task {
                await verificationGate.refresh(userId: authService.activeUserId)
                await loadGovernmentID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await verificationGate.refresh(userId: authService.activeUserId)
                await loadGovernmentID()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        if identityService.isLoading && identityService.governmentID == nil {
            ProgressView()
                .padding(.top, 20)
        } else if let governmentID = identityService.governmentID {
            switch governmentID.verificationStatus {
            case .pending:
                pendingCard
            case .rejected:
                rejectedCard
            case .verified:
                verifiedCard
            }
        } else {
            startCard
        }
    }

    private var startCard: some View {
        VStack(spacing: 16) {
            Button(action: startVerification) {
                HStack {
                    if isStartingVerification {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "person.badge.shield.checkmark.fill")
                        Text("Verify Identity with Stripe")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isStartingVerification)

            Text("Stripe Identity securely compares your government-issued ID with a selfie photo. Your information is encrypted and protected.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var pendingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Verification Pending")
                        .font(.headline)
                        .foregroundColor(.orange)

                    Text("We're reviewing your ID with Stripe. This usually takes less than a minute. We'll unlock your account automatically when it's approved.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(10)

            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    private var rejectedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Verification Failed")
                        .font(.headline)
                        .foregroundColor(.red)

                    Text("Your identity verification wasn't successful. Please try again with a clearer photo of your ID.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(10)

            Button(action: startVerification) {
                HStack {
                    if isStartingVerification {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry Verification")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isStartingVerification)
        }
    }

    private var verifiedCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text("Identity Verified")
                    .font(.headline)
                    .foregroundColor(.green)

                Text("You're all set. Opening Buzz…")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
    }

    private func startVerification() {
        guard !isStartingVerification else { return }
        isStartingVerification = true

        authenticateWithBiometrics { authenticated in
            guard authenticated else {
                isStartingVerification = false
                return
            }
            Task { await launchStripeFlow() }
        }
    }

    private func authenticateWithBiometrics(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var policyError: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &policyError)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication

        let reason = "Please authenticate to start identity verification."
        context.evaluatePolicy(policy, localizedReason: reason) { success, authenticationError in
            DispatchQueue.main.async {
                if success {
                    completion(true)
                } else {
                    errorMessage = authenticationError?.localizedDescription ?? "Authentication failed"
                    showError = true
                    completion(false)
                }
            }
        }
    }

    private func launchStripeFlow() async {
        defer { isStartingVerification = false }

        guard let currentUser = authService.currentUser else {
            errorMessage = "Unable to start verification. Please try signing out and back in."
            showError = true
            return
        }

        do {
            let email = currentUser.email ?? authService.userProfile?.email
            let clientSecret = try await identityService.createVerificationSession(
                userId: currentUser.id,
                email: email
            )

            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                errorMessage = "Unable to present verification"
                showError = true
                return
            }

            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }

            let result = try await identityService.presentVerificationFlow(
                clientSecret: clientSecret,
                from: topController
            )

            try await identityService.handleVerificationResult(
                result,
                userId: currentUser.id,
                sessionId: extractSessionId(from: clientSecret)
            )

            await loadGovernmentID()
            await verificationGate.refresh(userId: authService.activeUserId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func extractSessionId(from clientSecret: String) -> String? {
        clientSecret.components(separatedBy: "_secret_").first
    }

    private func loadGovernmentID() async {
        guard let userId = authService.activeUserId else { return }
        try? await identityService.fetchGovernmentID(userId: userId)
    }

    private func signOut() {
        guard !isSigningOut else { return }
        isSigningOut = true
        Task {
            do {
                try await authService.signOut()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSigningOut = false
        }
    }
}
