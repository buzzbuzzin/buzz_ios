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
    
    /// Check if user has an active Academy Pass subscription
    func hasAcademyPassSubscription() -> Bool {
        return purchasedProductIDs.contains(where: { id in
            ProductIdentifiers.academyPassProductIDs.contains(id)
        })
    }
    
    /// Get the active subscription product
    func getActiveSubscription() -> Product? {
        return products.first { product in
            purchasedProductIDs.contains(product.id)
        }
    }
}

// MARK: - Entitlement Manager

/// Manages user entitlements (what they have access to)
class EntitlementManager: ObservableObject {
    static let shared = EntitlementManager()
    
    @Published var hasAcademyPass = false
    
    private init() {}
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

