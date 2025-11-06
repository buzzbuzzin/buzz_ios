//
//  CallSignEditView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct CallSignEditView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var profileService = ProfileService()
    @Environment(\.dismiss) var dismiss
    
    @State private var callSign = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text("Call Sign")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                
                // Description
                Text("This is your unique call sign that other users will see when referring to you.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Call Sign Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Call Sign")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Call Sign", text: $callSign)
                            .autocapitalization(.allCharacters)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !callSign.isEmpty {
                            Button(action: {
                                callSign = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Update Button
            VStack {
                CustomButton(
                    title: "Update",
                    action: updateCallSign,
                    isLoading: isLoading
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Call Sign")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentCallSign()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadCurrentCallSign() {
        callSign = authService.userProfile?.callSign ?? ""
    }
    
    private func updateCallSign() {
        guard let currentUser = authService.currentUser else { return }
        
        isLoading = true
        Task {
            let userId = currentUser.id
            do {
                try await profileService.updateProfile(
                    userId: userId,
                    firstName: nil,
                    lastName: nil,
                    callSign: callSign.isEmpty ? nil : callSign,
                    email: nil,
                    phone: nil,
                    gender: nil
                )
                await authService.checkAuthStatus()
                isLoading = false
                dismiss()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

