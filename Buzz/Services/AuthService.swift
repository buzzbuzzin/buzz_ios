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
    @Published var shouldShowPremiumIntro = false
    @Published private(set) var hasResolvedInitialSession = false
    
    var activeUserId: UUID? {
        currentUser?.id ?? uiTestUserId
    }
    
    private let supabase = SupabaseClient.shared.client
    private let userDefaults = UserDefaults.standard
    private var uiTestUserId: UUID?
    private let cachedUserProfileKey = "auth.cachedUserProfile"
    
    init() {
        if isUITestMode {
            bootstrapUITestUser()
        } else {
            Task {
                await checkAuthStatus(isInitialLoad: true)
            }
        }
    }
    
    // MARK: - Auth Status
    
    func checkAuthStatus(isInitialLoad: Bool = false) async {
        if isInitialLoad {
            hasResolvedInitialSession = false
        }

        defer {
            if isInitialLoad {
                hasResolvedInitialSession = true
            }
        }

        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            let didLoadProfile = await loadUserProfile()

            if !didLoadProfile {
                userProfile = restoreCachedUserProfile(for: session.user.id)
            }

            isAuthenticated = currentUser != nil && userProfile != nil
        } catch {
            isAuthenticated = false
            currentUser = nil
            userProfile = nil
            clearCachedUserProfile()
        }
    }

    private var isUITestMode: Bool {
        ProcessInfo.processInfo.arguments.contains("UI_TESTING") ||
        ProcessInfo.processInfo.environment["UITEST_MODE"] == "1"
    }
    
    private var uiTestRole: UserType {
        if let raw = ProcessInfo.processInfo.environment["UITEST_ROLE"],
           let role = UserType(rawValue: raw) {
            return role
        }
        return .customer
    }
    
    private func bootstrapUITestUser() {
        let userId = UUID(uuidString: ProcessInfo.processInfo.environment["UITEST_USER_ID"] ?? "") ?? UUID()
        self.uiTestUserId = userId
        let profile = UserProfile(
            id: userId,
            userType: uiTestRole,
            firstName: "UITest",
            lastName: uiTestRole == .pilot ? "Pilot" : "Customer",
            callSign: uiTestRole == .pilot ? "testpilot" : "testcustomer",
            email: "uitest@example.com",
            phone: nil,
            gender: nil,
            profilePictureUrl: nil,
            communicationPreference: nil,
            role: uiTestRole == .customer ? .individual : nil,
            specialization: .realEstate,
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
            isBeaconVolunteer: nil, selectedRegion: nil, isVerified: nil
        )
        self.userProfile = profile
        self.isAuthenticated = true
        self.shouldDelayNavigation = false
        self.shouldShowPremiumIntro = false
        self.hasResolvedInitialSession = true
    }
    
    @discardableResult
    private func loadUserProfile(maxAttempts: Int = 3) async -> Bool {
        guard let userId = currentUser?.id else { return false }

        for attempt in 1...maxAttempts {
            do {
                let profile: UserProfile = try await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value

                userProfile = profile
                cacheUserProfile(profile)

                // Sync email from auth to profile if they don't match
                // This handles the case where user confirmed email change and logged back in
                if let authEmail = currentUser?.email,
                   authEmail != profile.email {
                    let updates: [String: AnyJSON] = [
                        "email": .string(authEmail)
                    ]

                    try await supabase
                        .from("profiles")
                        .update(updates)
                        .eq("id", value: userId.uuidString)
                        .execute()

                    // Reload profile to get updated data
                    let updatedProfile: UserProfile = try await supabase
                        .from("profiles")
                        .select()
                        .eq("id", value: userId.uuidString)
                        .single()
                        .execute()
                        .value

                    userProfile = updatedProfile
                    cacheUserProfile(updatedProfile)
                }

                return true
            } catch {
                let isLastAttempt = attempt == maxAttempts
                print("Error loading profile (attempt \(attempt)/\(maxAttempts)): \(error)")

                if isLastAttempt {
                    return false
                }

                let retryDelay = UInt64(attempt) * 500_000_000
                try? await Task.sleep(nanoseconds: retryDelay)
            }
        }

        return false
    }
    
    // MARK: - Email/Password Auth
    
    func signUpWithEmail(email: String, password: String, userType: UserType, firstName: String, lastName: String, callSign: String?, role: CustomerRole?, specialization: BookingSpecialization?) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Sign up with email (Supabase will send verification email if enabled in dashboard)
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                redirectTo: URL(string: "https://buzzbuzzin.com/elementor-1147/")
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
                shouldDelayNavigation = true
                // Only show premium intro animation for customer accounts, not pilots
                if userProfile?.userType == .customer {
                    shouldShowPremiumIntro = true
                } else {
                    // For pilots, don't delay navigation since they won't see the animation
                    shouldDelayNavigation = false
                }
            } else {
                shouldDelayNavigation = false
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            shouldDelayNavigation = false
            shouldShowPremiumIntro = false
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
        await NotificationManager.shared.removeDeviceToken()
        try await supabase.auth.signOut()
        currentUser = nil
        userProfile = nil
        isAuthenticated = false
        clearCachedUserProfile()

        // Tear down per-user in-memory state held by shared singleton services so the
        // next user on the same device cannot briefly see the previous user's data
        // (exam appointments, booking config, Academy Pass / Stripe entitlements,
        // weather alerts) before their own fetch completes.
        ExamService.shared.resetForSignOut()
        BookingConfigService.shared.resetForSignOut()
        NWSAlertService.shared.resetForSignOut()
        EntitlementManager.shared.resetForSignOut()
    }
    
    // MARK: - Change Password
    
    func verifyCurrentPassword(password: String) async throws -> Bool {
        guard currentUser != nil else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }

        // Use a server-side RPC (SECURITY DEFINER) that compares against the stored
        // bcrypt hash in auth.users. This replaces the previous approach which called
        // supabase.auth.signIn just to validate the password — that call issued a new
        // session and rotated access tokens, leaving the app in an inconsistent auth
        // state if the subsequent changePassword call failed.
        do {
            let isValid: Bool = try await supabase
                .rpc("verify_user_password", params: ["p_password": password])
                .execute()
                .value
            return isValid
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
    
    func sendPasswordResetEmail() async throws {
        guard let email = currentUser?.email else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No email found for current user"])
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Send password reset email via Supabase
            try await supabase.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "https://buzzbuzzin.com/elementor-1147/")
            )
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Password Reset with OTP
    
    func sendPasswordResetOTP(email: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Send password reset email with OTP using resetPasswordForEmail
            try await supabase.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "https://buzzbuzzin.com/elementor-1147/")
            )
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func verifyPasswordResetOTP(email: String, token: String) async throws {
        isLoading = true
        errorMessage = nil

        // Password-reset OTP creates a real Supabase session on success. If another
        // user is already signed in on this device, verifyOTP would silently overwrite
        // their session and any subsequent writes would be attributed to the OTP user.
        // Tear down any existing session/local state first so only the reset-flow user
        // can reach authenticated state after the OTP is verified.
        if isAuthenticated || currentUser != nil {
            await NotificationManager.shared.removeDeviceToken()
            try? await supabase.auth.signOut()
            currentUser = nil
            userProfile = nil
            isAuthenticated = false
            clearCachedUserProfile()
        }

        // While the OTP flow is in progress we hold the app on the welcome/onboarding
        // route — we don't want the root destination to flip to `.main` just because
        // verifyOTP set up a session under the hood.
        shouldDelayNavigation = true

        do {
            let response = try await supabase.auth.verifyOTP(
                email: email,
                token: token,
                type: .email
            )

            currentUser = response.user
            await loadUserProfile()

            isLoading = false
        } catch {
            isLoading = false
            shouldDelayNavigation = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func resetPasswordWithOTP(newPassword: String) async throws {
        guard currentUser != nil else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user session found. Please verify OTP first."])
        }

        isLoading = true
        errorMessage = nil

        do {
            // Update password
            try await supabase.auth.update(user: UserAttributes(password: newPassword))

            // Ensure user remains authenticated and profile is loaded
            await checkAuthStatus()

            // Release the navigation hold placed by verifyPasswordResetOTP — the root
            // observer in BuzzApp will now re-prime and refresh VerificationGate in
            // response to `isAuthenticated` flipping true.
            shouldDelayNavigation = false

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
    
    // MARK: - Update Phone with OTP
    
    func sendPhoneUpdateOTP(phone: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Update user's phone number - Supabase will send an OTP via SMS
            try await supabase.auth.update(user: UserAttributes(phone: phone))
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func verifyPhoneUpdateOTP(phone: String, token: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Verify OTP for phone change
            let response = try await supabase.auth.verifyOTP(
                phone: phone,
                token: token,
                type: .phoneChange
            )
            
            // Update current user
            currentUser = response.user
            
            // Update the phone in the profile table
            if let userId = currentUser?.id {
                let updates: [String: AnyJSON] = [
                    "phone": .string(phone)
                ]
                
                try await supabase
                    .from("profiles")
                    .update(updates)
                    .eq("id", value: userId.uuidString)
                    .execute()
                
                // Reload user profile to reflect changes
                await loadUserProfile()
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Change Email with Token Verification
    
    func changeEmail(newEmail: String) async throws -> Date {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        guard let oldEmail = currentUser?.email else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No email found for current user"])
        }
        
        print("DEBUG AuthService: Starting email change for user \(userId) from \(oldEmail) to \(newEmail)")
        
        do {
            // Define request and response structures
            struct EmailChangeRequest: Codable {
                let old_email: String
                let new_email: String
            }
            
            struct EmailChangeResponse: Codable {
                let success: Bool?
                let message: String?
                let expires_at: String?
                let error: String?
            }
            
            let request = EmailChangeRequest(
                old_email: oldEmail,
                new_email: newEmail
            )
            
            // Call edge function to send verification token
            // Supabase automatically handles authorization
            let response: EmailChangeResponse = try await supabase.functions.invoke(
                "send-email-change-token",
                options: FunctionInvokeOptions(body: request)
            )
            
            // Check for errors in response
            if let error = response.error {
                throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
            }
            
            // Parse response to get expiration time
            if let expiresAtString = response.expires_at {
                let formatter = ISO8601DateFormatter()
                if let expiresAt = formatter.date(from: expiresAtString) {
                    print("DEBUG AuthService: Email change token sent successfully, expires at \(expiresAt)")
                    return expiresAt
                }
            }
            
            // Default expiration: 30 minutes from now
            let defaultExpiration = Date().addingTimeInterval(30 * 60)
            print("DEBUG AuthService: Email change token sent successfully (using default expiration)")
            return defaultExpiration
            
        } catch {
            print("DEBUG AuthService: Email change failed: \(error)")
            throw error
        }
    }
    
    func verifyEmailChangeToken(token: String, newEmail: String) async throws {
        guard currentUser != nil else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        print("DEBUG AuthService: Verifying email change token")
        
        do {
            // Define request and response structures
            struct VerifyTokenRequest: Codable {
                let token: String
                let new_email: String
            }
            
            struct VerifyTokenResponse: Codable {
                let success: Bool?
                let message: String?
                let new_email: String?
                let error: String?
            }
            
            let request = VerifyTokenRequest(
                token: token,
                new_email: newEmail
            )
            
            // Call edge function to verify token
            // Supabase automatically handles authorization
            let response: VerifyTokenResponse = try await supabase.functions.invoke(
                "verify-email-change-token",
                options: FunctionInvokeOptions(body: request)
            )
            
            // Check for errors in response
            if let error = response.error {
                throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
            }
            
            if response.success == true {
                print("DEBUG AuthService: Email verified and updated successfully")
                // Don't reload auth status yet - let the user log out first
                // The new email will be loaded when they log back in
                return
            }
            
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to verify email change"])
            
        } catch {
            print("DEBUG AuthService: Email verification failed: \(error)")
            throw error
        }
    }
    
    func resendEmailChangeToken(oldEmail: String, newEmail: String) async throws -> Date {
        guard currentUser != nil else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        print("DEBUG AuthService: Resending email change token")
        
        // Just call changeEmail again - it will generate a new token
        return try await changeEmail(newEmail: newEmail)
    }
    
    // MARK: - Delete Account
    
    func deleteAccount() async throws {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Clean up user data from related tables before profile deletion
            // Each delete is wrapped in try? so one failure doesn't block others

            // Tables with user_id column
            try? await supabase.from("hanger_talk_likes").delete().eq("user_id", value: userId.uuidString).execute()
            try? await supabase.from("hanger_talk_reposts").delete().eq("user_id", value: userId.uuidString).execute()
            try? await supabase.from("hanger_talk_bookmarks").delete().eq("user_id", value: userId.uuidString).execute()
            try? await supabase.from("device_tokens").delete().eq("user_id", value: userId.uuidString).execute()

            // Clean up mentions where user is mentioned
            try? await supabase.from("hanger_talk_mentions").delete().eq("mentioned_user_id", value: userId.uuidString).execute()

            // Clean up follows where user is follower or being followed
            try? await supabase.from("user_follows").delete().eq("follower_id", value: userId.uuidString).execute()
            try? await supabase.from("user_follows").delete().eq("following_id", value: userId.uuidString).execute()

            // Clean up notifications where user is recipient or actor
            try? await supabase.from("hanger_talk_notifications").delete().eq("recipient_id", value: userId.uuidString).execute()
            try? await supabase.from("hanger_talk_notifications").delete().eq("actor_id", value: userId.uuidString).execute()

            // Delete user's posts (this should cascade to related data)
            try? await supabase.from("hanger_talk_posts").delete().eq("author_id", value: userId.uuidString).execute()

            // Delete profile from database
            try await supabase
                .from("profiles")
                .delete()
                .eq("id", value: userId.uuidString)
                .execute()

            // TODO: Delete auth user via server function or admin API
            // Note: Supabase doesn't have a direct API to delete auth users from client
            await NotificationManager.shared.removeDeviceToken()
            try await supabase.auth.signOut()
            
            currentUser = nil
            userProfile = nil
            isAuthenticated = false
            isLoading = false
            clearCachedUserProfile()
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
            // Normalize callsign to uppercase before saving
            let normalizedCallSign = callSign.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
            profile["call_sign"] = .string(normalizedCallSign)
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

    private func cacheUserProfile(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(CachedUserProfile(userId: profile.id, profile: profile)) else {
            return
        }

        userDefaults.set(data, forKey: cachedUserProfileKey)
    }

    private func restoreCachedUserProfile(for userId: UUID) -> UserProfile? {
        guard let data = userDefaults.data(forKey: cachedUserProfileKey),
              let cachedProfile = try? JSONDecoder().decode(CachedUserProfile.self, from: data),
              cachedProfile.userId == userId else {
            return nil
        }

        return cachedProfile.profile
    }

    private func clearCachedUserProfile() {
        userDefaults.removeObject(forKey: cachedUserProfileKey)
    }
}

private struct CachedUserProfile: Codable {
    let userId: UUID
    let profile: UserProfile
}
