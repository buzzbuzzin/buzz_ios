//
//  ProfileService.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import Foundation
import Supabase
import Combine

@MainActor
class ProfileService: ObservableObject {
    private let supabase = SupabaseClient.shared.client
    
    func getProfile(userId: UUID) async throws -> UserProfile {
        let profile: UserProfile = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        
        return profile
    }
    
    func updateProfile(userId: UUID, firstName: String?, lastName: String?, callSign: String?, email: String?, phone: String?) async throws {
        var updates: [String: AnyJSON] = [:]
        
        if let firstName = firstName {
            updates["first_name"] = .string(firstName)
        }
        if let lastName = lastName {
            updates["last_name"] = .string(lastName)
        }
        if let callSign = callSign {
            updates["call_sign"] = .string(callSign)
        }
        if let email = email {
            updates["email"] = .string(email)
        }
        if let phone = phone {
            updates["phone"] = .string(phone)
        }
        
        try await supabase
            .from("profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()
    }
    
    func updateCommunicationPreference(userId: UUID, preference: CommunicationPreference) async throws {
        let updates: [String: AnyJSON] = [
            "communication_preference": .string(preference.rawValue)
        ]
        
        try await supabase
            .from("profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()
    }
    
    func checkCallSignAvailability(callSign: String) async throws -> Bool {
        do {
            let profiles: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("call_sign", value: callSign)
                .execute()
                .value
            
            return profiles.isEmpty
        } catch {
            throw error
        }
    }
}

