//
//  LicenseManagementView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import PhotosUI
import Auth

struct LicenseManagementView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var licenseService = LicenseUploadService()
    
    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack {
            if licenseService.isLoading {
                LoadingView(message: "Loading licenses...")
            } else if licenseService.licenses.isEmpty {
                EmptyStateView(
                    icon: "doc.badge.plus",
                    title: "No Licenses",
                    message: "Upload your drone pilot license to start accepting bookings",
                    actionTitle: "Upload License",
                    action: { showDocumentPicker = true }
                )
            } else {
                List {
                    ForEach(licenseService.licenses) { license in
                        LicenseRow(license: license)
                    }
                    .onDelete(perform: deleteLicense)
                }
                .refreshable {
                    await loadLicenses()
                }
            }
        }
        .navigationTitle("Licenses")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showImagePicker = true
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
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
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
            await loadLicenses()
        }
    }
    
    private func loadLicenses() async {
        guard let currentUser = authService.currentUser else { return }
        try? await licenseService.fetchLicenses(pilotId: currentUser.id)
    }
    
    private func uploadImage(_ image: UIImage) {
        guard let currentUser = authService.currentUser,
              let imageData = licenseService.compressImage(image) else {
            errorMessage = "Failed to process image"
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
        guard let currentUser = authService.currentUser else { return }
        
        Task {
            let userId = currentUser.id
            do {
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
    
    private func deleteLicense(at offsets: IndexSet) {
        for index in offsets {
            let license = licenseService.licenses[index]
            Task {
                try? await licenseService.deleteLicense(license: license)
                await loadLicenses()
            }
        }
    }
}

// MARK: - License Row

struct LicenseRow: View {
    let license: PilotLicense
    
    var body: some View {
        HStack {
            Image(systemName: license.fileType == .pdf ? "doc.fill" : "photo.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(license.fileType == .pdf ? "PDF Document" : "Image")
                    .font(.headline)
                
                Text("Uploaded \(license.uploadedAt.formatted(date: .abbreviated, time: .shortened))")
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

