//
//  CertificateBadgeUploadView.swift
//  Buzz
//
//  Created by Xinyu Fang on 1/14/26.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// A view that allows pilots to upload certificates for First Aid or Basic Firefighter badges
/// independently of the Beacon program onboarding flow.
struct CertificateBadgeUploadView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var badgeService: BadgeService
    @StateObject private var beaconService = BeaconService()
    let userId: UUID
    let badgeType: Badge.BadgeType
    
    @State private var isLoading = false
    @State private var showUploadOptions = false
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedDocumentURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var uploadSuccess = false
    
    private var trainingType: BeaconTrainingType? {
        badgeType.beaconTrainingType
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Badge Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: badgeType == .firstAid ? [.red.opacity(0.8), .pink.opacity(0.6)] : [.orange.opacity(0.8), .red.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: badgeType.icon)
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 20)
                    
                    // Badge Info
                    VStack(spacing: 8) {
                        Text(badgeType.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(badgeDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Success View
                    if uploadSuccess {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            
                            Text("Certificate Uploaded!")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            Text("Your \(badgeType.displayName) badge has been awarded.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: { dismiss() }) {
                                Text("Done")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    } else {
                        // Upload Section
                        VStack(spacing: 20) {
                            // Upload Button
                            Button(action: { showUploadOptions = true }) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "arrow.up.doc.fill")
                                        Text("Upload Certificate")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(badgeType == .firstAid ? Color.red : Color.orange)
                                .cornerRadius(12)
                            }
                            .disabled(isLoading)
                            .padding(.horizontal)
                            
                            // Requirements
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Requirements")
                                    .font(.headline)
                                
                                RequirementRow(
                                    number: 1,
                                    text: "Complete \(trainingType?.displayName ?? "training") with an accredited provider"
                                )
                                
                                RequirementRow(
                                    number: 2,
                                    text: "Take a photo or scan of your certificate"
                                )
                                
                                RequirementRow(
                                    number: 3,
                                    text: "Upload it here to earn your badge"
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            // Info Note
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                
                                Text("This certificate will also count towards Beacon program requirements if you decide to join later.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Earn Badge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Upload Certificate", isPresented: $showUploadOptions, titleVisibility: .visible) {
                Button("Photo Library") {
                    showImagePicker = true
                }
                Button("Documents") {
                    showDocumentPicker = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showImagePicker) {
                CertificateImagePicker(image: $selectedImage)
            }
            .sheet(isPresented: $showDocumentPicker) {
                CertificateDocumentPicker { url in
                    selectedDocumentURL = url
                }
            }
            .onChange(of: selectedImage) { newImage in
                if let image = newImage {
                    Task {
                        await uploadCertificate(image: image)
                    }
                }
            }
            .onChange(of: selectedDocumentURL) { newURL in
                if let url = newURL {
                    Task {
                        await uploadCertificate(url: url)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var badgeDescription: String {
        switch badgeType {
        case .firstAid:
            return "Earn this badge by uploading your First Aid/CPR certification from an accredited provider."
        case .basicFirefighter:
            return "Earn this badge by uploading your basic firefighting training certificate from an accredited provider."
        default:
            return "Upload your certificate to earn this badge."
        }
    }
    
    private func uploadCertificate(image: UIImage) async {
        guard let trainingType = trainingType else {
            errorMessage = "Invalid badge type"
            showError = true
            return
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to process image"
            showError = true
            return
        }
        
        await performUpload(
            data: imageData,
            fileName: "\(trainingType.rawValue)_\(Date().timeIntervalSince1970).jpg",
            isPDF: false,
            trainingType: trainingType
        )
    }
    
    private func uploadCertificate(url: URL) async {
        guard let trainingType = trainingType else {
            errorMessage = "Invalid badge type"
            showError = true
            return
        }
        
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
            let isPDF = fileName.lowercased().hasSuffix(".pdf")
            
            await performUpload(
                data: data,
                fileName: fileName,
                isPDF: isPDF,
                trainingType: trainingType
            )
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func performUpload(data: Data, fileName: String, isPDF: Bool, trainingType: BeaconTrainingType) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Upload certificate using BeaconService
            // This stores it in beacon_training_progress table
            // The database trigger automatically awards the badge
            _ = try await beaconService.uploadTrainingCertificate(
                userId: userId,
                trainingType: trainingType,
                data: data,
                fileName: fileName,
                isPDF: isPDF
            )
            
            // Refresh badges to show the newly earned badge
            try await badgeService.fetchPilotBadges(pilotId: userId)
            try await badgeService.fetchAvailableBadges(pilotId: userId)
            
            await MainActor.run {
                isLoading = false
                uploadSuccess = true
                selectedImage = nil
                selectedDocumentURL = nil
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Requirement Row

private struct RequirementRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "\(number).circle.fill")
                .foregroundColor(.secondary)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Certificate Image Picker

struct CertificateImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: CertificateImagePicker
        
        init(_ parent: CertificateImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    self.parent.image = image as? UIImage
                }
            }
        }
    }
}

// MARK: - Certificate Document Picker

struct CertificateDocumentPicker: UIViewControllerRepresentable {
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
        let parent: CertificateDocumentPicker
        
        init(_ parent: CertificateDocumentPicker) {
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
