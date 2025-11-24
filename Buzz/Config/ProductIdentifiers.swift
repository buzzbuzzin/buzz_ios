//
//  ProductIdentifiers.swift
//  Buzz
//
//  Product identifiers for StoreKit In-App Purchases
//  These IDs must match the product IDs created in App Store Connect
//

import Foundation

/// Product identifiers for all in-app purchases
struct ProductIdentifiers {
    
    // MARK: - Academy Pass Subscriptions
    
    // IMPORTANT CONFIGURATION NOTES:
    // ===============================
    // Apple Internal ID (from App Store Connect): 6755633766
    // Product ID in App Store Connect: prod_TQeKNRSes494yB
    //
    // This Product ID matches what's configured in App Store Connect.
    // It's the same as the Stripe product ID for consistency.
    
    /// Monthly subscription for Academy Pass (UAS Pilot Course)
    /// Price: $9.99/month
    /// Product ID: prod_TQeKNRSes494yB (from App Store Connect)
    static let academyPassMonthly = "prod_TQeKNRSes494yB"
    
    /// Annual subscription for Academy Pass (optional - can add later)
    /// Price: $99.99/year (saves 17%)
    /// Note: Update this with your actual annual product ID from App Store Connect
    static let academyPassAnnual = "prod_TQeKNRSes494yB_annual"
    
    // MARK: - Product ID Collections
    
    /// All Academy Pass product IDs
    static let academyPassProductIDs: Set<String> = [
        academyPassMonthly,
        academyPassAnnual
    ]
    
    /// All available product IDs in the app
    static let allProductIDs: Set<String> = academyPassProductIDs
}

// MARK: - Product Configuration

/// Configuration for each product (for display purposes)
extension ProductIdentifiers {
    
    struct ProductInfo {
        let id: String
        let name: String
        let description: String
        let features: [String]
    }
    
    static let academyPassInfo = ProductInfo(
        id: academyPassMonthly,
        name: "Academy Pass",
        description: "Get full access to all course units in the UAS Pilot Course",
        features: [
            "Access to Units 4-20",
            "All extension courses",
            "Advanced training modules",
            "Monthly updates and new content",
            "Cancel anytime"
        ]
    )
}