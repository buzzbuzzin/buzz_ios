//
//  StoreKitManager.swift
//  Buzz
//
//  Created for Apple StoreKit In-App Purchase management
//  Handles subscription purchases, transaction validation, and entitlements
//

import Foundation
import StoreKit
import SwiftUI
import Combine
import Supabase
import PostgREST

/// Main StoreKit manager for handling in-app purchases
@MainActor
class StoreKitManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasActiveSubscription = false
    
    // MARK: - Private Properties
    
    private var updateListenerTask: Task<Void, Error>?
    private var entitlementManager = EntitlementManager.shared
    
    // MARK: - Initialization
    
    init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    
    /// Load products from App Store Connect
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Request products from the App Store
            let products = try await Product.products(for: ProductIdentifiers.allProductIDs)
            
            // Sort products by price (lowest first)
            self.products = products.sorted { $0.price < $1.price }
            
            print("✅ Loaded \(products.count) products from App Store")
            products.forEach { product in
                print("  - \(product.displayName): \(product.displayPrice)")
            }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            isLoading = false
            print("❌ Error loading products: \(error)")
        }
    }
    
    // MARK: - Purchase Flow
    
    /// Purchase a product
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        errorMessage = nil
        
        do {
            // Start the purchase
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Verify the transaction
                let transaction = try checkVerified(verification)
                
                // Update purchased products
                await updatePurchasedProducts()
                
                // Finish the transaction
                await transaction.finish()
                
                isLoading = false
                print("✅ Successfully purchased: \(product.displayName)")
                
                return transaction
                
            case .userCancelled:
                isLoading = false
                errorMessage = "Purchase was cancelled"
                print("ℹ️ User cancelled purchase")
                return nil
                
            case .pending:
                isLoading = false
                errorMessage = "Purchase is pending approval"
                print("⏳ Purchase is pending")
                return nil
                
            @unknown default:
                isLoading = false
                errorMessage = "Unknown purchase result"
                return nil
            }
        } catch {
            isLoading = false
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("❌ Purchase error: \(error)")
            throw error
        }
    }
    
    // MARK: - Transaction Verification
    
    /// Verify a transaction is valid and signed by the App Store
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            // The transaction is not verified, reject it
            throw StoreError.verificationFailed
            
        case .verified(let safe):
            // The transaction is verified
            return safe
        }
    }
    
    // MARK: - Update Purchased Products
    
    /// Update the list of purchased products
    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        
        // Iterate through all the user's purchased products
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Check if the subscription is still active
                if let expirationDate = transaction.expirationDate,
                   expirationDate < Date() {
                    // Subscription has expired
                    continue
                }
                
                purchasedIDs.insert(transaction.productID)
            } catch {
                print("❌ Transaction verification failed: \(error)")
            }
        }
        
        self.purchasedProductIDs = purchasedIDs
        self.hasActiveSubscription = !purchasedIDs.isEmpty
        
        // Update entitlement manager
        entitlementManager.hasAcademyPass = !purchasedIDs.isEmpty
        
        print("📱 Updated purchased products: \(purchasedIDs)")
    }
    
    // MARK: - Transaction Listener
    
    /// Listen for transaction updates
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { @MainActor in
            // Iterate through any transactions that don't come from a direct call to `purchase()`
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    
                    // Update purchased products
                    await self.updatePurchasedProducts()
                    
                    // Always finish a transaction
                    await transaction.finish()
                } catch {
                    print("❌ Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Restore Purchases
    
    /// Restore previously purchased products
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Sync with App Store
            try await AppStore.sync()
            
            // Update purchased products
            await updatePurchasedProducts()
            
            isLoading = false
            
            if hasActiveSubscription {
                print("✅ Purchases restored successfully")
            } else {
                errorMessage = "No previous purchases found"
                print("ℹ️ No purchases to restore")
            }
        } catch {
            isLoading = false
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            print("❌ Restore error: \(error)")
        }
    }
    
    // MARK: - Subscription Status
    
    /// Check if user has an active Academy Pass subscription (Apple StoreKit only)
    /// For a complete check including Stripe, use checkAllSubscriptions(pilotId:)
    func hasAcademyPassSubscription() -> Bool {
        return purchasedProductIDs.contains(where: { id in
            ProductIdentifiers.academyPassProductIDs.contains(id)
        })
    }
    
    /// Check all subscription sources (Apple + Stripe backend)
    /// This is the recommended method to use in views
    func checkAllSubscriptions(pilotId: UUID) async -> Bool {
        // First update Apple purchases
        await updatePurchasedProducts()
        
        // Then check all sources via EntitlementManager
        return await entitlementManager.checkAllSubscriptionSources(
            pilotId: pilotId,
            appleProductIDs: ProductIdentifiers.academyPassProductIDs
        )
    }
    
    /// Get the active subscription product (Apple only)
    func getActiveSubscription() -> Product? {
        return products.first { product in
            purchasedProductIDs.contains(product.id)
        }
    }
    
    /// Check if user has subscription from a different source
    /// Use before purchase to prevent double billing
    func hasSubscriptionFromOtherSource(_ source: SubscriptionSource) -> Bool {
        return entitlementManager.hasSubscriptionFromOtherSource(currentSource: source)
    }
}

// MARK: - Entitlement Manager

/// Subscription source - where the subscription was purchased
enum SubscriptionSource: String, Codable {
    case apple = "apple"
    case stripe = "stripe"
    case none = "none"
}

/// Manages user entitlements (what they have access to)
/// Checks both Apple StoreKit and backend database for subscriptions
@MainActor
class EntitlementManager: ObservableObject {
    static let shared = EntitlementManager()
    
    @Published var hasAcademyPass = false
    @Published var subscriptionSource: SubscriptionSource = .none
    @Published var isCheckingSubscription = false
    @Published var stripeSubscription: CourseSubscription?
    
    private let supabase = SupabaseClient.shared.client
    
    private init() {}
    
    // MARK: - Unified Subscription Check
    
    /// Checks both Apple StoreKit and backend database for active subscriptions
    /// Returns true if user has an active subscription from ANY source
    func checkAllSubscriptionSources(pilotId: UUID, appleProductIDs: Set<String>) async -> Bool {
        isCheckingSubscription = true
        
        // 1. Check Apple StoreKit entitlements first (local, faster)
        var hasAppleSubscription = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if appleProductIDs.contains(transaction.productID) {
                    // Check if not expired
                    if let expirationDate = transaction.expirationDate, expirationDate > Date() {
                        hasAppleSubscription = true
                        break
                    } else if transaction.expirationDate == nil {
                        // Lifetime purchase (no expiration)
                        hasAppleSubscription = true
                        break
                    }
                }
            }
        }
        
        if hasAppleSubscription {
            hasAcademyPass = true
            subscriptionSource = .apple
            stripeSubscription = nil
            isCheckingSubscription = false
            print("✅ Found active Apple subscription")
            return true
        }
        
        // 2. Check backend database for Stripe subscription
        do {
            let response: [CourseSubscription] = try await supabase
                .from("course_subscriptions")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("course_id", value: CourseSubscriptionService.uasPilotCourseId.uuidString)
                .eq("status", value: "active")
                .execute()
                .value
            
            if let subscription = response.first {
                // Verify the subscription period is still valid
                if let endDate = subscription.currentPeriodEnd, endDate > Date() {
                    hasAcademyPass = true
                    subscriptionSource = .stripe
                    stripeSubscription = subscription
                    isCheckingSubscription = false
                    print("✅ Found active Stripe subscription from backend")
                    return true
                }
            }
        } catch {
            print("⚠️ Failed to check backend subscription: \(error)")
        }
        
        // No active subscription found from any source
        hasAcademyPass = false
        subscriptionSource = .none
        stripeSubscription = nil
        isCheckingSubscription = false
        print("ℹ️ No active subscription found from any source")
        return false
    }
    
    /// Check if user already has a subscription from another source
    /// Use this before allowing a new purchase to prevent double billing
    func hasSubscriptionFromOtherSource(currentSource: SubscriptionSource) -> Bool {
        guard hasAcademyPass else { return false }
        return subscriptionSource != currentSource && subscriptionSource != .none
    }
    
    /// Get a display string for the subscription source
    var subscriptionSourceDisplayName: String {
        switch subscriptionSource {
        case .apple:
            return "App Store"
        case .stripe:
            return "Buzz Academy Website"
        case .none:
            return "None"
        }
    }
}

// MARK: - Store Error

enum StoreError: LocalizedError {
    case verificationFailed
    case purchaseFailed
    case productNotFound
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Transaction verification failed"
        case .purchaseFailed:
            return "Purchase failed"
        case .productNotFound:
            return "Product not found"
        }
    }
}

