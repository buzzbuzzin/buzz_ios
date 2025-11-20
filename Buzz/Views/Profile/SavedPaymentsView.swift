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
    @State private var isAddingPaymentMethod = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        List {
            if isLoading && !isAddingPaymentMethod {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if paymentMethods.isEmpty {
                VStack(spacing: 24) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No Saved Payment Methods")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Add a payment method to use for future purchases. Your payment information is securely stored and encrypted.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        Task {
                            await addPaymentMethod()
                        }
                    }) {
                        HStack {
                            if isAddingPaymentMethod {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text(isAddingPaymentMethod ? "Adding..." : "Add Payment Method")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isAddingPaymentMethod)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(paymentMethods) { method in
                    PaymentMethodRow(paymentMethod: method)
                }
                
                // Add Payment Method button when there are existing methods
                Button(action: {
                    Task {
                        await addPaymentMethod()
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Payment Method")
                        Spacer()
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding(.vertical, 8)
                }
                .disabled(isAddingPaymentMethod)
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
    
    private func addPaymentMethod() async {
        guard let currentUser = authService.currentUser else { return }
        
        isAddingPaymentMethod = true
        errorMessage = nil
        
        do {
            // Create SetupIntent
            let setupIntentResponse = try await paymentService.createSetupIntent(customerId: currentUser.id)
            
            // Present PaymentSheet with SetupIntent
            let result = try await paymentService.presentSetupIntentPaymentSheet(
                setupIntentClientSecret: setupIntentResponse.clientSecret,
                customerId: setupIntentResponse.customerId,
                customerEphemeralKeySecret: setupIntentResponse.ephemeralKeySecret
            )
            
            await MainActor.run {
                self.isAddingPaymentMethod = false
            }
            
            // Handle result
            switch result {
            case .completed:
                // Payment method saved successfully, refresh the list
                await loadPaymentMethods()
            case .cancelled:
                // User cancelled, no action needed
                break
            case .failed(let error):
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        } catch {
            await MainActor.run {
                self.isAddingPaymentMethod = false
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }
}

struct PaymentMethodRow: View {
    let paymentMethod: SavedPaymentMethod
    
    var body: some View {
        HStack(spacing: 16) {
            // Card brand icon
            Image(systemName: cardBrandIcon)
                .font(.title2)
                .foregroundColor(cardBrandColor)
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
    
    private var cardBrandIcon: String {
        guard let brand = paymentMethod.card?.brand.lowercased() else {
            return "creditcard.fill"
        }
        
        switch brand {
        case "visa":
            return "creditcard.fill"
        case "mastercard":
            return "creditcard.fill"
        case "amex", "american_express":
            return "creditcard.fill"
        case "discover":
            return "creditcard.fill"
        default:
            return "creditcard.fill"
        }
    }
    
    private var cardBrandColor: Color {
        guard let brand = paymentMethod.card?.brand.lowercased() else {
            return .blue
        }
        
        switch brand {
        case "visa":
            return .blue
        case "mastercard":
            return .orange
        case "amex", "american_express":
            return .green
        case "discover":
            return .orange
        default:
            return .blue
        }
    }
}

#Preview {
    NavigationView {
        SavedPaymentsView()
            .environmentObject(AuthService())
    }
}

