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
    @State private var licenseToEdit: PilotLicense?
    @State private var showEditSheet = false
    @State private var showLicenseTypeSelection = false
    @State private var selectedLicenseType: LicenseType?
    @State private var customLicenseType: String = ""
    @State private var pendingUploadAction: (() -> Void)?
    
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
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 0) {
                                // Group licenses by category
                                let groupedLicenses = groupLicensesByCategory()
                                
                                // Drone Pilot License Section
                                if !groupedLicenses[.dronePilot]!.isEmpty {
                                    LicenseCategorySection(
                                        category: .dronePilot,
                                        licenses: groupedLicenses[.dronePilot]!,
                                        onView: { license in
                                            print("DEBUG LicenseView: Eye icon tapped")
                                            print("DEBUG LicenseView: License ID: \(license.id)")
                                            print("DEBUG LicenseView: License URL: \(license.fileUrl)")
                                            print("DEBUG LicenseView: License type: \(license.fileType)")
                                            Task { @MainActor in
                                                self.selectedLicense = license
                                                print("DEBUG LicenseView: selectedLicense set to: \(self.selectedLicense?.id.uuidString ?? "nil")")
                                            }
                                        },
                                        onDelete: { license in
                                            licenseToDelete = license
                                            showDeleteConfirmation = true
                                        },
                                        onEdit: { license in
                                            licenseToEdit = license
                                            showEditSheet = true
                                        }
                                    )
                                }
                                
                                // Radio Operator Permit Section
                                if !groupedLicenses[.radioOperator]!.isEmpty {
                                    LicenseCategorySection(
                                        category: .radioOperator,
                                        licenses: groupedLicenses[.radioOperator]!,
                                        onView: { license in
                                            Task { @MainActor in
                                                self.selectedLicense = license
                                            }
                                        },
                                        onDelete: { license in
                                            licenseToDelete = license
                                            showDeleteConfirmation = true
                                        },
                                        onEdit: { license in
                                            licenseToEdit = license
                                            showEditSheet = true
                                        }
                                    )
                                }
                                
                                // Flight Reviewer Section
                                if !groupedLicenses[.flightReviewer]!.isEmpty {
                                    LicenseCategorySection(
                                        category: .flightReviewer,
                                        licenses: groupedLicenses[.flightReviewer]!,
                                        onView: { license in
                                            Task { @MainActor in
                                                self.selectedLicense = license
                                            }
                                        },
                                        onDelete: { license in
                                            licenseToDelete = license
                                            showDeleteConfirmation = true
                                        },
                                        onEdit: { license in
                                            licenseToEdit = license
                                            showEditSheet = true
                                        }
                                    )
                                }
                                
                                // Other Section
                                if !groupedLicenses[.other]!.isEmpty {
                                    LicenseCategorySection(
                                        category: .other,
                                        licenses: groupedLicenses[.other]!,
                                        onView: { license in
                                            Task { @MainActor in
                                                self.selectedLicense = license
                                            }
                                        },
                                        onDelete: { license in
                                            licenseToDelete = license
                                            showDeleteConfirmation = true
                                        },
                                        onEdit: { license in
                                            licenseToEdit = license
                                            showEditSheet = true
                                        }
                                    )
                                }
                            }
                            .padding(.bottom, 16)
                        }
                        .refreshable {
                            await loadLicenses()
                        }
                        
                        // Notes section in gray background
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
                                
                                Text("3. Per FAA regulation, in order to fly your drone under the FAA's Small UAS Rule (Part 107), you must obtain a Remote Pilot Certificate from the FAA. This certificate demonstrates that you understand the regulations, operating requirements, and procedures for safely flying drones. Certificate holders must complete an online recurrent training every 24 calendar months to maintain aeronautical knowledge recency.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Link("Learn more about becoming a drone pilot", destination: URL(string: "https://www.faa.gov/uas/commercial_operators/become_a_drone_pilot")!)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                    }
                }
            }
        }
        .navigationTitle("Licenses")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isAuthenticated {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showUploadOptions = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add License")
                }
            }
        }
        .confirmationDialog("Upload License", isPresented: $showUploadOptions, titleVisibility: .visible) {
            Button("Take Photo") {
                guard isAuthenticated else {
                    errorMessage = "Please authenticate first"
                    showError = true
                    return
                }
                pendingUploadAction = {
                    imageSourceType = .camera
                    showImagePicker = true
                }
                showLicenseTypeSelection = true
            }
            Button("Choose from Photo Library") {
                guard isAuthenticated else {
                    errorMessage = "Please authenticate first"
                    showError = true
                    return
                }
                pendingUploadAction = {
                    imageSourceType = .photoLibrary
                    showImagePicker = true
                }
                showLicenseTypeSelection = true
            }
            Button("Choose File") {
                guard isAuthenticated else {
                    errorMessage = "Please authenticate first"
                    showError = true
                    return
                }
                pendingUploadAction = {
                    showDocumentPicker = true
                }
                showLicenseTypeSelection = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showLicenseTypeSelection) {
            LicenseTypeSelectionView(
                selectedType: $selectedLicenseType,
                customType: $customLicenseType,
                onConfirm: {
                    showLicenseTypeSelection = false
                    pendingUploadAction?()
                    pendingUploadAction = nil
                },
                onCancel: {
                    showLicenseTypeSelection = false
                    selectedLicenseType = nil
                    customLicenseType = ""
                    pendingUploadAction = nil
                }
            )
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
        .sheet(item: $licenseToEdit) { license in
            NavigationStack {
                EditPilotLicenseView(
                    license: license,
                    licenseService: licenseService,
                    onSave: {
                        showEditSheet = false
                        licenseToEdit = nil
                        Task {
                            await loadLicenses()
                        }
                    },
                    onCancel: {
                        showEditSheet = false
                        licenseToEdit = nil
                    }
                )
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
        let licenseTypeString = getLicenseTypeString()
        
        Task {
            do {
                let fileName = "\(UUID().uuidString).jpg"
                _ = try await licenseService.uploadLicense(
                    pilotId: userId,
                    data: imageData,
                    fileName: fileName,
                    fileType: .image,
                    licenseType: licenseTypeString
                )
                // Reset license type selection
                selectedLicenseType = nil
                customLicenseType = ""
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
                // Generate unique filename to allow multiple uploads of same file
                let originalFileName = url.lastPathComponent
                let fileExtension = (originalFileName as NSString).pathExtension
                let uniqueFileName: String
                if fileExtension.isEmpty {
                    // If no extension, just append UUID
                    uniqueFileName = "\(originalFileName)_\(UUID().uuidString)"
                } else {
                    let fileNameWithoutExtension = (originalFileName as NSString).deletingPathExtension
                    uniqueFileName = "\(fileNameWithoutExtension)_\(UUID().uuidString).\(fileExtension)"
                }
                let licenseTypeString = getLicenseTypeString()
                _ = try await licenseService.uploadLicense(
                    pilotId: userId,
                    data: data,
                    fileName: uniqueFileName,
                    fileType: .pdf,
                    licenseType: licenseTypeString
                )
                // Reset license type selection
                selectedLicenseType = nil
                customLicenseType = ""
                await loadLicenses()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func getLicenseTypeString() -> String? {
        if let selected = selectedLicenseType {
            if selected == .custom {
                return customLicenseType.isEmpty ? nil : customLicenseType
            }
            return selected.rawValue
        }
        return nil
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
    
    private func groupLicensesByCategory() -> [LicenseCategory: [PilotLicense]] {
        var grouped: [LicenseCategory: [PilotLicense]] = [
            .dronePilot: [],
            .radioOperator: [],
            .flightReviewer: [],
            .other: []
        ]
        
        for license in licenseService.licenses {
            // Determine category based on license type
            let category: LicenseCategory
            if let licenseTypeString = license.licenseType,
               let licenseType = LicenseType(rawValue: licenseTypeString) {
                category = licenseType.category
            } else {
                // Default to other if we can't determine the category
                category = .other
            }
            grouped[category]?.append(license)
        }
        
        return grouped
    }
}

// MARK: - License Category Section

struct LicenseCategorySection: View {
    let category: LicenseCategory
    let licenses: [PilotLicense]
    let onView: (PilotLicense) -> Void
    let onDelete: (PilotLicense) -> Void
    let onEdit: (PilotLicense) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            Text(category.title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
                .padding(.top, 20)
            
            // License Cards
            VStack(spacing: 12) {
                ForEach(licenses) { license in
                    LicenseCard(
                        license: license,
                        onView: { onView(license) },
                        onDelete: { onDelete(license) },
                        onEdit: { onEdit(license) }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - License Card

struct LicenseCard: View {
    let license: PilotLicense
    let onView: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    private func isRPACertificate(_ license: PilotLicense) -> Bool {
        return license.licenseType?.contains("RPA Pilot Certificate") ?? false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Section
            HStack(spacing: 12) {
                // File icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: license.fileType == .pdf ? "doc.fill" : "photo.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                // File info
                VStack(alignment: .leading, spacing: 4) {
                    Text(license.licenseType ?? (license.fileType == .pdf ? "PDF Document" : "Image"))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Uploaded \(license.uploadedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    // View button
                    Button(action: {
                        print("DEBUG LicenseCard: View button tapped")
                        onView()
                    }) {
                        Image(systemName: "eye.fill")
                            .font(.body)
                            .foregroundColor(.blue)
                            .frame(width: 36, height: 36)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Delete button
                    Button(action: {
                        print("DEBUG LicenseCard: Delete button tapped")
                        onDelete()
                    }) {
                        Image(systemName: "trash.fill")
                            .font(.body)
                            .foregroundColor(.red)
                            .frame(width: 36, height: 36)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(16)
            
            // Divider
            Divider()
                .padding(.horizontal, 16)
            
            // OCR Information Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Extracted Information")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    // Edit button
                    Button(action: {
                        print("DEBUG LicenseCard: Edit button tapped")
                        onEdit()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .medium))
                            Text("Edit")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // OCR Fields Grid
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 16) {
                        LicenseInfoRow(
                            label: "Name",
                            value: license.name ?? "",
                            isEmpty: license.name == nil
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LicenseInfoRow(
                            label: isRPACertificate(license) ? "Date" : "Completion Date",
                            value: license.completionDate ?? "",
                            isEmpty: license.completionDate == nil
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    HStack(alignment: .top, spacing: 16) {
                        LicenseInfoRow(
                            label: isRPACertificate(license) ? "TC Account" : "Course",
                            value: license.courseCompleted ?? "",
                            isEmpty: license.courseCompleted == nil
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LicenseInfoRow(
                            label: "Certificate",
                            value: license.certificateNumber ?? "",
                            isEmpty: license.certificateNumber == nil
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

// MARK: - License Info Row Component

struct LicenseInfoRow: View {
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

// MARK: - Edit Pilot License View

struct EditPilotLicenseView: View {
    let license: PilotLicense
    @ObservedObject var licenseService: LicenseUploadService
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var name: String
    @State private var courseCompleted: String
    @State private var completionDate: Date
    @State private var certificateNumber: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showCompletionDatePicker = false
    
    // Date formatters
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
    
    private let dateParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        // Also try other formats
        return formatter
    }()
    
    private var isRPACertificate: Bool {
        license.licenseType?.contains("RPA Pilot Certificate") ?? false
    }
    
    init(license: PilotLicense, licenseService: LicenseUploadService, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.license = license
        self.licenseService = licenseService
        self.onSave = onSave
        self.onCancel = onCancel
        
        _name = State(initialValue: license.name ?? "")
        _courseCompleted = State(initialValue: license.courseCompleted ?? "")
        
        // Parse the date string to Date
        let parsedDate: Date
        if let dateString = license.completionDate, !dateString.isEmpty {
            // Try multiple date formats
            let formatters: [DateFormatter] = [
                {
                    let f = DateFormatter()
                    f.dateStyle = .long
                    f.timeStyle = .none
                    return f
                }(),
                {
                    let f = DateFormatter()
                    f.dateFormat = "MM/dd/yyyy"
                    return f
                }(),
                {
                    let f = DateFormatter()
                    f.dateFormat = "MMMM d, yyyy"
                    return f
                }(),
                {
                    let f = DateFormatter()
                    f.dateFormat = "MMM d, yyyy"
                    return f
                }()
            ]
            
            var foundDate: Date?
            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    foundDate = date
                    break
                }
            }
            parsedDate = foundDate ?? Date()
        } else {
            parsedDate = Date()
        }
        _completionDate = State(initialValue: parsedDate)
        
        _certificateNumber = State(initialValue: license.certificateNumber ?? "")
    }
    
    var body: some View {
        Form {
            Section(header: Text("Pilot License Information")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter name", text: $name)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isRPACertificate ? "TC Account" : "Course Completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField(isRPACertificate ? "Enter TC Account" : "Enter course name", text: $courseCompleted)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isRPACertificate ? "Date" : "Completion Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if showCompletionDatePicker {
                        VStack(alignment: .leading, spacing: 8) {
                            DatePicker(
                                "",
                                selection: $completionDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.wheel)
                            
                            Button(action: {
                                withAnimation {
                                    showCompletionDatePicker = false
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
                            Text(dateFormatter.string(from: completionDate))
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    showCompletionDatePicker = true
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
                    Text("Certificate Number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter certificate number", text: $certificateNumber)
                        .placeholder(when: certificateNumber.isEmpty) {
                            Text(isRPACertificate ? "e.g., PC2020952034" : "e.g., 1595266-20241102-00677")
                                .foregroundColor(.secondary)
                        }
                }
            }
        }
        .navigationTitle("Edit License")
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
                // Format the date as a string
                let dateString = dateFormatter.string(from: completionDate)
                
                try await licenseService.updateLicenseOCRFields(
                    licenseId: license.id,
                    name: name.isEmpty ? nil : name,
                    courseCompleted: courseCompleted.isEmpty ? nil : courseCompleted,
                    completionDate: dateString,
                    certificateNumber: certificateNumber.isEmpty ? nil : certificateNumber
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

// MARK: - License Type Selection View

struct LicenseTypeSelectionView: View {
    @Binding var selectedType: LicenseType?
    @Binding var customType: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var showCustomTextField = false
    
    // Group license types by category
    private var dronePilotLicenses: [LicenseType] {
        LicenseType.allCases.filter { $0.category == .dronePilot }
    }
    
    private var radioOperatorLicenses: [LicenseType] {
        LicenseType.allCases.filter { $0.category == .radioOperator }
    }
    
    private var flightReviewerLicenses: [LicenseType] {
        LicenseType.allCases.filter { $0.category == .flightReviewer }
    }
    
    private var otherLicenses: [LicenseType] {
        LicenseType.allCases.filter { $0.category == .other }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Drone Pilot License Section
                Section(header: Text("Drone Pilot License")) {
                    ForEach(dronePilotLicenses, id: \.self) { type in
                        Button(action: {
                            selectedType = type
                            showCustomTextField = false
                        }) {
                            HStack {
                                Text(type.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // Radio Operator Permit Type Section
                Section(header: Text("Radio Operator Permit Type")) {
                    ForEach(radioOperatorLicenses, id: \.self) { type in
                        Button(action: {
                            selectedType = type
                            showCustomTextField = false
                        }) {
                            HStack {
                                Text(type.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // Flight Reviewer Section
                Section(header: Text("Flight Reviewer")) {
                    ForEach(flightReviewerLicenses, id: \.self) { type in
                        Button(action: {
                            selectedType = type
                            showCustomTextField = false
                        }) {
                            HStack {
                                Text(type.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // Other Section
                Section(header: Text("Other")) {
                    ForEach(otherLicenses, id: \.self) { type in
                        Button(action: {
                            selectedType = type
                            if type == .custom {
                                showCustomTextField = true
                            } else {
                                showCustomTextField = false
                            }
                        }) {
                            HStack {
                                Text(type.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                if showCustomTextField && selectedType == .custom {
                    Section(header: Text("Enter Your License Type")) {
                        TextField("Enter license type", text: $customType)
                            .textInputAutocapitalization(.words)
                    }
                }
            }
            .navigationTitle("License Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Continue") {
                        onConfirm()
                    }
                    .disabled(selectedType == nil || (selectedType == .custom && customType.isEmpty))
                }
            }
        }
    }
}

