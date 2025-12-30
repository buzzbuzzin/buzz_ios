//
//  ReferralService.swift
//  Buzz
//
//  Created for the client referral/loyalty program
//

import Foundation
import Supabase
import Combine

class ReferralService: ObservableObject {
    @Published var isLoading = false
    @Published var referralCode: String?
    @Published var stats: ReferralStats?
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    
    // MARK: - Generate or Get Referral Code
    
    /// Generates a new referral code for the user or retrieves their existing one
    func getOrGenerateReferralCode(userId: UUID) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        do {
            struct GenerateRequest: Codable {
                let user_id: String
            }
            
            let request = GenerateRequest(user_id: userId.uuidString)
            
            let response: GenerateReferralCodeResponse = try await supabase.functions
                .invoke("generate-referral-code", options: FunctionInvokeOptions(
                    body: request
                ))
            
            isLoading = false
            referralCode = response.code
            return response.code
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Apply Referral Code
    
    /// Applies a referral code during signup, linking the new user to the referrer
    func applyReferralCode(refereeId: UUID, referralCode: String) async throws -> ApplyReferralCodeResponse {
        isLoading = true
        errorMessage = nil
        
        do {
            struct ApplyRequest: Codable {
                let referee_id: String
                let referral_code: String
            }
            
            let request = ApplyRequest(
                referee_id: refereeId.uuidString,
                referral_code: referralCode
            )
            
            let response: ApplyReferralCodeResponse = try await supabase.functions
                .invoke("apply-referral-code", options: FunctionInvokeOptions(
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
    
    // MARK: - Get Referral Stats
    
    /// Fetches the user's referral statistics including credits and referral history
    func getReferralStats(userId: UUID) async throws -> ReferralStats {
        isLoading = true
        errorMessage = nil
        
        do {
            struct StatsRequest: Codable {
                let user_id: String
            }
            
            let request = StatsRequest(user_id: userId.uuidString)
            
            let response: ReferralStats = try await supabase.functions
                .invoke("get-referral-stats", options: FunctionInvokeOptions(
                    body: request
                ))
            
            isLoading = false
            stats = response
            referralCode = response.referralCode
            return response
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Validate Referral Code
    
    /// Validates a referral code exists without applying it
    func validateReferralCode(_ code: String) async throws -> Bool {
        let normalizedCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !normalizedCode.isEmpty else {
            return false
        }
        
        do {
            let result = try await supabase
                .from("referral_codes")
                .select("code")
                .eq("code", value: normalizedCode)
                .single()
                .execute()
            
            return result.data.count > 2 // More than just "{}"
        } catch {
            // Code not found
            return false
        }
    }
    
    // MARK: - Get Available Credits
    
    /// Gets the user's available referral credits from their profile
    func getAvailableCredits(userId: UUID) async throws -> Decimal {
        struct ProfileCredits: Codable {
            let referralCredits: Decimal?
            
            enum CodingKeys: String, CodingKey {
                case referralCredits = "referral_credits"
            }
        }
        
        do {
            let result: ProfileCredits = try await supabase
                .from("profiles")
                .select("referral_credits")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            return result.referralCredits ?? 0
        } catch {
            print("Error fetching referral credits: \(error)")
            return 0
        }
    }
}

