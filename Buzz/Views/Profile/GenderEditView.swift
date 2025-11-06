//
//  GenderEditView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct GenderEditView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var profileService = ProfileService()
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedGender: Gender?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text("Gender")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                
                // Description
                Text("This information helps us provide you with a personalized experience.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Gender Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gender")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    List {
                        ForEach(Gender.allCases, id: \.self) { gender in
                            Button(action: {
                                selectedGender = gender
                            }) {
                                HStack {
                                    Text(gender.displayName)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedGender == gender {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .frame(height: CGFloat(Gender.allCases.count * 50))
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Update Button
            VStack {
                CustomButton(
                    title: "Update",
                    action: updateGender,
                    isLoading: isLoading
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Gender")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentGender()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadCurrentGender() {
        selectedGender = authService.userProfile?.gender
    }
    
    private func updateGender() {
        guard let currentUser = authService.currentUser else { return }
        
        isLoading = true
        Task {
            let userId = currentUser.id
            do {
                try await profileService.updateProfile(
                    userId: userId,
                    firstName: nil,
                    lastName: nil,
                    callSign: nil,
                    email: nil,
                    phone: nil,
                    gender: selectedGender
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

