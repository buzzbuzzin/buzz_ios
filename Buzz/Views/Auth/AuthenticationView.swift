//
//  AuthenticationView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @State private var showSignUp = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                    
                    Text("Welcome aboard")
                        .font(.system(size: 32, weight: .semibold))
                    
                    Text("or back")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)
                .padding(.bottom, 40)
                
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
                    Button("Sign Up") {
                        showSignUp = true
                    }
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
            .onChange(of: authService.isAuthenticated) { _, isAuth in
                // Dismiss signup sheet when authentication succeeds
                if isAuth {
                    showSignUp = false
                }
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
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sign In with Email")
                .font(.title3)
                .fontWeight(.semibold)
            
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
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
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
                            icon: "airplane",
                            isSelected: userType == .pilot
                        ) {
                            userType = .pilot
                        }
                        
                        UserTypeButton(
                            title: "Customer",
                            icon: "person.fill",
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

