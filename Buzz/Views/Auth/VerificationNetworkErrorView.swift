//
//  VerificationNetworkErrorView.swift
//  Buzz
//

import SwiftUI

struct VerificationNetworkErrorView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject var verificationGate: VerificationGate

    @State private var isRetrying = false
    @State private var isSigningOut = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "wifi.slash")
                    .font(.system(size: 72))
                    .foregroundColor(.orange)

                Text("No Internet Connection")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("We couldn't confirm your verification status. Buzz needs an internet connection to keep your account secure. Please check your connection and try again.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button(action: retry) {
                    HStack {
                        if isRetrying {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isRetrying)
                .padding(.horizontal, 40)

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
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func retry() {
        guard !isRetrying else { return }
        isRetrying = true
        Task {
            await verificationGate.retry(userId: authService.activeUserId)
            isRetrying = false
        }
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
