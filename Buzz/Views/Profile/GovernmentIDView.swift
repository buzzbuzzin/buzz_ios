//
//  GovernmentIDView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import LocalAuthentication
import Auth
import PhotosUI

struct GovernmentIDView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var identityService = IdentityVerificationService()
    @Environment(\.dismiss) var dismiss
    
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var showImageSourceSheet = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedImage: UIImage?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeleteAlert = false
    @State private var isAuthenticated = false
    @State private var showAuthPrompt = true
    
    var body: some View {
        VStack(spacing: 0) {
            if showAuthPrompt && !isAuthenticated {
                // Authentication prompt
                VStack(spacing: 24) {
                    Image(systemName: "faceid")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Verify Your Identity")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Please authenticate with Face ID to upload your driver's license for identity verification.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    CustomButton(
                        title: "Authenticate with Face ID",
                        action: authenticateWithFaceID
                    )
                    .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Content
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    Text("Government ID")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 8)
                    
                    // Description
                    Text("Upload your driver's license to verify your identity. This helps ensure the safety and security of our platform.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if identityService.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    } else if let governmentID = identityService.governmentID {
                        // Show uploaded ID info
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("ID Uploaded")
                                    .font(.headline)
                            }
                            
                            HStack {
                                Text("Status:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(governmentID.verificationStatus.displayName)
                                    .fontWeight(.semibold)
                                    .foregroundColor(statusColor(governmentID.verificationStatus))
                            }
                            
                            HStack {
                                Text("Uploaded:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(governmentID.uploadedAt, style: .date)
                                    .foregroundColor(.secondary)
                            }
                            
                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Remove ID")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    } else {
                        // Upload options
                        VStack(spacing: 16) {
                            Button(action: {
                                showImageSourceSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("Take Photo")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            
                            Button(action: {
                                showDocumentPicker = true
                            }) {
                                HStack {
                                    Image(systemName: "doc.fill")
                                    Text("Choose File")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Government ID")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Choose Photo Source", isPresented: $showImageSourceSheet, titleVisibility: .visible) {
            Button("Take Photo") {
                imageSourceType = .camera
                showImagePicker = true
            }
            Button("Choose from Library") {
                imageSourceType = .photoLibrary
                showImagePicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: imageSourceType)
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { url in
                uploadDocument(url: url)
            }
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                uploadImage(image)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Delete ID", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteID()
            }
        } message: {
            Text("Are you sure you want to remove your government ID?")
        }
        .task {
            await loadGovernmentID()
        }
    }
    
    private func authenticateWithFaceID() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Please authenticate to upload your driver's license for identity verification."
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        isAuthenticated = true
                        showAuthPrompt = false
                    } else {
                        errorMessage = authenticationError?.localizedDescription ?? "Authentication failed"
                        showError = true
                    }
                }
            }
        } else {
            // Fallback to device passcode if biometrics not available
            let context = LAContext()
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Please authenticate to upload your driver's license.") { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        isAuthenticated = true
                        showAuthPrompt = false
                    } else {
                        errorMessage = authenticationError?.localizedDescription ?? "Authentication failed"
                        showError = true
                    }
                }
            }
        }
    }
    
    private func statusColor(_ status: VerificationStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .verified: return .green
        case .rejected: return .red
        }
    }
    
    private func loadGovernmentID() async {
        guard let currentUser = authService.currentUser else { return }
        try? await identityService.fetchGovernmentID(userId: currentUser.id)
    }
    
    private func uploadImage(_ image: UIImage) {
        guard isAuthenticated,
              let currentUser = authService.currentUser,
              let imageData = identityService.compressImage(image) else {
            errorMessage = "Failed to process image"
            showError = true
            return
        }
        
        let userId = currentUser.id
        
        Task {
            do {
                let fileName = "\(UUID().uuidString).jpg"
                _ = try await identityService.uploadGovernmentID(
                    userId: userId,
                    data: imageData,
                    fileName: fileName,
                    fileType: .image
                )
                await loadGovernmentID()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func uploadDocument(url: URL) {
        guard isAuthenticated,
              let currentUser = authService.currentUser else { return }
        
        Task {
            let userId = currentUser.id
            do {
                let data = try Data(contentsOf: url)
                let fileName = url.lastPathComponent
                _ = try await identityService.uploadGovernmentID(
                    userId: userId,
                    data: data,
                    fileName: fileName,
                    fileType: .pdf
                )
                await loadGovernmentID()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func deleteID() {
        Task {
            do {
                try await identityService.deleteGovernmentID()
                await loadGovernmentID()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

