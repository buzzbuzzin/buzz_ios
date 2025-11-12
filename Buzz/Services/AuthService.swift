//
//  AuthService.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import Foundation
import Supabase
import AuthenticationServices
import GoogleSignIn
import Combine

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var userProfile: UserProfile?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var shouldDelayNavigation = false // Flag to delay navigation for promotion flow
    
    private let supabase = SupabaseClient.shared.client
    
    init() {
        Task {
            await checkAuthStatus()
        }
    }
    
    // MARK: - Auth Status
    
    func checkAuthStatus() async {
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            await loadUserProfile()
            
            // Only mark as authenticated if we have both user and profile
            if currentUser != nil && userProfile != nil {
                isAuthenticated = true
            } else {
                isAuthenticated = false
            }
        } catch {
            isAuthenticated = false
            currentUser = nil
            userProfile = nil
        }
    }
    
    private func loadUserProfile() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            let profile: UserProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            userProfile = profile
        } catch {
            print("Error loading profile: \(error)")
        }
    }
    
    // MARK: - Email/Password Auth
    
    func signUpWithEmail(email: String, password: String, userType: UserType, firstName: String, lastName: String, callSign: String?, role: CustomerRole?, specialization: BookingSpecialization?) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Sign up with email (Supabase will send verification email if enabled in dashboard)
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            
            let userId = response.user.id
            
            // Create profile
            try await createProfile(userId: userId, userType: userType, firstName: firstName, lastName: lastName, callSign: callSign, email: email, role: role, specialization: specialization)
            
            // Supabase creates a session automatically after signup
            // Even if email is unconfirmed, user can still login
            currentUser = response.user
            
            // Wait for database to commit
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Load the profile we just created
            await loadUserProfile()
            
            // Mark as authenticated (even if email not yet verified)
            if userProfile != nil {
                isAuthenticated = true
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signInWithEmail(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Sign in (works even if email not verified)
            let response = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            
            currentUser = response.user
            
            // Load profile
            await loadUserProfile()
            
            // Mark as authenticated
            if userProfile != nil {
                isAuthenticated = true
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Phone Auth
    
    func signInWithPhone(phone: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.signInWithOTP(
                phone: phone
            )
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func verifyOTP(phone: String, token: String, userType: UserType?, callSign: String?) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await supabase.auth.verifyOTP(
                phone: phone,
                token: token,
                type: .sms
            )
            
            // Check if profile exists
            let userId = response.user.id
            let profileExists = await checkProfileExists(userId: userId)
            
            if !profileExists, let userType = userType {
                try await createProfile(userId: userId, userType: userType, callSign: callSign, phone: phone)
            }
            
            currentUser = response.user
            await checkAuthStatus()
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple(authorization: ASAuthorization, userType: UserType?, callSign: String?) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Apple ID Credential"])
        }
        
        guard let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get token"])
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: tokenString
                )
            )
            
            // Check if profile exists
            let userId = response.user.id
            let profileExists = await checkProfileExists(userId: userId)
            
            if !profileExists, let userType = userType {
                // Note: email and fullName are only provided on first authorization
                // For returning users, these will be nil
                let email = appleIDCredential.email
                let fullName = appleIDCredential.fullName
                try await createProfile(
                    userId: userId,
                    userType: userType,
                    firstName: fullName?.givenName,
                    lastName: fullName?.familyName,
                    callSign: callSign,
                    email: email
                )
            }
            
            currentUser = response.user
            await checkAuthStatus()
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle(userType: UserType?, callSign: String?) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = await windowScene.windows.first?.rootViewController else {
                throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller"])
            }
            
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get ID token"])
            }
            
            let response = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken
                )
            )
            
            // Check if profile exists
            let userId = response.user.id
            let profileExists = await checkProfileExists(userId: userId)
            
            if !profileExists, let userType = userType {
                let email = result.user.profile?.email
                try await createProfile(userId: userId, userType: userType, callSign: callSign, email: email)
            }
            
            currentUser = response.user
            await checkAuthStatus()
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        try await supabase.auth.signOut()
        currentUser = nil
        userProfile = nil
        isAuthenticated = false
    }
    
    // MARK: - Change Password
    
    func verifyCurrentPassword(password: String) async throws -> Bool {
        guard let email = currentUser?.email else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No email found"])
        }
        
        do {
            _ = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            return true
        } catch {
            return false
        }
    }
    
    func changePassword(newPassword: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.update(user: UserAttributes(password: newPassword))
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Delete Account
    
    func deleteAccount() async throws {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Delete profile from database
            try await supabase
                .from("profiles")
                .delete()
                .eq("id", value: userId.uuidString)
                .execute()
            
            // Delete user from auth (this will cascade delete related data if RLS policies are set up)
            // Note: Supabase doesn't have a direct API to delete auth users from client
            // You may need to implement this via a server function or admin API
            // For now, we'll sign out the user
            try await supabase.auth.signOut()
            
            currentUser = nil
            userProfile = nil
            isAuthenticated = false
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkProfileExists(userId: UUID) async -> Bool {
        do {
            let _: UserProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            return true
        } catch {
            return false
        }
    }
    
    private func createProfile(userId: UUID, userType: UserType, firstName: String? = nil, lastName: String? = nil, callSign: String?, email: String? = nil, phone: String? = nil, role: CustomerRole? = nil, specialization: BookingSpecialization? = nil) async throws {
        var profile: [String: AnyJSON] = [
            "id": .string(userId.uuidString),
            "user_type": .string(userType.rawValue),
            "created_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        
        if let firstName = firstName {
            profile["first_name"] = .string(firstName)
        }
        if let lastName = lastName {
            profile["last_name"] = .string(lastName)
        }
        if let callSign = callSign {
            profile["call_sign"] = .string(callSign)
        }
        if let email = email {
            profile["email"] = .string(email)
        }
        if let phone = phone {
            profile["phone"] = .string(phone)
        }
        if let role = role {
            profile["role"] = .string(role.rawValue)
        }
        if let specialization = specialization {
            profile["specialization"] = .string(specialization.rawValue)
        }
        
        try await supabase
            .from("profiles")
            .insert(profile)
            .execute()
        
        // If pilot, create initial stats
        if userType == .pilot {
            do {
                let stats: [String: AnyJSON] = [
                    "pilot_id": .string(userId.uuidString),
                    "total_flight_hours": .double(0.0),
                    "completed_bookings": .integer(0),
                    "tier": .integer(0)
                ]
                
                try await supabase
                    .from("pilot_stats")
                    .insert(stats)
                    .execute()
            } catch {
                // Log the error but don't fail signup - stats can be created later
                print("Warning: Failed to create pilot stats - will be created when viewing profile")
            }
        }
    }
}

