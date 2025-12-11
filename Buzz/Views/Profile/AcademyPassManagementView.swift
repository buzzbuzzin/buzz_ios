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
    @StateObject private var entitlementManager = EntitlementManager.shared
    @State private var showSubscriptionSheet = false
    @State private var isCheckingSubscription = true
    @Environment(\.dismiss) var dismiss
    
    /// Check if user has active subscription from any source
    private var hasActiveSubscription: Bool {
        entitlementManager.hasAcademyPass
    }
    
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
                
                // Loading state while checking subscription
                if isCheckingSubscription {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Checking subscription status...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                }
                
                // Subscription Status Card
                if !isCheckingSubscription && hasActiveSubscription {
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
                                
                                // Show subscription source
                                Text("via \(entitlementManager.subscriptionSourceDisplayName)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                // Show Apple subscription details if from Apple
                                if entitlementManager.subscriptionSource == .apple,
                                   let subscription = storeKitManager.getActiveSubscription() {
                                    Text(subscription.displayName)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    if let period = subscription.subscription?.subscriptionPeriod {
                                        Text("\(subscription.displayPrice) / \(period.localizedDescription)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                // Show Stripe subscription details if from Stripe
                                if entitlementManager.subscriptionSource == .stripe,
                                   let stripeSubscription = entitlementManager.stripeSubscription {
                                    if let endDate = stripeSubscription.currentPeriodEnd {
                                        Text("Renews: \(endDate.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Manage Subscription Button - different based on source
                        if entitlementManager.subscriptionSource == .apple {
                            Button(action: {
                                openAppleSubscriptionManagement()
                            }) {
                                HStack {
                                    Image(systemName: "gear")
                                    Text("Manage in App Store")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .foregroundColor(.primary)
                        } else if entitlementManager.subscriptionSource == .stripe {
                            Button(action: {
                                openStripeSubscriptionManagement()
                            }) {
                                HStack {
                                    Image(systemName: "globe")
                                    Text("Manage on Website")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                } else if !isCheckingSubscription {
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
                if !isCheckingSubscription && !hasActiveSubscription {
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
            // Load products
            if storeKitManager.products.isEmpty {
                await storeKitManager.loadProducts()
            }
            
            // Check ALL subscription sources (Apple + Stripe backend)
            isCheckingSubscription = true
            _ = await storeKitManager.checkAllSubscriptions(pilotId: pilotId)
            isCheckingSubscription = false
        }
    }
    
    private func openAppleSubscriptionManagement() {
        // Open iOS Settings to manage Apple subscription
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openStripeSubscriptionManagement() {
        // Open website to manage Stripe subscription
        if let url = URL(string: "https://academy.buzzbuzzin.com/account") {
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
    @ObservedObject private var entitlementManager = EntitlementManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    @State private var hasAgreedToPolicies = false
    @State private var showExistingSubscriptionAlert = false
    @State private var isCheckingSubscription = true
    
    private var isPurchaseDisabled: Bool {
        isLoading || !hasAgreedToPolicies || isCheckingSubscription
    }
    
    /// Check if user already has a Stripe subscription
    private var hasStripeSubscription: Bool {
        entitlementManager.hasAcademyPass && entitlementManager.subscriptionSource == .stripe
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Show warning if user already has Stripe subscription
                    if hasStripeSubscription {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            
                            Text("You Already Have a Subscription")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text("You have an active subscription through our website. Purchasing here would result in double billing.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                if let url = URL(string: "https://academy.buzzbuzzin.com/account") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("Manage on Website")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Loading state
                    if isCheckingSubscription {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Checking subscription status...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                    }
                    
                    // Products (only show if no existing Stripe subscription)
                    if !hasStripeSubscription && !isCheckingSubscription {
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
                            
                            HStack(alignment: .top, spacing: 12) {
                                Button {
                                    hasAgreedToPolicies.toggle()
                                } label: {
                                    Image(systemName: hasAgreedToPolicies ? "checkmark.square.fill" : "square")
                                        .foregroundColor(hasAgreedToPolicies ? .blue : .secondary)
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Agree to terms")
                                .accessibilityValue(hasAgreedToPolicies ? "Selected" : "Not selected")
                                
                                Text(.init("I agree to the [End User License Agreement](\(eulaURL.absoluteString)) and [Privacy Policy](\(privacyPolicyURL.absoluteString))"))
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer()
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
                                .background(isPurchaseDisabled ? Color.gray : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isPurchaseDisabled)
                        }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
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
            
            // Check ALL subscription sources (Apple + Stripe backend)
            isCheckingSubscription = true
            _ = await storeKitManager.checkAllSubscriptions(pilotId: pilotId)
            isCheckingSubscription = false
        }
    }
    
    private var eulaURL: URL {
        URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    }
    
    private var privacyPolicyURL: URL {
        URL(string: "https://buzzbuzzin.com/legal/")!
    }
    
    private func purchaseProduct(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        
        // Double-check for existing Stripe subscription before purchase
        if hasStripeSubscription {
            errorMessage = "You already have a subscription through our website."
            isLoading = false
            return
        }
        
        do {
            let transaction = try await storeKitManager.purchase(product)
            
            if transaction != nil {
                showSuccessAlert = true
                
                // Record in database with Apple as source
                await recordSubscriptionInDatabase(transaction: transaction!)
                
                // Update entitlement manager
                _ = await storeKitManager.checkAllSubscriptions(pilotId: pilotId)
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
                currentPeriodEnd: endDate,
                source: .apple  // Mark as Apple subscription
            )
            print("✅ Recorded Apple subscription in database")
        } catch {
            print("⚠️ Failed to record subscription: \(error)")
        }
    }
}

