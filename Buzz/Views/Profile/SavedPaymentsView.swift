//
//  SavedPaymentsView.swift
//  Buzz
//
//  Created for displaying customer's saved payment methods
//

import SwiftUI
import Auth

struct SavedPaymentsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var paymentService = PaymentService()
    @State private var paymentMethods: [SavedPaymentMethod] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if paymentMethods.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No Saved Payment Methods")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("When you save a payment method during checkout, it will appear here for future use.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(paymentMethods) { method in
                    PaymentMethodRow(paymentMethod: method)
                }
            }
        }
        .navigationTitle("Saved Payments")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadPaymentMethods()
        }
        .task {
            await loadPaymentMethods()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Failed to load payment methods")
        }
    }
    
    private func loadPaymentMethods() async {
        guard let currentUser = authService.currentUser else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let methods = try await paymentService.fetchSavedPaymentMethods(customerId: currentUser.id)
            await MainActor.run {
                self.paymentMethods = methods
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                self.showError = true
            }
        }
    }
}

struct PaymentMethodRow: View {
    let paymentMethod: SavedPaymentMethod
    
    var body: some View {
        HStack(spacing: 16) {
            // Card icon
            Image(systemName: "creditcard.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            // Card details
            VStack(alignment: .leading, spacing: 4) {
                Text(paymentMethod.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if !paymentMethod.expirationDate.isEmpty {
                    Text("Expires \(paymentMethod.expirationDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationView {
        SavedPaymentsView()
            .environmentObject(AuthService())
    }
}

