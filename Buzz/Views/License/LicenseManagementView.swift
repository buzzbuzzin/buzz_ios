//
//  LicenseManagementView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import PhotosUI
import Auth
import LocalAuthentication

struct LicenseManagementView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var licenseService = LicenseUploadService()
    
    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    @State private var showUploadOptions = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedImage: UIImage?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isAuthenticated = false
    @State private var showAuthPrompt = true
    @State private var selectedLicense: PilotLicense?
    @State private var licenseToDelete: PilotLicense?
    @State private var showDeleteConfirmation = false
    
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
                    
                    Text("Please authenticate with Face ID to access pilot license information. This helps protect your sensitive information.")
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
                if licenseService.isLoading {
                    LoadingView(message: "Loading licenses...")
                } else if licenseService.licenses.isEmpty {
                    EmptyStateView(
                        icon: "doc.badge.plus",
                        title: "No Licenses",
                        message: "Upload your drone pilot license to start accepting bookings",
                        actionTitle: "Upload License",
                        action: { showUploadOptions = true }
                    )
                } else {
                    List {
                        ForEach(licenseService.licenses) { license in
                            LicenseRow(
                                license: license,
                                onTap: {
                                    print("DEBUG LicenseView: Eye icon tapped")
                                    print("DEBUG LicenseView: License ID: \(license.id)")
                                    print("DEBUG LicenseView: License URL: \(license.fileUrl)")
                                    print("DEBUG LicenseView: License type: \(license.fileType)")
                                    // Use Task to ensure state update happens on main thread
                                    Task { @MainActor in
                                        self.selectedLicense = license
                                        print("DEBUG LicenseView: selectedLicense set to: \(self.selectedLicense?.id.uuidString ?? "nil")")
                                    }
                                },
                                onDelete: {
                                    licenseToDelete = license
                                    showDeleteConfirmation = true
                                }
                            )
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                licenseToDelete = licenseService.licenses[index]
                                showDeleteConfirmation = true
                            }
                        }
                    }
                    .refreshable {
                        await loadLicenses()
                    }
                }
            }
        }
        .navigationTitle("Licenses")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Upload License", isPresented: $showUploadOptions, titleVisibility: .visible) {
            Button("Take Photo") {
                guard isAuthenticated else {
                    errorMessage = "Please authenticate first"
                    showError = true
                    return
                }
                imageSourceType = .camera
                showImagePicker = true
            }
            Button("Choose from Photo Library") {
                guard isAuthenticated else {
                    errorMessage = "Please authenticate first"
                    showError = true
                    return
                }
                imageSourceType = .photoLibrary
                showImagePicker = true
            }
            Button("Choose File") {
                guard isAuthenticated else {
                    errorMessage = "Please authenticate first"
                    showError = true
                    return
                }
                showDocumentPicker = true
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
        .alert("Delete License", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                licenseToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let license = licenseToDelete {
                    deleteLicense(license: license)
                }
                licenseToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this license? This action cannot be undone.")
        }
        .sheet(item: $selectedLicense) { license in
            NavigationStack {
                FileViewer(
                    fileUrl: license.fileUrl,
                    fileType: license.fileType == .pdf ? .pdf : .image,
                    bucketName: "pilot-licenses"
                )
            }
            .onAppear {
                print("DEBUG LicenseView: Sheet appeared for license: \(license.id)")
                print("DEBUG LicenseView: File URL: \(license.fileUrl)")
                print("DEBUG LicenseView: File Type: \(license.fileType)")
            }
        }
        .task {
            if isAuthenticated {
                await loadLicenses()
            }
        }
    }
    
    private func authenticateWithFaceID() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Please authenticate to access pilot license information."
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        isAuthenticated = true
                        showAuthPrompt = false
                        Task {
                            await loadLicenses()
                        }
                    } else {
                        errorMessage = authenticationError?.localizedDescription ?? "Authentication failed"
                        showError = true
                    }
                }
            }
        } else {
            // Fallback to device passcode if biometrics not available
            let context = LAContext()
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Please authenticate to access pilot license information.") { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        isAuthenticated = true
                        showAuthPrompt = false
                        Task {
                            await loadLicenses()
                        }
                    } else {
                        errorMessage = authenticationError?.localizedDescription ?? "Authentication failed"
                        showError = true
                    }
                }
            }
        }
    }
    
    private func loadLicenses() async {
        guard let currentUser = authService.currentUser else { return }
        try? await licenseService.fetchLicenses(pilotId: currentUser.id)
    }
    
    private func uploadImage(_ image: UIImage) {
        guard isAuthenticated,
              let currentUser = authService.currentUser,
              let imageData = licenseService.compressImage(image) else {
            if !isAuthenticated {
                errorMessage = "Please authenticate first"
            } else {
                errorMessage = "Failed to process image"
            }
            showError = true
            return
        }
        
        let userId = currentUser.id
        
        Task {
            do {
                let fileName = "\(UUID().uuidString).jpg"
                _ = try await licenseService.uploadLicense(
                    pilotId: userId,
                    data: imageData,
                    fileName: fileName,
                    fileType: .image
                )
                await loadLicenses()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func uploadDocument(url: URL) {
        guard isAuthenticated,
              let currentUser = authService.currentUser else {
            errorMessage = "Please authenticate first"
            showError = true
            return
        }
        
        Task {
            let userId = currentUser.id
            do {
                // Request access to security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    throw NSError(domain: "FileAccessError", code: -1, 
                                userInfo: [NSLocalizedDescriptionKey: "Unable to access the selected file"])
                }
                
                // Ensure we stop accessing the resource when done
                defer {
                    url.stopAccessingSecurityScopedResource()
                }
                
                let data = try Data(contentsOf: url)
                let fileName = url.lastPathComponent
                _ = try await licenseService.uploadLicense(
                    pilotId: userId,
                    data: data,
                    fileName: fileName,
                    fileType: .pdf
                )
                await loadLicenses()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func deleteLicense(license: PilotLicense) {
        guard isAuthenticated else {
            errorMessage = "Please authenticate first"
            showError = true
            return
        }
        
        Task {
            do {
                try await licenseService.deleteLicense(license: license)
                await loadLicenses()
            } catch {
                errorMessage = "Failed to delete license: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

// MARK: - License Row

struct LicenseRow: View {
    let license: PilotLicense
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // File icon
            Image(systemName: license.fileType == .pdf ? "doc.fill" : "photo.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 50)
            
            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(license.fileType == .pdf ? "PDF Document" : "Image")
                    .font(.headline)
                
                Text("Uploaded \(license.uploadedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                // View button
                Button(action: {
                    print("DEBUG LicenseRow: View button tapped")
                    onTap()
                }) {
                    Image(systemName: "eye.fill")
                        .font(.body)
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Delete button
                Button(action: {
                    print("DEBUG LicenseRow: Delete button tapped")
                    onDelete()
                }) {
                    Image(systemName: "trash.fill")
                        .font(.body)
                        .foregroundColor(.red)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    var sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.onDocumentPicked(url)
            }
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

