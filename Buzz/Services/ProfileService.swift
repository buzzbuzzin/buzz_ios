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
    @Published var loadedProfile: UserProfile?

    private let supabase = SupabaseClient.shared.client
    private let userDefaults = UserDefaults.standard

    // MARK: - Persistent Cache

    private func cacheKey(for userId: UUID) -> String {
        "profileCache.\(userId.uuidString)"
    }

    func persistProfile(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        userDefaults.set(data, forKey: cacheKey(for: profile.id))
    }

    func restoreCachedProfile(for userId: UUID) -> UserProfile? {
        guard let data = userDefaults.data(forKey: cacheKey(for: userId)),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return nil
        }
        return profile
    }

    func invalidateCache(for userId: UUID) {
        userDefaults.removeObject(forKey: cacheKey(for: userId))
    }

    // MARK: - Get Profile (stale-while-revalidate)

    func getProfile(userId: UUID) async throws -> UserProfile {
        // Return cached immediately if available, then revalidate in background
        if let cached = restoreCachedProfile(for: userId) {
            Task { await revalidateProfile(userId: userId) }
            return cached
        }

        // No cache — fetch from network
        let profile: UserProfile = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        persistProfile(profile)
        return profile
    }

    private func revalidateProfile(userId: UUID) async {
        guard let fresh: UserProfile = try? await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value else { return }

        let cached = restoreCachedProfile(for: userId)
        persistProfile(fresh)
        if cached != fresh {
            loadedProfile = fresh
        }
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

        invalidateCache(for: userId)
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

        invalidateCache(for: userId)
    }

    func updateRegion(userId: UUID, regionString: String) async throws {
        let updates: [String: AnyJSON] = [
            "selected_region": .string(regionString)
        ]

        try await supabase
            .from("profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()

        invalidateCache(for: userId)
    }

    func updateRegionalPreferences(
        userId: UUID,
        regionString: String,
        preferredMeasurementSystem: MeasurementSystem?
    ) async throws {
        let updates: [String: AnyJSON] = [
            "selected_region": .string(regionString),
            "preferred_measurement_system": preferredMeasurementSystem.map { .string($0.rawValue) } ?? .null
        ]

        try await supabase
            .from("profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()

        invalidateCache(for: userId)
    }

    func updatePreferredMeasurementSystem(
        userId: UUID,
        preferredMeasurementSystem: MeasurementSystem?
    ) async throws {
        let updates: [String: AnyJSON] = [
            "preferred_measurement_system": preferredMeasurementSystem.map { .string($0.rawValue) } ?? .null
        ]

        try await supabase
            .from("profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()

        invalidateCache(for: userId)
    }
    
    func updateExMilitaryStatus(userId: UUID, isExMilitary: Bool) async throws {
        let updates: [String: AnyJSON] = [
            "is_ex_military": .bool(isExMilitary)
        ]
        
        try await supabase
            .from("profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()
    }
    
    func updateVeteranVerification(userId: UUID, serviceName: String, serviceCountry: String, militaryBranch: String, serviceNumber: String) async throws {
        let updates: [String: AnyJSON] = [
            "is_ex_military": .bool(true),
            "veteran_service_name": .string(serviceName),
            "veteran_service_country": .string(serviceCountry),
            "veteran_military_branch": .string(militaryBranch),
            "veteran_service_number": .string(serviceNumber)
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
                stripeAccountId: nil,
                isExMilitary: nil,
                isGovernmentEmployee: nil,
                hasFaaCertification: nil,
                isBuzzAffiliate: nil,
                veteranServiceName: nil,
                veteranServiceCountry: nil,
                veteranMilitaryBranch: nil,
                veteranServiceNumber: nil,
                lastLocationLat: nil,
                lastLocationLng: nil,
                lastLocationUpdate: nil,
                referralCredits: nil,
                referredBy: nil,
                isBeaconVolunteer: nil,
                selectedRegion: nil,
                isVerified: nil
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
                stripeAccountId: nil,
                isExMilitary: nil,
                isGovernmentEmployee: nil,
                hasFaaCertification: nil,
                isBuzzAffiliate: nil,
                veteranServiceName: nil,
                veteranServiceCountry: nil,
                veteranMilitaryBranch: nil,
                veteranServiceNumber: nil,
                lastLocationLat: nil,
                lastLocationLng: nil,
                lastLocationUpdate: nil,
                referralCredits: nil,
                referredBy: nil,
                isBeaconVolunteer: nil,
                selectedRegion: nil,
                isVerified: nil
            )
        }

        return nil
    }
}
