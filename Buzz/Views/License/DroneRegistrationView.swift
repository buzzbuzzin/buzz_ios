//
//  DroneRegistrationView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import PhotosUI
import Auth

struct DroneRegistrationView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var registrationService = DroneRegistrationService()
    
    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    @State private var showImageSourceSheet = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedImage: UIImage?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack {
            if registrationService.isLoading {
                LoadingView(message: "Loading registrations...")
            } else if registrationService.registrations.isEmpty {
                EmptyStateView(
                    icon: "airplane",
                    title: "No Drone Registrations",
                    message: "Upload your drone registration file to verify your drone",
                    actionTitle: "Upload Registration",
                    action: { showDocumentPicker = true }
                )
            } else {
                List {
                    ForEach(registrationService.registrations) { registration in
                        DroneRegistrationRow(registration: registration)
                    }
                    .onDelete(perform: deleteRegistration)
                }
                .refreshable {
                    await loadRegistrations()
                }
            }
        }
        .navigationTitle("Drone Registration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showImageSourceSheet = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                    
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("Choose File", systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
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
        .task {
            await loadRegistrations()
        }
    }
    
    private func loadRegistrations() async {
        guard let currentUser = authService.currentUser else { return }
        try? await registrationService.fetchRegistrations(pilotId: currentUser.id)
    }
    
    private func uploadImage(_ image: UIImage) {
        guard let currentUser = authService.currentUser,
              let imageData = registrationService.compressImage(image) else {
            errorMessage = "Failed to process image"
            showError = true
            return
        }
        
        let userId = currentUser.id
        
        Task {
            do {
                let fileName = "\(UUID().uuidString).jpg"
                _ = try await registrationService.uploadRegistration(
                    pilotId: userId,
                    data: imageData,
                    fileName: fileName,
                    fileType: .image
                )
                await loadRegistrations()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func uploadDocument(url: URL) {
        guard let currentUser = authService.currentUser else { return }
        
        Task {
            let userId = currentUser.id
            do {
                let data = try Data(contentsOf: url)
                let fileName = url.lastPathComponent
                _ = try await registrationService.uploadRegistration(
                    pilotId: userId,
                    data: data,
                    fileName: fileName,
                    fileType: .pdf
                )
                await loadRegistrations()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func deleteRegistration(at offsets: IndexSet) {
        for index in offsets {
            let registration = registrationService.registrations[index]
            Task {
                try? await registrationService.deleteRegistration(registration: registration)
                await loadRegistrations()
            }
        }
    }
}

// MARK: - Drone Registration Row

struct DroneRegistrationRow: View {
    let registration: DroneRegistration
    
    var body: some View {
        HStack {
            Image(systemName: registration.fileType == .pdf ? "doc.fill" : "photo.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(registration.fileType == .pdf ? "PDF Document" : "Image")
                    .font(.headline)
                
                Text("Uploaded \(registration.uploadedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

