//
//  StripeConnectService.swift
//  Buzz
//
//  Created for Stripe Connect Express account onboarding
//

import Foundation
import Supabase
import UIKit
import Combine
import SafariServices

@MainActor
class StripeConnectService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var accountStatus: StripeAccountStatus?
    
    private let supabase = SupabaseClient.shared.client
    
    enum StripeAccountStatus: String, Codable {
        case notCreated = "not_created"
        case onboarding = "onboarding"
        case pending = "pending"
        case active = "active"
        case restricted = "restricted"
        
        var displayName: String {
            switch self {
            case .notCreated: return "Not Set Up"
            case .onboarding: return "Onboarding In Progress"
            case .pending: return "Pending Verification"
            case .active: return "Active"
            case .restricted: return "Restricted"
            }
        }
        
        var canReceivePayments: Bool {
            return self == .active
        }
    }
    
    // MARK: - Create Connected Account
    
    /// Creates an Express connected account for the pilot
    func createConnectedAccount(userId: UUID, email: String?, country: String = "US") async throws -> String {
        isLoading = true
        errorMessage = nil
        
        struct CreateAccountRequest: Codable {
            let user_id: String
            let email: String?
            let country: String
        }
        
        let request = CreateAccountRequest(
            user_id: userId.uuidString,
            email: email,
            country: country
        )
        
        struct CreateAccountResponse: Codable {
            let account_id: String
            let already_exists: Bool
            let warning: String?
        }
        
        struct ErrorResponse: Codable {
            let error: String
            let details: String?
            let type: String?
        }
        
        do {
            let response: CreateAccountResponse = try await supabase.functions
                .invoke("create-connected-account", options: FunctionInvokeOptions(
                    body: request
                ))
            
            isLoading = false
            return response.account_id
        } catch {
            isLoading = false
            
            // Try to extract error message from Supabase function error
            var errorMessageToShow = error.localizedDescription
            
            // The error shows "httpError(code: 500, data: 166 bytes)" - we need to extract the data
            // Check if error description contains data info
            let errorString = String(describing: error)
            print("Full error string: \(errorString)")
            
            // Try to get error data from NSError userInfo
            let nsError = error as NSError
            
            // Supabase HTTP errors might have data in different places
            // Try multiple approaches to extract the error response
            if let errorData = nsError.userInfo["data"] as? Data {
                print("Found error data: \(errorData.count) bytes")
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: errorData) {
                    errorMessageToShow = errorResponse.details ?? errorResponse.error
                    print("Parsed error response: \(errorResponse)")
                } else if let errorString = String(data: errorData, encoding: .utf8) {
                    print("Error data as string: \(errorString)")
                    // Try to parse as JSON manually
                    if let json = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
                       let errorMsg = json["error"] as? String {
                        errorMessageToShow = errorMsg
                    } else {
                        errorMessageToShow = errorString
                    }
                }
            }
            
            // Also check for response body in other possible locations
            if errorMessageToShow == error.localizedDescription {
                // Try reflection to access 'data' property if it exists
                let mirror = Mirror(reflecting: error)
                for child in mirror.children {
                    if child.label == "data", let data = child.value as? Data {
                        print("Found data via reflection: \(data.count) bytes")
                        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                            errorMessageToShow = errorResponse.details ?? errorResponse.error
                        } else if let errorString = String(data: data, encoding: .utf8) {
                            print("Error data as string: \(errorString)")
                            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let errorMsg = json["error"] as? String {
                                errorMessageToShow = errorMsg
                            }
                        }
                        break
                    }
                }
            }
            
            // Log the full error for debugging
            print("StripeConnect Error: \(error)")
            print("Error details: \(error.localizedDescription)")
            print("Error userInfo: \(nsError.userInfo)")
            print("Final error message: \(errorMessageToShow)")
            
            errorMessage = errorMessageToShow
            throw NSError(
                domain: "StripeConnectError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: errorMessageToShow]
            )
        }
    }
    
    // MARK: - Create Account Link
    
    /// Creates an account link for onboarding
    func createAccountLink(accountId: String, refreshUrl: String, returnUrl: String) async throws -> URL {
        isLoading = true
        errorMessage = nil
        
        do {
            struct AccountLinkRequest: Codable {
                let account_id: String
                let refresh_url: String
                let return_url: String
            }
            
            let request = AccountLinkRequest(
                account_id: accountId,
                refresh_url: refreshUrl,
                return_url: returnUrl
            )
            
            struct AccountLinkResponse: Codable {
                let url: String
            }
            
            let response: AccountLinkResponse = try await supabase.functions
                .invoke("create-account-link", options: FunctionInvokeOptions(
                    body: request
                ))
            
            guard let url = URL(string: response.url) else {
                throw NSError(
                    domain: "StripeConnectError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid account link URL"]
                )
            }
            
            isLoading = false
            return url
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Present Onboarding Flow
    
    /// Presents the Stripe onboarding flow in a Safari View Controller
    func presentOnboardingFlow(accountLinkUrl: URL, from viewController: UIViewController) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let safariVC = SFSafariViewController(url: accountLinkUrl)
                safariVC.modalPresentationStyle = .pageSheet
                
                // Store continuation for later use
                var observation: NSKeyValueObservation?
                observation = safariVC.observe(\.isBeingDismissed) { _, _ in
                    observation?.invalidate()
                    continuation.resume()
                }
                
                viewController.present(safariVC, animated: true)
            }
        }
    }
    
    // MARK: - Check Account Status
    
    /// Checks the status of a connected account
    func checkAccountStatus(accountId: String) async throws -> StripeAccountStatus {
        isLoading = true
        errorMessage = nil
        
        do {
            struct AccountStatusRequest: Codable {
                let account_id: String
            }
            
            struct AccountStatusResponse: Codable {
                let status: String
                let details_submitted: Bool
                let charges_enabled: Bool
                let payouts_enabled: Bool
            }
            
            let request = AccountStatusRequest(account_id: accountId)
            
            let response: AccountStatusResponse = try await supabase.functions
                .invoke("check-account-status", options: FunctionInvokeOptions(
                    body: request
                ))
            
            // Map Stripe status to our enum
            let status: StripeAccountStatus
            switch response.status {
            case "active":
                status = .active
            case "pending":
                status = .pending
            case "onboarding":
                status = .onboarding
            case "restricted":
                status = .restricted
            default:
                status = .onboarding
            }
            
            isLoading = false
            return status
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Get Account ID from Profile
    
    /// Gets the Stripe account ID from user profile
    func getAccountId(userId: UUID) async throws -> String? {
        do {
            struct ProfileResponse: Codable {
                let stripe_account_id: String?
            }
            
            let response: ProfileResponse = try await supabase
                .from("profiles")
                .select("stripe_account_id")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            return response.stripe_account_id
        } catch {
            throw error
        }
    }
    
    // MARK: - Complete Onboarding Flow
    
    /// Complete onboarding flow: create account if needed, then present onboarding
    func startOnboardingFlow(userId: UUID, email: String?, from viewController: UIViewController) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Check if account already exists
            var accountId = try await getAccountId(userId: userId)
            
            // Create account if it doesn't exist
            if accountId == nil {
                accountId = try await createConnectedAccount(userId: userId, email: email)
            }
            
            guard let accountId = accountId else {
                throw NSError(
                    domain: "StripeConnectError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to get or create account"]
                )
            }
            
            // Create account link
            // Use simple URLs - Safari View Controller will handle the redirect
            // When user completes onboarding, Stripe redirects to return_url and Safari closes
            let refreshUrl = "https://stripe.com/connect/onboarding/refresh"
            let returnUrl = "https://stripe.com/connect/onboarding/return"
            
            let accountLinkUrl = try await createAccountLink(
                accountId: accountId,
                refreshUrl: refreshUrl,
                returnUrl: returnUrl
            )
            
            // Present onboarding flow
            try await presentOnboardingFlow(accountLinkUrl: accountLinkUrl, from: viewController)
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

