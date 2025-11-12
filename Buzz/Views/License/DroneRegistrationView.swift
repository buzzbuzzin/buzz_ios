//
//  DroneRegistrationView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import PhotosUI
import Auth
import LocalAuthentication

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
    @State private var isAuthenticated = false
    @State private var showAuthPrompt = true
    @State private var selectedRegistration: DroneRegistration?
    @State private var registrationToDelete: DroneRegistration?
    @State private var showDeleteConfirmation = false
    @State private var registrationToEdit: DroneRegistration?
    @State private var showEditSheet = false
    
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
                    
                    Text("Please authenticate with Face ID to access drone registration. This helps protect your sensitive information.")
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
                if registrationService.isLoading {
                    LoadingView(message: "Loading registrations...")
                } else if registrationService.registrations.isEmpty {
                    EmptyStateView(
                        icon: "airplane",
                        title: "No Drone Registrations",
                        message: "Upload your drone registration files to verify your drones",
                        actionTitle: "Upload Registration",
                        action: { showImageSourceSheet = true }
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Registration cards
                            ForEach(registrationService.registrations) { registration in
                                DroneRegistrationRow(
                                    registration: registration,
                                    onTap: {
                                        print("DEBUG DroneRegistrationView: Eye icon tapped")
                                        print("DEBUG DroneRegistrationView: Registration ID: \(registration.id)")
                                        print("DEBUG DroneRegistrationView: Registration URL: \(registration.fileUrl)")
                                        print("DEBUG DroneRegistrationView: Registration type: \(registration.fileType)")
                                        // Use Task to ensure state update happens on main thread
                                        Task { @MainActor in
                                            self.selectedRegistration = registration
                                            print("DEBUG DroneRegistrationView: selectedRegistration set to: \(self.selectedRegistration?.id.uuidString ?? "nil")")
                                        }
                                    },
                                    onDelete: {
                                        registrationToDelete = registration
                                        showDeleteConfirmation = true
                                    },
                                    onEdit: {
                                        registrationToEdit = registration
                                        showEditSheet = true
                                    }
                                )
                            }
                            
                            // Notes section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Notes")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("1. OCR may not working properly to parse out correct information from your uploaded file. It is your responsibility to double check and make sure the data is correct.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("2. Your data will be kept safe and is used to verify your eligibility to operate your drones. This ensures public safety and protects you and others from risks.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("3. Per FAA regulation, register your drone at FAADroneZone whether flying under the Exception for Limited Recreational Operations or Part 107. All drones must be registered, except those that weigh 0.55 pounds or less (less than 250 grams) and are flown under the Exception for Limited Recreational Operations. Drones registered under the Exception for Limited Recreational Operations cannot be flown under Part 107.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Link("Learn more about registering your drone", destination: URL(string: "https://www.faa.gov/uas/getting_started/register_drone")!)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                    .refreshable {
                        await loadRegistrations()
                    }
                }
            }
        }
        .navigationTitle("Drone Registration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isAuthenticated {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showImageSourceSheet = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
        }
        .confirmationDialog("Upload Registration", isPresented: $showImageSourceSheet, titleVisibility: .visible) {
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
        .alert("Delete Registration", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                registrationToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let registration = registrationToDelete {
                    deleteRegistration(registration: registration)
                }
                registrationToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this registration? This action cannot be undone.")
        }
        .sheet(item: $selectedRegistration) { registration in
            NavigationStack {
                FileViewer(
                    fileUrl: registration.fileUrl,
                    fileType: registration.fileType == .pdf ? .pdf : .image,
                    bucketName: "drone-registrations"
                )
            }
            .onAppear {
                print("DEBUG DroneRegistrationView: Sheet appeared for registration: \(registration.id)")
                print("DEBUG DroneRegistrationView: File URL: \(registration.fileUrl)")
                print("DEBUG DroneRegistrationView: File Type: \(registration.fileType)")
            }
        }
        .sheet(item: $registrationToEdit) { registration in
            NavigationStack {
                EditDroneRegistrationView(
                    registration: registration,
                    registrationService: registrationService,
                    onSave: {
                        showEditSheet = false
                        registrationToEdit = nil
                        Task {
                            await loadRegistrations()
                        }
                    },
                    onCancel: {
                        showEditSheet = false
                        registrationToEdit = nil
                    }
                )
            }
        }
        .task {
            if isAuthenticated {
                await loadRegistrations()
            }
        }
    }
    
    private func authenticateWithFaceID() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Please authenticate to access drone registration information."
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        isAuthenticated = true
                        showAuthPrompt = false
                        Task {
                            await loadRegistrations()
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
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Please authenticate to access drone registration information.") { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        isAuthenticated = true
                        showAuthPrompt = false
                        Task {
                            await loadRegistrations()
                        }
                    } else {
                        errorMessage = authenticationError?.localizedDescription ?? "Authentication failed"
                        showError = true
                    }
                }
            }
        }
    }
    
    private func loadRegistrations() async {
        guard let currentUser = authService.currentUser else { return }
        try? await registrationService.fetchRegistrations(pilotId: currentUser.id)
    }
    
    private func uploadImage(_ image: UIImage) {
        guard isAuthenticated,
              let currentUser = authService.currentUser,
              let imageData = registrationService.compressImage(image) else {
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
                // Generate unique filename to avoid conflicts
                let originalFileName = url.lastPathComponent
                let fileExtension = url.pathExtension
                let fileNameWithoutExtension = (originalFileName as NSString).deletingPathExtension
                let uniqueFileName = "\(UUID().uuidString)_\(fileNameWithoutExtension).\(fileExtension)"
                _ = try await registrationService.uploadRegistration(
                    pilotId: userId,
                    data: data,
                    fileName: uniqueFileName,
                    fileType: .pdf
                )
                await loadRegistrations()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func deleteRegistration(registration: DroneRegistration) {
        guard isAuthenticated else {
            errorMessage = "Please authenticate first"
            showError = true
            return
        }
        
        Task {
            do {
                try await registrationService.deleteRegistration(registration: registration)
                await loadRegistrations()
            } catch {
                errorMessage = "Failed to delete registration: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

// MARK: - Drone Registration Row

struct DroneRegistrationRow: View {
    let registration: DroneRegistration
    let onTap: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // File icon
                Image(systemName: registration.fileType == .pdf ? "doc.fill" : "photo.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 50)
                
                // File info
                VStack(alignment: .leading, spacing: 4) {
                    Text(registration.fileType == .pdf ? "PDF Document" : "Image")
                        .font(.headline)
                    
                    Text("Uploaded \(registration.uploadedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    // View button
                    Button(action: {
                        print("DEBUG DroneRegistrationRow: View button tapped")
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
                        print("DEBUG DroneRegistrationRow: Delete button tapped")
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
            
            // Always display extracted OCR information section
            VStack(alignment: .leading, spacing: 6) {
                Divider()
                
                HStack {
                    Text("Extracted Information")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    // Edit button
                    Button(action: {
                        print("DEBUG DroneRegistrationRow: Edit button tapped")
                        onEdit()
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            RegistrationInfoRow(
                                label: "Owner",
                                value: registration.registeredOwner ?? "",
                                isEmpty: registration.registeredOwner == nil
                            )
                            RegistrationInfoRow(
                                label: "Manufacturer",
                                value: registration.manufacturer ?? "",
                                isEmpty: registration.manufacturer == nil
                            )
                            RegistrationInfoRow(
                                label: "Model",
                                value: registration.model ?? "",
                                isEmpty: registration.model == nil
                            )
                            RegistrationInfoRow(
                                label: "Serial Number",
                                value: registration.serialNumber ?? "",
                                isEmpty: registration.serialNumber == nil
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            RegistrationInfoRow(
                                label: "Registration",
                                value: registration.registrationNumber ?? "",
                                isEmpty: registration.registrationNumber == nil
                            )
                            RegistrationInfoRow(
                                label: "Issued",
                                value: registration.issued ?? "",
                                isEmpty: registration.issued == nil
                            )
                            RegistrationInfoRow(
                                label: "Expires",
                                value: registration.expires ?? "",
                                isEmpty: registration.expires == nil
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.leading, 62) // Align with content above
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Registration Info Row Component

struct RegistrationInfoRow: View {
    let label: String
    let value: String
    var isEmpty: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if isEmpty {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                }
            }
            if value.isEmpty {
                Text("—")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Edit Drone Registration View

struct EditDroneRegistrationView: View {
    let registration: DroneRegistration
    @ObservedObject var registrationService: DroneRegistrationService
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var registeredOwner: String
    @State private var manufacturer: String
    @State private var model: String
    @State private var serialNumber: String
    @State private var registrationNumber: String
    @State private var issued: Date
    @State private var expires: Date
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showIssuedPicker = false
    @State private var showExpiresPicker = false
    
    // Date formatter for MM/dd/yyyy format
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }()
    
    init(registration: DroneRegistration, registrationService: DroneRegistrationService, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.registration = registration
        self.registrationService = registrationService
        self.onSave = onSave
        self.onCancel = onCancel
        
        _registeredOwner = State(initialValue: registration.registeredOwner ?? "")
        _manufacturer = State(initialValue: registration.manufacturer ?? "")
        _model = State(initialValue: registration.model ?? "")
        _serialNumber = State(initialValue: registration.serialNumber ?? "")
        _registrationNumber = State(initialValue: registration.registrationNumber ?? "")
        
        // Parse the date strings to Date objects
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"
        
        let parsedIssued: Date
        if let issuedString = registration.issued, !issuedString.isEmpty {
            parsedIssued = dateFormatter.date(from: issuedString) ?? Date()
        } else {
            parsedIssued = Date()
        }
        _issued = State(initialValue: parsedIssued)
        
        let parsedExpires: Date
        if let expiresString = registration.expires, !expiresString.isEmpty {
            parsedExpires = dateFormatter.date(from: expiresString) ?? Date()
        } else {
            parsedExpires = Date()
        }
        _expires = State(initialValue: parsedExpires)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Drone Registration Information")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Owner")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter owner name", text: $registeredOwner)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Manufacturer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter manufacturer", text: $manufacturer)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter model", text: $model)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Serial Number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter serial number", text: $serialNumber)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Registration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter registration number", text: $registrationNumber)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Issued")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if showIssuedPicker {
                        VStack(alignment: .leading, spacing: 8) {
                            DatePicker(
                                "",
                                selection: $issued,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.wheel)
                            
                            Button(action: {
                                withAnimation {
                                    showIssuedPicker = false
                                }
                            }) {
                                Text("Done")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                        }
                    } else {
                        HStack {
                            Text(dateFormatter.string(from: issued))
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    showIssuedPicker = true
                                }
                            }) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expires")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if showExpiresPicker {
                        VStack(alignment: .leading, spacing: 8) {
                            DatePicker(
                                "",
                                selection: $expires,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.wheel)
                            
                            Button(action: {
                                withAnimation {
                                    showExpiresPicker = false
                                }
                            }) {
                                Text("Done")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                        }
                    } else {
                        HStack {
                            Text(dateFormatter.string(from: expires))
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    showExpiresPicker = true
                                }
                            }) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Edit Registration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    onCancel()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveChanges()
                }
                .disabled(isSaving)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }
    
    private func saveChanges() {
        isSaving = true
        Task {
            do {
                // Format dates as MM/dd/yyyy strings
                let issuedString = dateFormatter.string(from: issued)
                let expiresString = dateFormatter.string(from: expires)
                
                try await registrationService.updateRegistrationOCRFields(
                    registrationId: registration.id,
                    registeredOwner: registeredOwner.isEmpty ? nil : registeredOwner,
                    manufacturer: manufacturer.isEmpty ? nil : manufacturer,
                    model: model.isEmpty ? nil : model,
                    serialNumber: serialNumber.isEmpty ? nil : serialNumber,
                    registrationNumber: registrationNumber.isEmpty ? nil : registrationNumber,
                    issued: issuedString,
                    expires: expiresString
                )
                await MainActor.run {
                    isSaving = false
                    onSave()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - View Extension for Placeholder

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
            ZStack(alignment: alignment) {
                placeholder().opacity(shouldShow ? 1 : 0)
                self
            }
        }
}

