//
//  CourseSubscriptionView.swift
//  Buzz
//
//  Created for UAS Pilot Course subscription management
//

import SwiftUI

struct CourseSubscriptionView: View {
    let course: TrainingCourse
    let pilotId: UUID
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionService = SubscriptionService()
    @StateObject private var courseSubscriptionService = CourseSubscriptionService()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    @State private var availablePlans: [SubscriptionPlan] = []
    
    // UAS Pilot Course Product ID from Stripe
    private let productId = "prod_TQeKNRSes494yB"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("UAS Pilot Course")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Get full access to all course units")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Pricing Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Monthly Subscription")
                                    .font(.headline)
                                if let plan = availablePlans.first {
                                    Text(plan.fullDisplayPrice)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                } else {
                                    Text("$9.99/month")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            SubscriptionFeatureRow(icon: "checkmark.circle.fill", text: "Access to Units 4-20")
                            SubscriptionFeatureRow(icon: "checkmark.circle.fill", text: "All extension courses")
                            SubscriptionFeatureRow(icon: "checkmark.circle.fill", text: "Advanced training modules")
                            SubscriptionFeatureRow(icon: "checkmark.circle.fill", text: "Cancel anytime")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Free Units Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Free Units (No Subscription Required)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("• Unit 1 - Ground School")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("• Unit 2 - Health & Safety")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("• Unit 3 - Operations")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // Subscribe Button
                    Button(action: {
                        Task {
                            await subscribeToCourse()
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                if let plan = availablePlans.first {
                                    Text("Subscribe for \(plan.fullDisplayPrice)")
                                        .fontWeight(.semibold)
                                } else {
                                    Text("Subscribe for $9.99/month")
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isLoading ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || availablePlans.isEmpty)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Subscribe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Subscription Successful", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("You now have access to all course units!")
            }
        }
        .task {
            // Check if already subscribed
            do {
                _ = try await courseSubscriptionService.checkSubscriptionStatus(pilotId: pilotId)
            } catch {
                print("Error checking subscription: \(error)")
            }
            
            // Fetch available plans for this product
            availablePlans = await subscriptionService.fetchAvailablePlans(productId: productId)
        }
    }
    
    private func subscribeToCourse() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Use the fetched plans, or fetch if not already loaded
            var plans = availablePlans
            if plans.isEmpty {
                plans = await subscriptionService.fetchAvailablePlans(productId: productId)
                availablePlans = plans
            }
            
            guard let plan = plans.first else {
                errorMessage = "Subscription plan not available. Please contact support."
                isLoading = false
                return
            }
            
            // Create subscription
            let response = try await subscriptionService.createSubscription(
                customerId: pilotId,
                priceId: plan.priceId
            )
            
            // Present payment sheet
            let result = try await subscriptionService.presentSubscriptionPaymentSheet(
                clientSecret: response.clientSecret,
                customerId: response.customerId,
                customerEphemeralKeySecret: response.ephemeralKeySecret
            )
            
            switch result {
            case .completed:
                // Payment successful - create subscription record
                let currentDate = Date()
                let periodEnd = Calendar.current.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
                
                try await courseSubscriptionService.createSubscriptionRecord(
                    pilotId: pilotId,
                    stripeSubscriptionId: response.subscriptionId,
                    stripePriceId: plan.priceId,
                    status: "active",
                    currentPeriodStart: currentDate,
                    currentPeriodEnd: periodEnd
                )
                
                showSuccessAlert = true
                
            case .cancelled:
                errorMessage = "Payment was canceled"
                
            case .failed(let error):
                errorMessage = "Payment failed: \(error.localizedDescription)"
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Error: \(error.localizedDescription)"
        }
    }
}

struct SubscriptionFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .font(.system(size: 16))
            Text(text)
                .font(.subheadline)
        }
    }
}

