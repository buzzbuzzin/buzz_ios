//
//  StoreKitExtensions.swift
//  Buzz
//
//  Extensions for StoreKit types
//

import Foundation
import StoreKit

// MARK: - Product.SubscriptionPeriod Extension

extension Product.SubscriptionPeriod {
    /// Localized description of the subscription period
    var localizedDescription: String {
        switch unit {
        case .day:
            return value == 1 ? "Daily" : "\(value) Days"
        case .week:
            return value == 1 ? "Weekly" : "\(value) Weeks"
        case .month:
            return value == 1 ? "Monthly" : "\(value) Months"
        case .year:
            return value == 1 ? "Yearly" : "\(value) Years"
        @unknown default:
            return "Unknown"
        }
    }
    
    /// Short localized description (e.g., "month", "year")
    var shortDescription: String {
        switch unit {
        case .day:
            return value == 1 ? "day" : "days"
        case .week:
            return value == 1 ? "week" : "weeks"
        case .month:
            return value == 1 ? "month" : "months"
        case .year:
            return value == 1 ? "year" : "years"
        @unknown default:
            return ""
        }
    }
}

// MARK: - Transaction Extension

extension Transaction {
    /// Formatted purchase date
    var formattedPurchaseDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: purchaseDate)
    }
    
    /// Formatted expiration date (if available)
    var formattedExpirationDate: String? {
        guard let expirationDate = expirationDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: expirationDate)
    }
    
    /// Check if subscription is active
    var isSubscriptionActive: Bool {
        guard let expirationDate = expirationDate else {
            // No expiration date means it's not a subscription or it's lifetime
            return true
        }
        return expirationDate > Date()
    }
}

