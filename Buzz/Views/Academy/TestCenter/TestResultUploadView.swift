//
//  TestResultUploadView.swift
//  Buzz
//
//  View for uploading test result documents for non-multiple-choice exams
//

import SwiftUI
import Auth
import PhotosUI
import UniformTypeIdentifiers

struct TestResultUploadView: View {
    let examType: ExamType
    let testId: UUID
    let courseId: UUID
    var onUploadComplete: (() -> Void)?
    
    @EnvironmentObject var authService: AuthService
    @StateObject private var uploadService = ExamResultUploadService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedFiles: [(data: Data, fileName: String, mimeType: String)] = []
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var isProcessing = false
    @State private var showDocumentPicker = false
    
    private var canUpload: Bool {
        !selectedFiles.isEmpty && !uploadService.isUploading
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upload Test Results")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Please upload your \(examType.displayName) test result documents. You can upload photos or PDF files.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("Accepted formats: JPG, PNG, PDF, HEIC")
                                    .font(.caption)
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("Maximum file size: 10MB per file")
                                    .font(.caption)
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("You can upload multiple files")
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding()
                    
                    // File Selection Buttons
                    VStack(spacing: 12) {
                        // Photo Library Button
                        PhotosPicker(
                            selection: $selectedItems,
                            maxSelectionCount: 5,
                            matching: .any(of: [.images, .not(.videos)])
                        ) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Select from Photos")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .onChange(of: selectedItems) { oldValue, newValue in
                            Task {
                                await loadSelectedPhotos(newValue)
                            }
                        }
                        
                        // Document Picker Button
                        Button(action: {
                            showDocumentPicker = true
                        }) {
                            HStack {
                                Image(systemName: "doc.fill")
                                Text("Select PDF Document")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Selected Files List
                    if !selectedFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Selected Files (\(selectedFiles.count))")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(selectedFiles.indices, id: \.self) { index in
                                HStack {
                                    Image(systemName: fileIcon(for: selectedFiles[index].fileName))
                                        .foregroundColor(.blue)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(selectedFiles[index].fileName)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        
                                        Text(formatFileSize(selectedFiles[index].data.count))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        selectedFiles.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Upload Progress
                    if uploadService.isUploading {
                        VStack(spacing: 12) {
                            ProgressView(value: uploadService.uploadProgress)
                                .progressViewStyle(.linear)
                            
                            Text("Uploading... \(Int(uploadService.uploadProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    // Upload Button
                    Button(action: {
                        Task {
                            await uploadFiles()
                        }
                    }) {
                        HStack {
                            if uploadService.isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                            }
                            Text(uploadService.isUploading ? "Uploading..." : "Upload Test Results")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canUpload ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canUpload)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Upload Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: true
            ) { result in
                handleDocumentSelection(result)
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK") {
                    onUploadComplete?()
                    dismiss()
                }
            } message: {
                Text("Your test results have been uploaded successfully and are now under review. You'll be notified once they're approved.")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") {}
            } message: {
                Text(uploadService.uploadError ?? "Failed to upload files")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        isProcessing = true
        
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                // Get file name from identifier or create a default one
                let fileName = "photo_\(Date().timeIntervalSince1970).jpg"
                let mimeType = ExamResultUploadService.getMimeType(for: fileName)
                
                // Validate file
                do {
                    try ExamResultUploadService.validateFile(data: data, fileName: fileName)
                    selectedFiles.append((data: data, fileName: fileName, mimeType: mimeType))
                } catch {
                    uploadService.uploadError = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
        
        isProcessing = false
    }
    
    private func handleDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                if let data = try? Data(contentsOf: url) {
                    let fileName = url.lastPathComponent
                    let mimeType = ExamResultUploadService.getMimeType(for: fileName)
                    
                    // Validate file
                    do {
                        try ExamResultUploadService.validateFile(data: data, fileName: fileName)
                        selectedFiles.append((data: data, fileName: fileName, mimeType: mimeType))
                    } catch {
                        uploadService.uploadError = error.localizedDescription
                        showErrorAlert = true
                    }
                }
            }
        case .failure(let error):
            uploadService.uploadError = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func uploadFiles() async {
        guard let currentUser = authService.currentUser else { return }
        
        do {
            _ = try await uploadService.uploadTestResultFiles(
                pilotId: currentUser.id,
                testId: testId,
                courseId: courseId,
                fileData: selectedFiles
            )
            
            showSuccessAlert = true
        } catch {
            showErrorAlert = true
        }
    }
    
    private func fileIcon(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.fill"
        case "jpg", "jpeg", "png", "heic", "heif":
            return "photo.fill"
        default:
            return "doc"
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
