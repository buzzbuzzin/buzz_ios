//
//  ExpressPromotionView.swift
//  Buzz
//
//  Created for Express Promotion feature
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Auth

// MARK: - Commander Promotion Card

struct CommanderPromotionCard: View {
    let hasLieutenantPromotion: Bool
    let applications: [ExpressPromotionApplication]
    let hasPassedGroundSchoolTest: Bool
    let isLoadingTestStatus: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 2: Commander Promotion")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            // Check from applications as well in case state hasn't updated
            let hasVerifiedLieutenant = hasLieutenantPromotion || applications.contains { $0.promotionType == .lieutenant && $0.status == .verified }
            let hasCommanderPromotion = applications.contains { $0.promotionType == .commander && $0.status == .verified }
            // Locked if: Step 1 not finished OR (Step 1 finished but test not passed and not promoted)
            let isLocked = !hasVerifiedLieutenant || (!hasPassedGroundSchoolTest && !hasCommanderPromotion)
            
            HStack(spacing: 16) {
                // Lock/Checkmark Icon
                ZStack {
                    Circle()
                        .fill(isLocked ? Color.gray.opacity(0.2) : Color.green.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                            .font(.headline)
                    } else if hasCommanderPromotion {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.headline)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.headline)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Commander")
                            .font(.headline)
                            .foregroundColor(isLocked ? .secondary : .primary)
                        
                        if isLocked {
                            Text("🔒")
                                .font(.caption)
                        }
                    }
                    
//                    Text("Pass the Ground School Test to automatically advance to Commander rank")
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                        .lineLimit(2)
                    
                    if isLoadingTestStatus {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.top, 4)
                    } else if isLocked {
                        if !hasVerifiedLieutenant {
                            Text("Complete Step 1 to unlock")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                        } else {
                            Text("Complete Ground School Test to unlock")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                        }
                    } else if hasCommanderPromotion {
                        Text("✓ Express Promotion: Promoted to Commander")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                            .padding(.top, 4)
                    } else if hasVerifiedLieutenant && hasPassedGroundSchoolTest {
                        Text("Test passed - Promotion in progress...")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                            .padding(.top, 4)
                    }
                }
                
                Spacer()
                
                if isLocked {
                    Image(systemName: "lock.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title3)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding()
            .background(isLocked ? Color(.systemGray5) : Color(.systemGray6))
            .cornerRadius(12)
            .opacity(isLocked ? 0.7 : 1.0)
            .padding(.horizontal)
        }
        .padding(.top)
    }
}

struct ExpressPromotionView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var expressPromotionService = ExpressPromotionService()
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedDocuments: [URL] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    @State private var showUploadActionSheet = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSubmitting = false
    @State private var selectedPromotionType: ExpressPromotionApplication.PromotionType?
    @State private var hasLieutenantPromotion = false
    @State private var hasPassedGroundSchoolTest = false
    @State private var isLoadingTestStatus = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                VStack(spacing: 12) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("Express Promotion")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Fast-track your rank advancement with verified credentials")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                Divider()
                    .padding(.horizontal)
                
                // Information Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("How It Works")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        PromotionInfoRow(
                            icon: "graduationcap.fill",
                            title: "Aviation Degree or PPL",
                            description: "Upload proof of an Aviation degree or Private Pilot License (PPL) to automatically advance to Lieutenant rank.",
                            rank: "Lieutenant"
                        )
                        
                        PromotionInfoRow(
                            icon: "checkmark.seal.fill",
                            title: "Ground School Test",
                            description: "After being promoted to Lieutenant, pass the UAS Ground School Test to automatically advance to Commander rank.",
                            rank: "Commander"
                        )
                    }
                    
                    Text("Step 1: Upload your diploma with Aviation degree or PPL documents (PDF or photos) and we will manually verify it for you.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    Text("Step 2: Pass the Ground School Test after verifying your diploma or PPL.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Current Applications Section
                if !expressPromotionService.applications.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Applications")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        ForEach(expressPromotionService.applications) { application in
                            ApplicationStatusCard(
                                application: application,
                                expressPromotionService: expressPromotionService
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                }
                
                // Step 1: Lieutenant Promotion
                let hasLieutenantApplication = expressPromotionService.applications.contains { $0.promotionType == .lieutenant && $0.status != .rejected }
                
                if !hasLieutenantApplication {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Step 1: Lieutenant Promotion")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        PromotionTypeButton(
                            title: "Lieutenant",
                            subtitle: nil,
                            icon: "graduationcap.fill",
                            isSelected: selectedPromotionType == .lieutenant,
                            action: {
                                selectedPromotionType = .lieutenant
                            }
                        )
                        .padding(.horizontal)
                        
                        // Document Upload Section for Lieutenant
                        if selectedPromotionType == .lieutenant {
                            VStack(alignment: .leading, spacing: 12) {
                                // Choose Files to Upload Button
                                Button(action: {
                                    showUploadActionSheet = true
                                }) {
                                    Text("Choose Files to Upload")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal)
                                
                                // Show selected documents
                                if !selectedDocuments.isEmpty || !selectedImages.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(Array(selectedDocuments.enumerated()), id: \.offset) { index, url in
                                            HStack {
                                                Image(systemName: "doc.fill")
                                                    .foregroundColor(.blue)
                                                Text(url.lastPathComponent)
                                                    .font(.caption)
                                                Spacer()
                                                Button(action: {
                                                    selectedDocuments.remove(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.red)
                                                }
                                            }
                                            .padding(.horizontal)
                                        }
                                        
                                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, _ in
                                            HStack {
                                                Image(systemName: "photo.fill")
                                                    .foregroundColor(.green)
                                                Text("Photo \(index + 1)")
                                                    .font(.caption)
                                                Spacer()
                                                Button(action: {
                                                    selectedImages.remove(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.red)
                                                }
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                    .padding(.top, 8)
                                    .padding(.horizontal)
                                }
                                
                                // Submit Button
                                Button(action: {
                                    submitApplication()
                                }) {
                                    HStack {
                                        if isSubmitting {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Text("Submit Application")
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        (selectedDocuments.isEmpty && selectedImages.isEmpty)
                                            ? Color.gray
                                            : Color.blue
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled((selectedDocuments.isEmpty && selectedImages.isEmpty) || isSubmitting)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }
                        }
                    }
                    .padding(.top)
                }
                
                // Step 2: Commander Promotion (always visible)
                CommanderPromotionCard(
                    hasLieutenantPromotion: hasLieutenantPromotion,
                    applications: expressPromotionService.applications,
                    hasPassedGroundSchoolTest: hasPassedGroundSchoolTest,
                    isLoadingTestStatus: isLoadingTestStatus
                )
            }
            .padding(.bottom)
        }
        .navigationTitle("Express Promotion")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: true
        ) { result in
            handleDocumentPickerResult(result)
        }
        .sheet(isPresented: $showImagePicker) {
            ExpressPromotionImagePicker(images: $selectedImages)
        }
        .confirmationDialog("Select Upload Type", isPresented: $showUploadActionSheet, titleVisibility: .visible) {
            Button("Document") {
                showDocumentPicker = true
            }
            Button("Photo Library") {
                showImagePicker = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await loadApplications()
            await checkStatus()
        }
        .refreshable {
            await loadApplications()
            await checkStatus()
        }
        .onAppear {
            // Refresh status when view appears (one-time check)
            Task {
                await checkStatus()
            }
        }
    }
    
    private func loadApplications() async {
        guard let pilotId = authService.currentUser?.id else { return }
        do {
            try await expressPromotionService.loadApplications(pilotId: pilotId)
        } catch {
            errorMessage = "Failed to load applications"
            showError = true
        }
    }
    
    private func checkStatus() async {
        guard let pilotId = authService.currentUser?.id else { return }
        
        // First reload applications to get latest status
        do {
            try await expressPromotionService.loadApplications(pilotId: pilotId)
        } catch {
            print("Error loading applications: \(error)")
        }
        
        // Check if pilot has Lieutenant promotion (verified) from loaded applications
        let lieutenantPromoted = expressPromotionService.applications.contains { $0.promotionType == .lieutenant && $0.status == .verified }
        hasLieutenantPromotion = lieutenantPromoted
        
        print("🔍 [ExpressPromotionView] Lieutenant promoted: \(lieutenantPromoted)")
        print("🔍 [ExpressPromotionView] Applications count: \(expressPromotionService.applications.count)")
        for app in expressPromotionService.applications {
            print("🔍 [ExpressPromotionView] App: \(app.promotionType.rawValue), Status: \(app.status.rawValue)")
        }
        
        // Check Ground School Test status (only if Lieutenant is verified)
        if lieutenantPromoted {
            isLoadingTestStatus = true
            do {
                let testPassed = try await expressPromotionService.checkGroundSchoolTestStatus(pilotId: pilotId)
                
                // Check if Commander promotion already exists
                let hasCommanderPromotion = expressPromotionService.applications.contains { $0.promotionType == .commander && $0.status == .verified }
                
                print("🔍 [ExpressPromotionView] Test passed: \(testPassed)")
                print("🔍 [ExpressPromotionView] Has Commander promotion: \(hasCommanderPromotion)")
                
                // If test passed and pilot hasn't been promoted yet, auto-promote
                if testPassed && !hasCommanderPromotion {
                    print("🚀 [ExpressPromotionView] Auto-promoting to Commander...")
                    // Automatically promote to Commander
                    try await expressPromotionService.autoPromoteToCommander(pilotId: pilotId)
                    // Reload applications to show updated status
                    try await expressPromotionService.loadApplications(pilotId: pilotId)
                    // Update state again after promotion
                    hasLieutenantPromotion = expressPromotionService.applications.contains { $0.promotionType == .lieutenant && $0.status == .verified }
                }
                
                hasPassedGroundSchoolTest = testPassed
            } catch {
                print("Error checking test status: \(error)")
            }
            isLoadingTestStatus = false
        } else {
            // If Lieutenant not verified, reset test status
            hasPassedGroundSchoolTest = false
            isLoadingTestStatus = false
        }
    }
    
    private func handleDocumentPickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            selectedDocuments.append(contentsOf: urls)
        case .failure(let error):
            errorMessage = "Failed to select documents: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func statusColor(for status: ExpressPromotionApplication.Status) -> Color {
        switch status {
        case .pending, .inReview:
            return .orange
        case .verified:
            return .green
        case .rejected:
            return .red
        }
    }
    
    private func submitApplication() {
        guard let pilotId = authService.currentUser?.id,
              selectedPromotionType == .lieutenant else { return }
        
        isSubmitting = true
        
        Task {
            do {
                // Determine document type
                let documentType: ExpressPromotionApplication.DocumentType = selectedDocuments.isEmpty ? .ppl : .aviationDegree
                
                // Convert documents to Data
                var documents: [Data] = []
                var fileNames: [String] = []
                
                // Add PDFs
                for url in selectedDocuments {
                    if let data = try? Data(contentsOf: url) {
                        documents.append(data)
                        fileNames.append(url.lastPathComponent)
                    }
                }
                
                // Add images
                for image in selectedImages {
                    if let data = image.jpegData(compressionQuality: 0.8) {
                        documents.append(data)
                        fileNames.append("photo_\(UUID().uuidString).jpg")
                    }
                }
                
                guard !documents.isEmpty else {
                    errorMessage = "Please select at least one document"
                    showError = true
                    isSubmitting = false
                    return
                }
                
                try await expressPromotionService.submitApplication(
                    pilotId: pilotId,
                    promotionType: .lieutenant,
                    documentType: documentType,
                    documents: documents,
                    fileNames: fileNames
                )
                
                // Reset form and reload status
                selectedDocuments = []
                selectedImages = []
                selectedPromotionType = nil
                await checkStatus()
                isSubmitting = false
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isSubmitting = false
            }
        }
    }
}

// MARK: - Supporting Views

struct PromotionInfoRow: View {
    let icon: String
    let title: String
    let description: String
    let rank: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(rank)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct PromotionTypeButton: View {
    let title: String
    let subtitle: String?
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with circle background (matching Commander card style)
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                        .font(.headline)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct ApplicationStatusCard: View {
    let application: ExpressPromotionApplication
    @ObservedObject var expressPromotionService: ExpressPromotionService
    @EnvironmentObject var authService: AuthService
    @State private var showWithdrawSheet = false
    
    var body: some View {
        Button(action: {
            // Only show withdraw sheet if status is pending or in_review
            if application.status == .pending || application.status == .inReview {
                showWithdrawSheet = true
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(application.promotionType == .lieutenant ? "Lieutenant" : "Commander")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // Don't show document type after submission - only show submission date/time
                    }
                    
                    Spacer()
                    
                    ExpressPromotionStatusBadge(status: application.status)
                }
                
                if let rejectionReason = application.rejectionReason {
                    Text("Reason: \(rejectionReason)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
                
                // Show submission date/time (always show after submission)
                Text("Submitted: \(application.submittedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .confirmationDialog("Withdraw Application", isPresented: $showWithdrawSheet, titleVisibility: .visible) {
            Button("Withdraw Application", role: .destructive) {
                Task {
                    guard let pilotId = authService.currentUser?.id else { return }
                    do {
                        try await expressPromotionService.withdrawApplication(
                            applicationId: application.id,
                            pilotId: pilotId
                        )
                    } catch {
                        // Handle error - you might want to show an alert here
                        print("Error withdrawing application: \(error)")
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to withdraw your \(application.promotionType.displayName) promotion application?")
        }
    }
}


struct ExpressPromotionStatusBadge: View {
    let status: ExpressPromotionApplication.Status
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .inReview: return .blue
        case .verified: return .green
        case .rejected: return .red
        }
    }
}

struct ExpressPromotionImagePicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 10
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ExpressPromotionImagePicker
        
        init(_ parent: ExpressPromotionImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            for result in results {
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                    if let image = object as? UIImage {
                        DispatchQueue.main.async {
                            self.parent.images.append(image)
                        }
                    }
                }
            }
        }
    }
}

