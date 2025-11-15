//
//  SubscriptionService.swift
//  Buzz
//
//  Created for managing customer subscriptions
//

import Foundation
import StripePaymentSheet
import Supabase
import UIKit
import Combine

@MainActor
class SubscriptionService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentSubscription: Subscription?
    @Published var availablePlans: [SubscriptionPlan] = []
    
    private let supabase = SupabaseClient.shared.client
    
    // MARK: - Fetch Current Subscription
    
    /// Fetches the current active subscription for a customer
    func fetchCurrentSubscription(customerId: UUID) async throws -> Subscription? {
        isLoading = true
        errorMessage = nil
        
        do {
            struct SubscriptionRequest: Codable {
                let customer_id: String
            }
            
            let request = SubscriptionRequest(
                customer_id: customerId.uuidString
            )
            
            let response: SubscriptionResponse = try await supabase.functions
                .invoke("get-subscription", options: FunctionInvokeOptions(
                    body: request
                ))
            
            isLoading = false
            currentSubscription = response.subscription
            return response.subscription
        } catch {
            isLoading = false
            
            // Ignore cancellation errors (NSURLErrorCancelled = -999)
            // These happen when views are dismissed or recreated
            if let nsError = error as NSError?, nsError.code == NSURLErrorCancelled {
                // Silently ignore cancellation - it's not a real error
                return nil
            }
            
            errorMessage = error.localizedDescription
            // Return nil if no subscription found (not an error)
            if let error = error as NSError?, error.domain.contains("not found") {
                return nil
            }
            throw error
        }
    }
    
    // MARK: - Fetch Available Plans
    
    /// Fetches available subscription plans
    /// - Parameter productId: Optional Stripe product ID. If nil, uses the default product
    func fetchAvailablePlans(productId: String? = nil) async -> [SubscriptionPlan] {
        isLoading = true
        errorMessage = nil
        
        do {
            struct PlansRequest: Codable {
                let product_id: String?
            }
            
            let request = PlansRequest(product_id: productId)
            
            if let productId = productId {
                print("📤 Sending product_id to edge function: \(productId)")
            } else {
                print("📤 No product_id provided, using default")
            }
            
            let response: PlansResponse = try await supabase.functions
                .invoke("get-subscription-plans", options: FunctionInvokeOptions(
                    body: request
                ))
            
            isLoading = false
            
            // Check if there's an error in the response (even if HTTP status is 200)
            if let error = response.error {
                errorMessage = error
                // Still return empty array instead of throwing to prevent retries
                availablePlans = []
                return []
            }
            
            availablePlans = response.plans
            return response.plans
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            
            // Ignore cancellation errors
            if let nsError = error as NSError?, nsError.code == NSURLErrorCancelled {
                return []
            }
            
            // For other errors, return empty array instead of throwing
            // This prevents the view from retrying and causing refresh loops
            availablePlans = []
            return []
        }
    }
    
    // MARK: - Create Subscription
    
    /// Creates a new subscription for a customer
    func createSubscription(
        customerId: UUID,
        priceId: String
    ) async throws -> SubscriptionCreationResponse {
        isLoading = true
        errorMessage = nil
        
        do {
            struct CreateSubscriptionRequest: Codable {
                let customer_id: String
                let price_id: String
            }
            
            let request = CreateSubscriptionRequest(
                customer_id: customerId.uuidString,
                price_id: priceId
            )
            
            let response: SubscriptionCreationResponse = try await supabase.functions
                .invoke("create-subscription", options: FunctionInvokeOptions(
                    body: request
                ))
            
            isLoading = false
            return response
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Present Subscription Payment Sheet
    
    /// Presents the Stripe PaymentSheet for subscription payment
    func presentSubscriptionPaymentSheet(
        clientSecret: String,
        customerId: String?,
        customerEphemeralKeySecret: String?
    ) async throws -> PaymentSheetResult {
        // Use PaymentService's presentPaymentSheet method
        // For subscriptions, the client secret is a PaymentIntent client secret
        let paymentService = PaymentService()
        return try await paymentService.presentPaymentSheet(
            paymentIntentClientSecret: clientSecret,
            customerId: customerId,
            customerEphemeralKeySecret: customerEphemeralKeySecret
        )
    }
    
    // MARK: - Cancel Subscription
    
    /// Cancels a subscription
    func cancelSubscription(subscriptionId: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            struct CancelSubscriptionRequest: Codable {
                let subscription_id: String
            }
            
            let request = CancelSubscriptionRequest(
                subscription_id: subscriptionId
            )
            
            _ = try await supabase.functions
                .invoke("cancel-subscription", options: FunctionInvokeOptions(
                    body: request
                ))
            
            isLoading = false
            currentSubscription = nil
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Pause Subscription
    
    /// Pauses a subscription
    func pauseSubscription(subscriptionId: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            struct PauseSubscriptionRequest: Codable {
                let subscription_id: String
            }
            
            let request = PauseSubscriptionRequest(
                subscription_id: subscriptionId
            )
            
            _ = try await supabase.functions
                .invoke("pause-subscription", options: FunctionInvokeOptions(
                    body: request
                ))
            
            isLoading = false
            // Refresh subscription status
            if let customerId = currentSubscription?.customerId {
                _ = try await fetchCurrentSubscription(customerId: customerId)
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

// MARK: - Response Models

struct SubscriptionResponse: Codable {
    let subscription: Subscription?
}

struct PlansResponse: Codable {
    let plans: [SubscriptionPlan]
    let error: String? // Optional error message
}

struct SubscriptionCreationResponse: Codable {
    let subscriptionId: String
    let clientSecret: String
    let customerId: String?
    let ephemeralKeySecret: String?
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case subscriptionId = "subscription_id"
        case clientSecret = "client_secret"
        case customerId = "customer_id"
        case ephemeralKeySecret = "ephemeral_key_secret"
        case status
    }
}

// MARK: - Subscription Models

struct Subscription: Codable, Identifiable {
    let id: String
    let customerId: UUID
    let status: SubscriptionStatus
    let currentPeriodStart: Date
    let currentPeriodEnd: Date
    let cancelAtPeriodEnd: Bool
    let plan: SubscriptionPlan?
    let stripeSubscriptionId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case customerId = "customer_id"
        case status
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case cancelAtPeriodEnd = "cancel_at_period_end"
        case plan
        case stripeSubscriptionId = "stripe_subscription_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        customerId = try container.decode(UUID.self, forKey: .customerId)
        status = try container.decode(SubscriptionStatus.self, forKey: .status)
        
        // Handle date decoding (Stripe returns Unix timestamps)
        let startTimestamp = try container.decode(Int.self, forKey: .currentPeriodStart)
        currentPeriodStart = Date(timeIntervalSince1970: TimeInterval(startTimestamp))
        
        let endTimestamp = try container.decode(Int.self, forKey: .currentPeriodEnd)
        currentPeriodEnd = Date(timeIntervalSince1970: TimeInterval(endTimestamp))
        
        cancelAtPeriodEnd = try container.decode(Bool.self, forKey: .cancelAtPeriodEnd)
        plan = try container.decodeIfPresent(SubscriptionPlan.self, forKey: .plan)
        stripeSubscriptionId = try container.decodeIfPresent(String.self, forKey: .stripeSubscriptionId)
    }
    
    var isActive: Bool {
        status == .active || status == .trialing
    }
}

enum SubscriptionStatus: String, Codable {
    case active
    case trialing
    case incomplete
    case incompleteExpired = "incomplete_expired"
    case pastDue = "past_due"
    case canceled
    case unpaid
    case paused
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .trialing: return "Trial"
        case .incomplete: return "Incomplete"
        case .incompleteExpired: return "Expired"
        case .pastDue: return "Past Due"
        case .canceled: return "Canceled"
        case .unpaid: return "Unpaid"
        case .paused: return "Paused"
        }
    }
}

struct SubscriptionPlan: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let priceId: String
    let amount: Decimal
    let currency: String
    let interval: String // "month" or "year"
    let features: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case priceId = "price_id"
        case amount
        case currency
        case interval
        case features
    }
    
    var displayPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount / 100)) ?? "$0"
    }
    
    var displayInterval: String {
        // If interval is empty, return empty string (no fallback)
        guard !interval.isEmpty else {
            return ""
        }
        
        switch interval.lowercased() {
        case "month": return "month"
        case "year": return "year"
        case "booking": return "booking"
        default: return interval
        }
    }
    
    var fullDisplayPrice: String {
        "\(displayPrice)/\(displayInterval)"
    }
}


