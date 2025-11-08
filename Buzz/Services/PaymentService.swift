//
//  PaymentService.swift
//  Buzz
//
//  Created for Stripe Connect integration
//

import Foundation
import StripePaymentSheet
import Supabase
import UIKit
import Combine

@MainActor
class PaymentService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    
    // MARK: - Create Payment Intent
    
    /// Creates a PaymentIntent on the server with transfer_group for later transfers
    func createPaymentIntent(
        amount: Decimal,
        currency: String = "usd",
        customerId: UUID,
        transferGroup: String
    ) async throws -> PaymentIntentResponse {
        isLoading = true
        errorMessage = nil
        
        do {
            struct PaymentIntentRequest: Codable {
                let amount: Int
                let currency: String
                let customer_id: String
                let transfer_group: String
            }
            
            let request = PaymentIntentRequest(
                amount: Int(NSDecimalNumber(decimal: amount * 100).intValue),
                currency: currency,
                customer_id: customerId.uuidString,
                transfer_group: transferGroup
            )
            
            let response: PaymentIntentResponse = try await supabase.functions
                .invoke("create-payment-intent", options: FunctionInvokeOptions(
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
    
    // MARK: - Present Payment Sheet
    
    /// Presents the Stripe PaymentSheet for payment
    func presentPaymentSheet(
        paymentIntentClientSecret: String,
        customerId: String?,
        customerEphemeralKeySecret: String?
    ) async throws -> PaymentSheetResult {
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "Buzz"
        
        // Configure customer if provided
        if let customerId = customerId, let ephemeralKey = customerEphemeralKeySecret {
            configuration.customer = .init(id: customerId, ephemeralKeySecret: ephemeralKey)
        }
        
        let paymentSheet = PaymentSheet(
            paymentIntentClientSecret: paymentIntentClientSecret,
            configuration: configuration
        )
        
        // Present payment sheet
        return try await paymentSheet.present()
    }
    
    // MARK: - Create Transfer
    
    /// Creates a transfer to the pilot's connected account when booking is completed
    func createTransfer(
        bookingId: UUID,
        amount: Decimal,
        currency: String = "usd",
        chargeId: String
    ) async throws -> TransferResponse {
        isLoading = true
        errorMessage = nil
        
        do {
            struct TransferRequest: Codable {
                let booking_id: String
                let amount: Int
                let currency: String
                let charge_id: String
            }
            
            let request = TransferRequest(
                booking_id: bookingId.uuidString,
                amount: Int(NSDecimalNumber(decimal: amount * 100).intValue),
                currency: currency,
                charge_id: chargeId
            )
            
            let response: TransferResponse = try await supabase.functions
                .invoke("create-transfer", options: FunctionInvokeOptions(
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
}

// MARK: - Response Models

struct PaymentIntentResponse: Codable {
    let clientSecret: String
    let paymentIntentId: String
    let customerId: String?
    let ephemeralKeySecret: String?
    
    enum CodingKeys: String, CodingKey {
        case clientSecret = "client_secret"
        case paymentIntentId = "payment_intent_id"
        case customerId = "customer_id"
        case ephemeralKeySecret = "ephemeral_key_secret"
    }
}

struct TransferResponse: Codable {
    let transferId: String
    let amount: Int
    let currency: String
    
    enum CodingKeys: String, CodingKey {
        case transferId = "transfer_id"
        case amount
        case currency
    }
}

// MARK: - Payment Sheet Result

enum PaymentSheetResult {
    case completed
    case cancelled
    case failed(Error)
}

extension PaymentSheet {
    func present() async throws -> PaymentSheetResult {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    continuation.resume(throwing: PaymentError.noWindow)
                    return
                }
                
                // Find the topmost view controller
                var topController = rootViewController
                while let presented = topController.presentedViewController {
                    topController = presented
                }
                
                self.present(from: topController) { result in
                    switch result {
                    case .completed:
                        continuation.resume(returning: .completed)
                    case .canceled:
                        continuation.resume(returning: .cancelled)
                    case .failed(let error):
                        continuation.resume(returning: .failed(error))
                    }
                }
            }
        }
    }
}

enum PaymentError: Error {
    case noWindow
    case invalidConfiguration
}

