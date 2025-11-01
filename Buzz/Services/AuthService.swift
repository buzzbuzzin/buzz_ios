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
            isAuthenticated = true
            await loadUserProfile()
        } catch {
            isAuthenticated = false
            currentUser = nil
            userProfile = nil
        }
    }
    
    private func loadUserProfile() async {
        guard let userId = currentUser?.id else { 
            print("🔴 No current user ID")
            return 
        }
        
        print("🔵 Loading profile for userId: \(userId)")
        
        do {
            let profile: UserProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            print("🔵 Profile loaded: userType=\(profile.userType.rawValue), callSign=\(profile.callSign ?? "none")")
            userProfile = profile
        } catch {
            print("🔴 Error loading profile: \(error)")
        }
    }
    
    // MARK: - Email/Password Auth
    
    func signUpWithEmail(email: String, password: String, userType: UserType, callSign: String?) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔵 Starting signup for userType: \(userType.rawValue)")
            
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            
            let userId = response.user.id
            print("🔵 User created with ID: \(userId)")
            
            // Create profile
            try await createProfile(userId: userId, userType: userType, callSign: callSign, email: email)
            print("🔵 Profile created successfully")
            
            currentUser = response.user
            
            // Wait a moment for database to commit
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await checkAuthStatus()
            print("🔵 Final userProfile type: \(String(describing: userProfile?.userType))")
            
            isLoading = false
        } catch {
            print("🔴 Signup error: \(error)")
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signInWithEmail(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            
            currentUser = response.user
            await checkAuthStatus()
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
                let email = appleIDCredential.email
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
    
    private func createProfile(userId: UUID, userType: UserType, callSign: String?, email: String? = nil, phone: String? = nil) async throws {
        print("🔵 Creating profile for userId: \(userId), userType: \(userType.rawValue), callSign: \(callSign ?? "none")")
        
        var profile: [String: AnyJSON] = [
            "id": .string(userId.uuidString),
            "user_type": .string(userType.rawValue),
            "created_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        
        if let callSign = callSign {
            profile["call_sign"] = .string(callSign)
        }
        if let email = email {
            profile["email"] = .string(email)
        }
        if let phone = phone {
            profile["phone"] = .string(phone)
        }
        
        print("🔵 Profile data to insert: \(profile)")
        
        do {
            let response = try await supabase
                .from("profiles")
                .insert(profile)
                .execute()
            
            print("🔵 Profile insert response: \(response)")
            print("🔵 Profile inserted successfully")
        } catch let error as NSError {
            print("🔴 Profile insert error: \(error)")
            print("🔴 Error domain: \(error.domain)")
            print("🔴 Error code: \(error.code)")
            print("🔴 Error userInfo: \(error.userInfo)")
            throw error
        }
        
        // If pilot, create initial stats
        if userType == .pilot {
            print("🔵 Creating pilot stats...")
            do {
                let stats: [String: AnyJSON] = [
                    "pilot_id": .string(userId.uuidString),
                    "total_flight_hours": .double(0.0),
                    "completed_bookings": .integer(0),
                    "tier": .integer(0)
                ]
                
                print("🔵 Pilot stats data to insert: \(stats)")
                
                let response = try await supabase
                    .from("pilot_stats")
                    .insert(stats)
                    .execute()
                
                print("🔵 Pilot stats insert response: \(response)")
                print("🔵 Pilot stats created successfully")
            } catch let error as NSError {
                // Log the error but don't fail signup - stats can be created later
                print("🔴 Pilot stats insert error: \(error)")
                print("🔴 Error domain: \(error.domain)")
                print("🔴 Error code: \(error.code)")
                print("🔴 Error userInfo: \(error.userInfo)")
            }
        }
    }
}

