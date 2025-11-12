//
//  AuthenticationView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

struct AuthenticationView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showSignUp = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                    
                    Text("Welcome aboard")
                        .font(.system(size: 28, weight: .semibold))
                    
                    Text("or back")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 10)
                .padding(.bottom, 10)
                
                // Auth Methods
                TabView(selection: $selectedTab) {
                    EmailSignInView()
                        .tag(0)
                    
                    PhoneSignInView()
                        .tag(1)
                    
                    SocialSignInView()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 400)
                
                // Sign Up Link
                HStack {
                    Text("Don't have an account?")
                        .foregroundColor(.secondary)
                    Button("Sign up") {
                        showSignUp = true
                    }
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.top, 30)
                
                Spacer(minLength: 0)
                    .frame(maxHeight: 20)
            }
            .frame(maxHeight: .infinity)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
            .onChange(of: authService.isAuthenticated) { _, isAuth in
                // Don't dismiss signup sheet immediately - let SignUpView handle promotion flow
                // The SignUpView will dismiss itself after showing promotion if needed
            }
        }
    }
}

// MARK: - Email Sign In View

struct EmailSignInView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSigningIn = false
    @State private var showUserTypeSelection = false
    @State private var selectedAuthMethod: SocialAuthMethod?
    @State private var selectedUserType: UserType = .pilot
    @State private var callSign = ""
    @State private var appleAuthorization: ASAuthorization?
    
    enum SocialAuthMethod {
        case apple, google
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            CustomButton(
                title: "Sign In",
                action: signIn,
                isLoading: authService.isLoading || isSigningIn,
                isDisabled: !isFormValid
            )
            .padding(.horizontal)
            
            if isSigningIn {
                Text("Signing in...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Divider - Temporarily commented out
            /*
            HStack {
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 1)
                Text("or")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 1)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            */
            
            // Social Sign In Options - Temporarily commented out
            /*
            VStack(spacing: 12) {
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .frame(height: 50)
                .cornerRadius(10)
                
                GoogleSignInButton(action: handleGoogleSignInButton)
                .frame(height: 50)
            }
            .padding(.horizontal)
            */
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showUserTypeSelection) {
            UserTypeSelectionSheet(
                userType: $selectedUserType,
                callSign: $callSign,
                onComplete: handleSocialSignIn
            )
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    private func signIn() {
        isSigningIn = true
        Task {
            do {
                try await authService.signInWithEmail(email: email, password: password)
                // Success - AuthService will handle navigation
                isSigningIn = false
            } catch {
                isSigningIn = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            selectedAuthMethod = .apple
            appleAuthorization = authorization
            showUserTypeSelection = true
        case .failure(let error):
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    // User canceled, don't show error
                    return
                case .failed:
                    errorMessage = "Apple Sign In failed. Please try again."
                case .invalidResponse:
                    errorMessage = "Invalid response from Apple. Please try again."
                case .notHandled:
                    errorMessage = "Apple Sign In is not available. Please check your device settings."
                case .unknown:
                    errorMessage = "Apple Sign In is not properly configured. Please ensure:\n1. Sign in with Apple capability is enabled in Xcode\n2. You're signed in with an Apple ID on this device\n3. Try using email sign-in instead"
                @unknown default:
                    errorMessage = "Apple Sign In error: \(authError.localizedDescription)"
                }
            } else {
                errorMessage = error.localizedDescription
            }
            showError = true
        }
    }
    
    private func handleGoogleSignInButton() {
        // Show user type selection first, then sign in
        // This matches our app's flow where we need user type before creating profile
        selectedAuthMethod = .google
        showUserTypeSelection = true
    }
    
    private func handleSocialSignIn() {
        Task {
            do {
                if selectedAuthMethod == .apple, let authorization = appleAuthorization {
                    try await authService.signInWithApple(
                        authorization: authorization,
                        userType: selectedUserType,
                        callSign: selectedUserType == .pilot ? callSign : nil
                    )
                } else if selectedAuthMethod == .google {
                    // Complete Google sign-in with user type
                    try await authService.signInWithGoogle(
                        userType: selectedUserType,
                        callSign: selectedUserType == .pilot ? callSign : nil
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Phone Sign In View

struct PhoneSignInView: View {
    @EnvironmentObject var authService: AuthService
    @State private var phoneNumber = ""
    @State private var otpCode = ""
    @State private var otpSent = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showUserTypeSelection = false
    @State private var selectedUserType: UserType = .pilot
    @State private var callSign = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sign In with Phone")
                .font(.title3)
                .fontWeight(.semibold)
            
            if !otpSent {
                VStack(spacing: 16) {
                    TextField("Phone Number", text: $phoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    Text("Include country code (e.g., +1234567890)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                CustomButton(
                    title: "Send Code",
                    action: sendOTP,
                    isLoading: authService.isLoading,
                    isDisabled: phoneNumber.isEmpty
                )
                .padding(.horizontal)
            } else {
                VStack(spacing: 16) {
                    TextField("Enter OTP Code", text: $otpCode)
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                CustomButton(
                    title: "Verify",
                    action: { showUserTypeSelection = true },
                    isLoading: authService.isLoading,
                    isDisabled: otpCode.isEmpty
                )
                .padding(.horizontal)
                
                Button("Resend Code") {
                    sendOTP()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showUserTypeSelection) {
            UserTypeSelectionSheet(
                userType: $selectedUserType,
                callSign: $callSign,
                onComplete: verifyOTP
            )
        }
    }
    
    private func sendOTP() {
        Task {
            do {
                try await authService.signInWithPhone(phone: phoneNumber)
                otpSent = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func verifyOTP() {
        Task {
            do {
                try await authService.verifyOTP(
                    phone: phoneNumber,
                    token: otpCode,
                    userType: selectedUserType,
                    callSign: selectedUserType == .pilot ? callSign : nil
                )
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Social Sign In View

struct SocialSignInView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showUserTypeSelection = false
    @State private var selectedAuthMethod: AuthMethod?
    @State private var selectedUserType: UserType = .pilot
    @State private var callSign = ""
    
    enum AuthMethod {
        case apple, google
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sign In with Social")
                .font(.title3)
                .fontWeight(.semibold)
            
            // Temporarily commented out
            /*
            VStack(spacing: 16) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .frame(height: 50)
                .cornerRadius(10)
                
                Button {
                    selectedAuthMethod = .google
                    showUserTypeSelection = true
                } label: {
                    HStack {
                        Image(systemName: "g.circle.fill")
                            .font(.title3)
                        Text("Sign in with Google")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            */
            
            Text("Social sign-in temporarily disabled")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
            
            Text("Choose your preferred sign-in method")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showUserTypeSelection) {
            UserTypeSelectionSheet(
                userType: $selectedUserType,
                callSign: $callSign,
                onComplete: handleSocialSignIn
            )
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            selectedAuthMethod = .apple
            showUserTypeSelection = true
            
            Task {
                do {
                    try await authService.signInWithApple(
                        authorization: authorization,
                        userType: selectedUserType,
                        callSign: selectedUserType == .pilot ? callSign : nil
                    )
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func handleSocialSignIn() {
        Task {
            do {
                if selectedAuthMethod == .google {
                    try await authService.signInWithGoogle(
                        userType: selectedUserType,
                        callSign: selectedUserType == .pilot ? callSign : nil
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - User Type Selection Sheet

struct UserTypeSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var userType: UserType
    @Binding var callSign: String
    let onComplete: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Welcome to Buzz!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("Tell us about yourself")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("I am a...")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        UserTypeButton(
                            title: "Pilot",
                            icon: "PilotIcon",
                            isCustomImage: true,
                            isSelected: userType == .pilot
                        ) {
                            userType = .pilot
                        }
                        
                        UserTypeButton(
                            title: "Customer",
                            icon: "person.fill",
                            isCustomImage: false,
                            isSelected: userType == .customer
                        ) {
                            userType = .customer
                        }
                    }
                }
                .padding(.horizontal)
                
                if userType == .pilot {
                    VStack(spacing: 8) {
                        TextField("Call Sign", text: $callSign)
                            .textContentType(.nickname)
                            .autocapitalization(.allCharacters)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        
                        Text("Your unique pilot identifier")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                CustomButton(
                    title: "Continue",
                    action: {
                        onComplete()
                        dismiss()
                    },
                    isDisabled: userType == .pilot && callSign.isEmpty
                )
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

