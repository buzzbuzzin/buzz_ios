//
//  SignUpView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import Foundation

struct SignUpView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var role: CustomerRole? = nil
    @State private var selectedSpecialization: BookingSpecialization? = nil
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var userType: UserType = .pilot
    @State private var callSign = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSigningUp = false
    @State private var customerSignUpPage: Int = 1 // 1 for basic info, 2 for role selection, 3 for specialization, 4 for confirmation
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                        
                        Text("Join Buzz")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        // Hide subtitle on customer pages 2 and 3 (role and specialization selection)
                        if !(userType == .customer && (customerSignUpPage == 2 || customerSignUpPage == 3)) {
                            Text(headerSubtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 40)
                    
                    // User Type Selection (hidden on customer pages 2, 3, and 4)
                    if !(userType == .customer && (customerSignUpPage == 2 || customerSignUpPage == 3 || customerSignUpPage == 4)) {
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
                                    customerSignUpPage = 1 // Reset when switching to pilot
                            }
                            
                            UserTypeButton(
                                title: "Customer",
                                icon: "person.fill",
                                isCustomImage: false,
                                isSelected: userType == .customer
                            ) {
                                userType = .customer
                                    customerSignUpPage = 1 // Reset to page 1 when switching to customer
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        if userType == .customer {
                            // Customer sign-up: Show different pages
                            if customerSignUpPage == 1 {
                                // Page 1: Basic Information
                                customerBasicInfoFields
                            } else if customerSignUpPage == 2 {
                                // Page 2: Role Selection
                                customerRoleSelectionFields
                            } else if customerSignUpPage == 3 {
                                // Page 3: Specialization Selection
                                customerSpecializationFields
                            } else {
                                // Page 4: Confirmation
                                customerConfirmationFields
                            }
                        } else {
                            // Pilot sign-up: Show all fields on one page
                            pilotSignUpFields
                        }
                    }
                    .padding(.horizontal)
                    
                    // Page Indicator (only for customer sign-up)
                    if userType == .customer {
                        PageIndicator(currentPage: customerSignUpPage, totalPages: 4)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                    }
                    
                    // Action Button
                    if userType == .customer {
                        if customerSignUpPage == 1 {
                            // Next button for customer page 1
                            CustomButton(
                                title: "Next",
                                action: {
                                    customerSignUpPage = 2
                                },
                                isLoading: false,
                                isDisabled: !isCustomerPage1Valid
                            )
                            .padding(.horizontal)
                        } else if customerSignUpPage == 2 {
                            // Next button for customer page 2
                            CustomButton(
                                title: "Next",
                                action: {
                                    customerSignUpPage = 3
                                },
                                isLoading: false,
                                isDisabled: role == nil
                            )
                            .padding(.horizontal)
                        } else if customerSignUpPage == 3 {
                            // Next button for customer page 3
                            CustomButton(
                                title: "Next",
                                action: {
                                    customerSignUpPage = 4
                                },
                                isLoading: false,
                                isDisabled: selectedSpecialization == nil
                            )
                            .padding(.horizontal)
                        } else {
                            // Finish Sign-up button for customer page 4
                            CustomButton(
                                title: "Finish Sign-up",
                                action: signUp,
                                isLoading: authService.isLoading || isSigningUp,
                                isDisabled: !isFormValid
                            )
                            .padding(.horizontal)
                        }
                    } else {
                        // Sign Up button for pilots
                        CustomButton(
                            title: "Sign Up",
                            action: signUp,
                            isLoading: authService.isLoading || isSigningUp,
                            isDisabled: !isFormValid
                        )
                        .padding(.horizontal)
                    }
                    
                    if isSigningUp {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Creating your account...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                    
                    // Sign In Link
                    HStack {
                        Text("Already have an account?")
                            .foregroundColor(.secondary)
                        Button("Sign In") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
                .padding(.bottom, 40)
            }
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        // Only handle gestures for customer sign-up
                        guard userType == .customer else { return }
                        
                        // Swipe left to go back (pages 2, 3, and 4)
                        if value.translation.width < -50 {
                            if customerSignUpPage == 2 {
                                customerSignUpPage = 1
                            } else if customerSignUpPage == 3 {
                                customerSignUpPage = 2
                            } else if customerSignUpPage == 4 {
                                customerSignUpPage = 3
                            }
                        }
                        // Swipe right to go forward (only if current page is valid)
                        else if value.translation.width > 50 {
                            if customerSignUpPage == 1 && isCustomerPage1Valid {
                                customerSignUpPage = 2
                            } else if customerSignUpPage == 2 && role != nil {
                                customerSignUpPage = 3
                            } else if customerSignUpPage == 3 && selectedSpecialization != nil {
                                customerSignUpPage = 4
                            }
                        }
                    }
            )
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    // User is now authenticated, dismiss the signup view
                    dismiss()
                }
            }
        }
    }
    
    private var headerSubtitle: String {
        if userType == .customer {
            switch customerSignUpPage {
            case 1: return "Create your account"
            case 2: return "Select your role"
            case 3: return "Choose your specialization"
            case 4: return "Review your information"
            default: return "Create your account"
            }
        } else {
            return "Start your drone pilot journey"
        }
    }
    
    private var isCustomerPage1Valid: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 6
    }
    
    private var isFormValid: Bool {
        if userType == .customer {
            return isCustomerPage1Valid && role != nil && selectedSpecialization != nil
        } else {
            return !firstName.isEmpty &&
            !lastName.isEmpty &&
            !email.isEmpty &&
            !password.isEmpty &&
            password == confirmPassword &&
            password.count >= 6 &&
            !callSign.isEmpty
        }
    }
    
    // Custom ordering for specialization cards: Logistics and Drone Art at the bottom
    private var orderedSpecializations: [BookingSpecialization] {
        [
            .automotive,
            .realEstate,
            .motionPicture,
            .agriculture,
            .searchRescue,
            .surveillanceSecurity,
            .inspections,
            .mappingSurveying,
            .logistics,
            .droneArt
        ]
    }
    
    // MARK: - Customer Sign Up Fields
    
    private var customerBasicInfoFields: some View {
        Group {
            // First Name
            VStack(alignment: .leading, spacing: 8) {
                Text("First Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                TextField("Enter your first name", text: $firstName)
                    .textContentType(.givenName)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            
            // Last Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Last Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                TextField("Enter your last name", text: $lastName)
                    .textContentType(.familyName)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            
            // Email
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                TextField("Enter your email", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            
            // Password
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                SecureField("Enter your password", text: $password)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            
            // Confirm Password
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                SecureField("Confirm your password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
        }
    }
    
    private var customerRoleSelectionFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select a role that fits you")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Role cards in a grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(CustomerRole.allCases, id: \.self) { roleOption in
                    RoleCard(
                        role: roleOption,
                        isSelected: role == roleOption
                    ) {
                        role = roleOption
                    }
                }
            }
        }
    }
    
    private var customerSpecializationFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your industry")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Select the type of drone service you're interested in")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Specialization cards in a grid (with custom ordering: Logistics and Drone Art at the bottom)
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(orderedSpecializations, id: \.self) { specialization in
                    SpecializationCard(
                        specialization: specialization,
                        isSelected: selectedSpecialization == specialization
                    ) {
                        // Toggle selection: if already selected, deselect it
                        if selectedSpecialization == specialization {
                            selectedSpecialization = nil
                        } else {
                            selectedSpecialization = specialization
                        }
                    }
                }
            }
        }
    }
    
    private var customerConfirmationFields: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Please review your information")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Tap any section to edit")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Basic Information Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Basic Information")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Button(action: {
                        customerSignUpPage = 1
                    }) {
                        Text("Edit")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ConfirmationRow(label: "First Name", value: firstName)
                    ConfirmationRow(label: "Last Name", value: lastName)
                    ConfirmationRow(label: "Email", value: email)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            
            // Role Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Role")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Button(action: {
                        customerSignUpPage = 2
                    }) {
                        Text("Edit")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                
                if let role = role {
                    HStack {
                        Image(systemName: role.icon)
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Text(role.displayName)
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                } else {
                    Text("Not selected")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
            }
            
            // Specialization Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Specialization")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Button(action: {
                        customerSignUpPage = 3
                    }) {
                        Text("Edit")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                
                if let specialization = selectedSpecialization {
                    HStack {
                        Image(systemName: specialization.icon)
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Text(specialization.displayName)
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                } else {
                    Text("Not selected")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
            }
        }
    }
    
    // MARK: - Pilot Sign Up Fields
    
    private var pilotSignUpFields: some View {
        Group {
            // First Name
            VStack(alignment: .leading, spacing: 8) {
                Text("First Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                TextField("Enter your first name", text: $firstName)
                    .textContentType(.givenName)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            
            // Last Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Last Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                TextField("Enter your last name", text: $lastName)
                    .textContentType(.familyName)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            
            // Email
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                TextField("Enter your email", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            
            // Password
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                SecureField("Enter your password", text: $password)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            
            // Confirm Password
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                SecureField("Confirm your password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            
            // Call Sign
            VStack(alignment: .leading, spacing: 8) {
                Text("Call Sign")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                TextField("Enter your call sign", text: $callSign)
                    .textContentType(.nickname)
                    .autocapitalization(.allCharacters)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                Text("Your unique pilot identifier")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func signUp() {
        isSigningUp = true
        Task {
            do {
                try await authService.signUpWithEmail(
                    email: email,
                    password: password,
                    userType: userType,
                    firstName: firstName,
                    lastName: lastName,
                    callSign: userType == .pilot ? callSign : nil,
                    role: userType == .customer ? role : nil,
                    specialization: userType == .customer ? selectedSpecialization : nil
                )
                
                // Success! The app will automatically navigate to main view
                // because authService.isAuthenticated is now true
                isSigningUp = false
                
            } catch {
                isSigningUp = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct UserTypeButton: View {
    let title: String
    let icon: String
    let isCustomImage: Bool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                if isCustomImage {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 30))
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct RoleCard: View {
    let role: CustomerRole
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: role.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(role.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PageIndicator: View {
    let currentPage: Int
    let totalPages: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalPages, id: \.self) { page in
                Circle()
                    .fill(page == currentPage ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut, value: currentPage)
            }
        }
    }
}

struct ConfirmationRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value.isEmpty ? "Not provided" : value)
                .font(.body)
                .foregroundColor(value.isEmpty ? .secondary : .primary)
            
            Spacer()
        }
    }
}

