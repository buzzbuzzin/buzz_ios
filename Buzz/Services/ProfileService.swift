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
    
    func updateProfile(userId: UUID, firstName: String?, lastName: String?, callSign: String?, email: String?, phone: String?, gender: Gender?) async throws {
        var updates: [String: AnyJSON] = [:]
        
        if let firstName = firstName {
            updates["first_name"] = .string(firstName)
        }
        if let lastName = lastName {
            updates["last_name"] = .string(lastName)
        }
        if let callSign = callSign {
            // Normalize callsign to uppercase before saving
            let normalizedCallSign = callSign.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
            updates["call_sign"] = .string(normalizedCallSign)
        }
        if let email = email {
            updates["email"] = .string(email)
        }
        if let phone = phone {
            updates["phone"] = .string(phone)
        }
        if let gender = gender {
            updates["gender"] = .string(gender.rawValue)
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
            // Normalize callsign to uppercase for case-insensitive comparison
            let normalizedCallSign = callSign.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Use case-insensitive comparison by checking for uppercase version
            let profiles: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("call_sign", value: normalizedCallSign)
                .execute()
                .value
            
            return profiles.isEmpty
        } catch {
            throw error
        }
    }
    
    // MARK: - Sample Customer Profiles for Demo
    // TODO: Remove this function when connecting to real backend
    
    func getSampleCustomerProfile(customerId: UUID) -> UserProfile? {
        // Only return sample data if demo mode is enabled
        guard DemoModeManager.shared.isDemoModeEnabled else {
            return nil
        }
        // Create a mapping of sample customer IDs to profiles with profile pictures
        // In production, this would fetch from the database
        let sampleCustomers: [String: (firstName: String, lastName: String, pictureUrl: String)] = [
            // These will be matched by hashing the UUID to get consistent names and pictures
            "customer1": ("Alex", "Martinez", "https://i.pravatar.cc/150?img=1"),
            "customer2": ("Jessica", "Thompson", "https://i.pravatar.cc/150?img=5"),
            "customer3": ("Michael", "Rodriguez", "https://i.pravatar.cc/150?img=12"),
            "customer4": ("Sarah", "Williams", "https://i.pravatar.cc/150?img=9"),
            "customer5": ("David", "Lee", "https://i.pravatar.cc/150?img=15"),
            "customer6": ("Emily", "Brown", "https://i.pravatar.cc/150?img=20"),
            "customer7": ("James", "Wilson", "https://i.pravatar.cc/150?img=33"),
            "customer8": ("Olivia", "Garcia", "https://i.pravatar.cc/150?img=47"),
            "customer9": ("Daniel", "Moore", "https://i.pravatar.cc/150?img=52"),
            "customer10": ("Sophia", "Taylor", "https://i.pravatar.cc/150?img=68")
        ]
        
        // Use a simple hash to get consistent customer names and pictures
        let hash = abs(customerId.hashValue) % sampleCustomers.count
        let customerKey = "customer\(hash + 1)"
        
        if let customerInfo = sampleCustomers[customerKey] {
            return             UserProfile(
                id: customerId,
                userType: .customer,
                firstName: customerInfo.firstName,
                lastName: customerInfo.lastName,
                callSign: nil,
                email: nil,
                phone: nil,
                gender: nil,
                profilePictureUrl: customerInfo.pictureUrl,
                communicationPreference: nil,
                role: nil,
                specialization: nil,
                createdAt: Date(),
                balance: nil,
                stripeAccountId: nil
            )
        }
        
        return nil
    }
    
    // MARK: - Sample Pilot Profiles for Demo
    // TODO: Remove this function when connecting to real backend
    
    func getSamplePilotProfile(pilotId: UUID) -> UserProfile? {
        // Only return sample data if demo mode is enabled
        guard DemoModeManager.shared.isDemoModeEnabled else {
            return nil
        }
        // Create a mapping of sample pilot IDs to profiles with profile pictures
        // In production, this would fetch from the database
        let samplePilots: [String: (firstName: String, lastName: String, callSign: String, pictureUrl: String)] = [
            // These will be matched by hashing the UUID to get consistent names and pictures
            "pilot1": ("Captain", "James", "SkyHawk", "https://i.pravatar.cc/150?img=11"),
            "pilot2": ("Major", "Sarah", "CloudRunner", "https://i.pravatar.cc/150?img=16"),
            "pilot3": ("Lt.", "Michael", "DroneMaster", "https://i.pravatar.cc/150?img=25"),
            "pilot4": ("Commander", "Emily", "AeroWave", "https://i.pravatar.cc/150?img=27"),
            "pilot5": ("Captain", "David", "SkyLine", "https://i.pravatar.cc/150?img=35"),
            "pilot6": ("Major", "Jessica", "WingShot", "https://i.pravatar.cc/150?img=41"),
            "pilot7": ("Lt.", "Robert", "FlightPath", "https://i.pravatar.cc/150?img=45"),
            "pilot8": ("Commander", "Amanda", "SkyView", "https://i.pravatar.cc/150?img=50"),
            "pilot9": ("Captain", "Chris", "AirDash", "https://i.pravatar.cc/150?img=55"),
            "pilot10": ("Major", "Laura", "CloudNine", "https://i.pravatar.cc/150?img=60")
        ]
        
        // Use a simple hash to get consistent pilot names and pictures
        let hash = abs(pilotId.hashValue) % samplePilots.count
        let pilotKey = "pilot\(hash + 1)"
        
        if let pilotInfo = samplePilots[pilotKey] {
            return UserProfile(
                id: pilotId,
                userType: .pilot,
                firstName: pilotInfo.firstName,
                lastName: pilotInfo.lastName,
                callSign: pilotInfo.callSign,
                email: nil,
                phone: nil,
                gender: nil,
                profilePictureUrl: pilotInfo.pictureUrl,
                communicationPreference: nil,
                role: nil,
                specialization: nil,
                createdAt: Date(),
                balance: nil,
                stripeAccountId: nil
            )
        }
        
        return nil
    }
}

