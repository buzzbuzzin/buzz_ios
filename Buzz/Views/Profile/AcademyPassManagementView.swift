//
//  AcademyPassManagementView.swift
//  Buzz
//
//  View for managing Buzz Academy Pass subscription
//  Shows subscription status, benefits, and management options
//

import SwiftUI
import StoreKit

struct AcademyPassManagementView: View {
    let pilotId: UUID
    @StateObject private var storeKitManager = StoreKitManager()
    @State private var showSubscriptionSheet = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header Section
                VStack(spacing: 16) {
                    Image(systemName: "graduationcap.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Buzz Academy Pass")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Unlock full access to all course materials")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top)
                
                // Subscription Status Card
                if storeKitManager.hasAcademyPassSubscription() {
                    // Active Subscription
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Active Subscription")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                if let subscription = storeKitManager.getActiveSubscription() {
                                    Text(subscription.displayName)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    if let period = subscription.subscription?.subscriptionPeriod {
                                        Text("\(subscription.displayPrice) / \(period.localizedDescription)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Manage Subscription Button
                        Button(action: {
                            openSubscriptionManagement()
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Manage Subscription")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                } else {
                    // No Active Subscription
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("No Active Subscription")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Subscribe to unlock all course content")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Subscribe Button
                        Button(action: {
                            showSubscriptionSheet = true
                        }) {
                            HStack {
                                Image(systemName: "cart.fill")
                                Text("Subscribe Now")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Benefits Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("What's Included")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        BenefitRow(
                            icon: "checkmark.circle.fill",
                            title: "Access to Units 5-20",
                            description: "Complete advanced course materials"
                        )
                        
                        BenefitRow(
                            icon: "checkmark.circle.fill",
                            title: "All Extension Courses",
                            description: "Specialized training modules"
                        )
                        
                        BenefitRow(
                            icon: "checkmark.circle.fill",
                            title: "Advanced Training",
                            description: "Professional-level content"
                        )
                        
                        BenefitRow(
                            icon: "checkmark.circle.fill",
                            title: "Monthly Updates",
                            description: "New content added regularly"
                        )
                        
                        BenefitRow(
                            icon: "checkmark.circle.fill",
                            title: "Cancel Anytime",
                            description: "No long-term commitment"
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Free Content Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Always Free")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
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
                    .padding(.horizontal)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Pricing Info (if not subscribed)
                if !storeKitManager.hasAcademyPassSubscription() {
                    VStack(spacing: 12) {
                        if let product = storeKitManager.products.first(where: { 
                            $0.id == ProductIdentifiers.academyPassMonthly 
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Monthly Subscription")
                                        .font(.headline)
                                    if let subscription = product.subscription {
                                        Text(subscription.subscriptionPeriod.localizedDescription)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Text(product.displayPrice)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            
                            Button(action: {
                                showSubscriptionSheet = true
                            }) {
                                Text("Get Academy Pass")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
        }
        .navigationTitle("Academy Pass")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSubscriptionSheet) {
            // Need to get the course for the subscription view
            // For now, we'll create a simplified version
            AcademyPassSubscriptionSheet(pilotId: pilotId)
        }
        .task {
            // Load products and update subscription status
            if storeKitManager.products.isEmpty {
                await storeKitManager.loadProducts()
            }
            await storeKitManager.updatePurchasedProducts()
        }
    }
    
    private func openSubscriptionManagement() {
        // Open iOS Settings to manage subscription
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Benefit Row

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .font(.system(size: 20))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Simplified Subscription Sheet

struct AcademyPassSubscriptionSheet: View {
    let pilotId: UUID
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeKitManager = StoreKitManager()
    @StateObject private var courseSubscriptionService = CourseSubscriptionService()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Products
                    ForEach(storeKitManager.products.filter { 
                        ProductIdentifiers.academyPassProductIDs.contains($0.id) 
                    }) { product in
                        VStack(alignment: .leading, spacing: 16) {
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
                                
                                Text(product.displayPrice)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(ProductIdentifiers.academyPassInfo.features, id: \.self) { feature in
                                    HStack(spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 16))
                                        Text(feature)
                                            .font(.subheadline)
                                    }
                                }
                            }
                            
                            Button(action: {
                                Task {
                                    await purchaseProduct(product)
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
                        .padding(.horizontal)
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.subheadline)
                            .padding()
                    }
                    
                    Button(action: {
                        Task {
                            await storeKitManager.restorePurchases()
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding()
                }
                .padding(.top)
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
        }
        .task {
            if storeKitManager.products.isEmpty {
                await storeKitManager.loadProducts()
            }
        }
    }
    
    private func purchaseProduct(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let transaction = try await storeKitManager.purchase(product)
            
            if transaction != nil {
                showSuccessAlert = true
                
                // Record in database
                await recordSubscriptionInDatabase(transaction: transaction!)
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }
    
    private func recordSubscriptionInDatabase(transaction: StoreKit.Transaction) async {
        do {
            let startDate = transaction.purchaseDate
            let endDate = transaction.expirationDate ?? Calendar.current.date(byAdding: .month, value: 1, to: startDate)!
            
            try await courseSubscriptionService.createSubscriptionRecord(
                pilotId: pilotId,
                stripeSubscriptionId: String(transaction.id),
                stripePriceId: transaction.productID,
                status: "active",
                currentPeriodStart: startDate,
                currentPeriodEnd: endDate
            )
        } catch {
            print("⚠️ Failed to record subscription: \(error)")
        }
    }
}

