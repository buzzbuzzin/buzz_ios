//
//  CourseSubscriptionView.swift
//  Buzz
//
//  Created for UAS Pilot Course subscription management
//  Now using Apple StoreKit for in-app purchases
//

import SwiftUI
import StoreKit

struct CourseSubscriptionView: View {
    let course: TrainingCourse
    let pilotId: UUID
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeKitManager = StoreKitManager()
    @StateObject private var courseSubscriptionService = CourseSubscriptionService()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    @State private var showRestoreAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🎓 Academy Pass")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Get full access to all course units")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Check if already subscribed
                    if storeKitManager.hasAcademyPassSubscription() {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            
                            Text("You're Subscribed!")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("You have full access to all course units")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            if let subscription = storeKitManager.getActiveSubscription() {
                                Text(subscription.displayName)
                                    .font(.headline)
                                Text(subscription.displayPrice + " / " + subscription.subscription!.subscriptionPeriod.localizedDescription)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else {
                        // Subscription Products
                        ForEach(storeKitManager.products.filter { 
                            ProductIdentifiers.academyPassProductIDs.contains($0.id) 
                        }) { product in
                            SubscriptionProductCard(
                                product: product,
                                isLoading: $isLoading,
                                onPurchase: {
                                    await purchaseProduct(product)
                                }
                            )
                            .padding(.horizontal)
                        }
                        
                        // Loading state
                        if storeKitManager.isLoading && storeKitManager.products.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                Text("Loading subscription options...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding()
                        }
                    }
                    
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
                        Text("• Unit 4 - Drone Pilot (unlocking requires passing ground school test)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Error Message
                    if let errorMessage = errorMessage ?? storeKitManager.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.subheadline)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    // Restore Purchases Button
                    Button(action: {
                        Task {
                            await restorePurchases()
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            .navigationTitle("Subscribe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Subscription Successful", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("You now have full access to all course units!")
            }
            .alert("Purchases Restored", isPresented: $showRestoreAlert) {
                Button("OK") { }
            } message: {
                Text("Your previous purchases have been restored successfully.")
            }
        }
        .task {
            // Load products on appear
            if storeKitManager.products.isEmpty {
                await storeKitManager.loadProducts()
            }
            
            // Update purchased products
            await storeKitManager.updatePurchasedProducts()
        }
    }
    
    // MARK: - Purchase Functions
    
    private func purchaseProduct(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Attempt to purchase the product
            let transaction = try await storeKitManager.purchase(product)
            
            if transaction != nil {
                // Purchase successful
                showSuccessAlert = true
                
                // Record subscription in database
                await recordSubscriptionInDatabase(transaction: transaction!)
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("❌ Purchase error: \(error)")
        }
    }
    
    private func restorePurchases() async {
        await storeKitManager.restorePurchases()
        
        if storeKitManager.hasActiveSubscription {
            showRestoreAlert = true
        }
    }
    
    private func recordSubscriptionInDatabase(transaction: StoreKit.Transaction) async {
        do {
            // Calculate subscription period
            let startDate = transaction.purchaseDate
            let endDate = transaction.expirationDate ?? Calendar.current.date(byAdding: .month, value: 1, to: startDate)!
            
            // Create subscription record in database
            try await courseSubscriptionService.createSubscriptionRecord(
                pilotId: pilotId,
                stripeSubscriptionId: String(transaction.id),
                stripePriceId: transaction.productID,
                status: "active",
                currentPeriodStart: startDate,
                currentPeriodEnd: endDate
            )
            
            print("✅ Recorded subscription in database")
        } catch {
            print("⚠️ Failed to record subscription in database: \(error)")
            // Don't show error to user as the purchase was successful
        }
    }
}

// MARK: - Subscription Product Card

struct SubscriptionProductCard: View {
    let product: Product
    @Binding var isLoading: Bool
    let onPurchase: () async -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Product Name and Price
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                    
                    if let subscription = product.subscription {
                        Text(subscription.subscriptionPeriod.localizedDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            
            Divider()
            
            // Features
            VStack(alignment: .leading, spacing: 12) {
                ForEach(ProductIdentifiers.academyPassInfo.features, id: \.self) { feature in
                    SubscriptionFeatureRow(icon: "checkmark.circle.fill", text: feature)
                }
            }
            
            // Purchase Button
            Button(action: {
                Task {
                    await onPurchase()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Subscribe Now")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isLoading ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isLoading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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

