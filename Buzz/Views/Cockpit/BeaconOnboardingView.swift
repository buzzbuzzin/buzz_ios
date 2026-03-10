//
//  BeaconOnboardingView.swift
//  Buzz
//
//  Created by Xinyu Fang on 12/31/24.
//

import SwiftUI
import PhotosUI
import Auth
import UniformTypeIdentifiers

struct BeaconOnboardingView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var beaconService = BeaconService()
    @State private var currentStep: BeaconOnboardingStep = .cprTraining
    @State private var completedTraining: Set<BeaconTrainingType> = []
    @State private var trainingRecords: [BeaconTrainingType: BeaconTrainingProgress] = [:]
    @State private var isLoading: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var showUploadOptions: Bool = false
    @State private var showExpirationSheet: Bool = false
    @State private var selectedImage: UIImage?
    @State private var selectedDocumentURL: URL?
    @State private var currentUploadType: BeaconTrainingType?
    @State private var pendingUpload: PendingCertificateUpload?
    @State private var selectedExpirationDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showConfetti: Bool = false
    
    var onComplete: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text("Emergency Response Onboarding")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Complete the required training to become a Beacon volunteer")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Progress Indicator
                HStack(spacing: 0) {
                    ForEach(BeaconOnboardingStep.allCases, id: \.rawValue) { step in
                        StepIndicator(
                            step: step,
                            isCompleted: isStepCompleted(step),
                            isCurrent: step == currentStep
                        )
                        
                        if step != BeaconOnboardingStep.allCases.last {
                            Rectangle()
                                .fill(isStepCompleted(step) ? Color.green : Color.gray.opacity(0.3))
                                .frame(height: 2)
                        }
                    }
                }
                .padding(.horizontal, 32)
                
                // Current Step Content
                VStack(spacing: 20) {
                    switch currentStep {
                    case .cprTraining:
                        TrainingStepView(
                            trainingType: .cpr,
                            trainingRecord: trainingRecords[.cpr],
                            isCompleted: completedTraining.contains(.cpr),
                            onUploadTap: {
                                currentUploadType = .cpr
                                showUploadOptions = true
                            },
                            onAddExpirationTap: {
                                beginExpirationEntry(for: .cpr)
                            },
                            isLoading: isLoading && currentUploadType == .cpr
                        )
                        
                    case .firefightingTraining:
                        TrainingStepView(
                            trainingType: .firefighting,
                            trainingRecord: trainingRecords[.firefighting],
                            isCompleted: completedTraining.contains(.firefighting),
                            onUploadTap: {
                                currentUploadType = .firefighting
                                showUploadOptions = true
                            },
                            onAddExpirationTap: {
                                beginExpirationEntry(for: .firefighting)
                            },
                            isLoading: isLoading && currentUploadType == .firefighting
                        )
                        
                    case .certTraining:
                        TrainingStepView(
                            trainingType: .cert,
                            trainingRecord: trainingRecords[.cert],
                            isCompleted: completedTraining.contains(.cert),
                            onUploadTap: {
                                currentUploadType = .cert
                                showUploadOptions = true
                            },
                            onAddExpirationTap: {
                                beginExpirationEntry(for: .cert)
                            },
                            isLoading: isLoading && currentUploadType == .cert
                        )
                        
                    case .badgeAward:
                        BadgeAwardView(showConfetti: $showConfetti)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Navigation Buttons
                VStack(spacing: 12) {
                    if currentStep == .badgeAward {
                        Button(action: {
                            Task {
                                await completeOnboarding()
                            }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "checkmark.seal.fill")
                                    Text("Activate Beacon Volunteer Status")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .disabled(isLoading)
                    } else {
                        Button(action: {
                            moveToNextStep()
                        }) {
                            HStack {
                                Text("Continue")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canProceed ? Color.blue : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!canProceed)
                    }
                    
                    if currentStep != .cprTraining {
                        Button(action: {
                            moveToPreviousStep()
                        }) {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("Back")
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Onboarding")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    onComplete()
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
            Button("Cancel", role: .cancel) {
                currentUploadType = nil
            }
        }
        .sheet(isPresented: $showImagePicker) {
            BeaconImagePicker(image: $selectedImage)
        }
        .sheet(isPresented: $showDocumentPicker) {
            BeaconDocumentPicker { url in
                selectedDocumentURL = url
            }
        }
        .sheet(isPresented: $showExpirationSheet) {
            expirationSheet
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage, let uploadType = currentUploadType {
                prepareUpload(image: image, type: uploadType)
            }
        }
        .onChange(of: selectedDocumentURL) { _, newURL in
            if let url = newURL, let uploadType = currentUploadType {
                prepareUpload(url: url, type: uploadType)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            await loadExistingProgress()
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case .cprTraining:
            return completedTraining.contains(.cpr)
        case .firefightingTraining:
            return completedTraining.contains(.firefighting)
        case .certTraining:
            return completedTraining.contains(.cert)
        case .badgeAward:
            return true
        }
    }

    private var expirationSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text(expirationSheetDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                DatePicker(
                    "Expiration Date",
                    selection: $selectedExpirationDate,
                    in: Date()...,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)

                Spacer()

                Button(action: {
                    Task {
                        await commitExpirationFlow()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(pendingUpload == nil ? "Save Expiration Date" : "Upload Certificate")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
            }
            .padding()
            .navigationTitle("Document Expiration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        resetPendingUploadState()
                    }
                }
            }
        }
    }

    private var expirationSheetDescription: String {
        if pendingUpload == nil {
            return "Tell Buzz when this qualification expires so existing Beacon volunteers can stay current without re-uploading a file."
        }

        return "After uploading the certificate, Buzz will use this date to determine when the qualification expires and when a renewed certification is required."
    }
    
    private func isStepCompleted(_ step: BeaconOnboardingStep) -> Bool {
        switch step {
        case .cprTraining:
            return completedTraining.contains(.cpr)
        case .firefightingTraining:
            return completedTraining.contains(.firefighting)
        case .certTraining:
            return completedTraining.contains(.cert)
        case .badgeAward:
            return false // Badge is awarded at the end
        }
    }
    
    private func moveToNextStep() {
        withAnimation {
            switch currentStep {
            case .cprTraining:
                currentStep = .firefightingTraining
            case .firefightingTraining:
                currentStep = .certTraining
            case .certTraining:
                currentStep = .badgeAward
                showConfetti = true
            case .badgeAward:
                break
            }
        }
    }
    
    private func moveToPreviousStep() {
        withAnimation {
            switch currentStep {
            case .cprTraining:
                break
            case .firefightingTraining:
                currentStep = .cprTraining
            case .certTraining:
                currentStep = .firefightingTraining
            case .badgeAward:
                currentStep = .certTraining
            }
        }
    }
    
    private func loadExistingProgress() async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            let progress = try await beaconService.getTrainingProgress(userId: userId)
            await MainActor.run {
                refreshTrainingState(with: progress)
            }
        } catch {
            print("Error loading progress: \(error)")
        }
    }
    
    private func prepareUpload(image: UIImage, type: BeaconTrainingType) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to process image"
            showError = true
            return
        }

        pendingUpload = PendingCertificateUpload(
            data: imageData,
            fileName: "\(type.rawValue)_\(Date().timeIntervalSince1970).jpg",
            isPDF: false
        )
        selectedImage = nil
        selectedExpirationDate = defaultExpirationDate(for: type)
        showExpirationSheet = true
    }
    
    private func prepareUpload(url: URL, type: BeaconTrainingType) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "FileAccessError", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Unable to access the selected file"])
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            let data = try Data(contentsOf: url)
            let fileName = url.lastPathComponent
            pendingUpload = PendingCertificateUpload(
                data: data,
                fileName: fileName,
                isPDF: fileName.lowercased().hasSuffix(".pdf")
            )
            selectedDocumentURL = nil
            selectedExpirationDate = defaultExpirationDate(for: type)
            showExpirationSheet = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func beginExpirationEntry(for type: BeaconTrainingType) {
        currentUploadType = type
        pendingUpload = nil
        selectedExpirationDate = defaultExpirationDate(for: type)
        showExpirationSheet = true
    }

    private func commitExpirationFlow() async {
        guard let userId = authService.currentUser?.id, let type = currentUploadType else { return }

        isLoading = true

        do {
            let updatedRecord: BeaconTrainingProgress
            if let pendingUpload {
                updatedRecord = try await beaconService.uploadTrainingCertificate(
                    userId: userId,
                    trainingType: type,
                    data: pendingUpload.data,
                    fileName: pendingUpload.fileName,
                    isPDF: pendingUpload.isPDF,
                    expiresAt: selectedExpirationDate
                )
            } else {
                updatedRecord = try await beaconService.updateTrainingExpiration(
                    userId: userId,
                    trainingType: type,
                    expiresAt: selectedExpirationDate
                )
            }

            await MainActor.run {
                refreshTrainingState(with: upserting(updatedRecord, into: Array(trainingRecords.values)))
                resetPendingUploadState()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
    
    private func completeOnboarding() async {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        
        do {
            try await beaconService.enrollAsVolunteer(userId: userId)
            await MainActor.run {
                isLoading = false
                onComplete()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }

    private func refreshTrainingState(with progress: [BeaconTrainingProgress]) {
        trainingRecords = Dictionary(uniqueKeysWithValues: progress.map { ($0.trainingType, $0) })
        completedTraining = Set(progress.filter(\.isCurrent).map(\.trainingType))
        currentStep = nextRequiredStep()
    }

    private func nextRequiredStep() -> BeaconOnboardingStep {
        if !completedTraining.contains(.cpr) {
            return .cprTraining
        }
        if !completedTraining.contains(.firefighting) {
            return .firefightingTraining
        }
        if !completedTraining.contains(.cert) {
            return .certTraining
        }
        return .badgeAward
    }

    private func defaultExpirationDate(for type: BeaconTrainingType) -> Date {
        if let existingExpiration = trainingRecords[type]?.expiresAt, existingExpiration > Date() {
            return existingExpiration
        }
        return Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    }

    private func upserting(_ record: BeaconTrainingProgress, into records: [BeaconTrainingProgress]) -> [BeaconTrainingProgress] {
        var updated = records.filter { $0.trainingType != record.trainingType }
        updated.append(record)
        return updated.sorted { $0.trainingType.rawValue < $1.trainingType.rawValue }
    }

    private func resetPendingUploadState() {
        pendingUpload = nil
        currentUploadType = nil
        selectedImage = nil
        selectedDocumentURL = nil
        showExpirationSheet = false
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let step: BeaconOnboardingStep
    let isCompleted: Bool
    let isCurrent: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 44, height: 44)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: step.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isCurrent ? .white : .gray)
                }
            }
            
            Text(step.title)
                .font(.caption2)
                .foregroundColor(isCurrent ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .frame(width: 70)
        }
    }
    
    private var backgroundColor: Color {
        if isCompleted {
            return .green
        } else if isCurrent {
            return .blue
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

// MARK: - Training Step View

struct TrainingStepView: View {
    let trainingType: BeaconTrainingType
    let trainingRecord: BeaconTrainingProgress?
    let isCompleted: Bool
    let onUploadTap: () -> Void
    let onAddExpirationTap: () -> Void
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Training Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: trainingType == .cpr ? [.red.opacity(0.8), .pink.opacity(0.6)] : [.orange.opacity(0.8), .red.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: trainingType.icon)
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            
            // Training Info
            VStack(spacing: 8) {
                Text(trainingType.displayName)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(trainingType.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Status or Upload Button
            if isCompleted {
                statusBanner(
                    icon: "checkmark.circle.fill",
                    text: "Current until \(formattedExpiration(trainingRecord?.expiresAt))",
                    color: .green
                )
            } else if let trainingRecord, trainingRecord.needsExpiration {
                VStack(spacing: 12) {
                    statusBanner(
                        icon: "calendar.badge.exclamationmark",
                        text: "Expiration date required for this document",
                        color: .orange
                    )

                    Button(action: onAddExpirationTap) {
                        Label("Add Expiration Date", systemImage: "calendar.badge.plus")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                    .disabled(isLoading)

                    Button(action: onUploadTap) {
                        Label("Upload Renewed Certificate", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
                            )
                            .cornerRadius(12)
                    }
                    .disabled(isLoading)
                }
            } else if let trainingRecord, trainingRecord.isExpired {
                VStack(spacing: 12) {
                    statusBanner(
                        icon: "exclamationmark.triangle.fill",
                        text: "Expired on \(formattedExpiration(trainingRecord.expiresAt))",
                        color: .red
                    )

                    Button(action: onUploadTap) {
                        Label("Upload Renewed Certificate", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    .disabled(isLoading)
                }
            } else {
                Button(action: onUploadTap) {
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
                    .background(trainingType == .cpr ? Color.red : Color.orange)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
            }
            
            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Requirements:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.secondary)
                    Text("Complete \(trainingType.displayName) with an accredited provider")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.secondary)
                    Text("Take a photo of your certificate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "3.circle.fill")
                        .foregroundColor(.secondary)
                    Text("Upload it here for verification")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func formattedExpiration(_ date: Date?) -> String {
        guard let date else { return "Unknown date" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func statusBanner(icon: String, text: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .foregroundColor(color)
                .fontWeight(.medium)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.12))
        .cornerRadius(12)
    }
}

private struct PendingCertificateUpload {
    let data: Data
    let fileName: String
    let isPDF: Bool
}

// MARK: - Badge Award View

struct BadgeAwardView: View {
    @Binding var showConfetti: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated Badge
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.yellow.opacity(0.5), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                
                // Badge
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: .orange.opacity(0.5), radius: 20)
                
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    
                    Text("BEACON")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(showConfetti ? 1.0 : 0.5)
            .opacity(showConfetti ? 1.0 : 0.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showConfetti)
            
            // Congratulations Text
            VStack(spacing: 8) {
                Text("Congratulations!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("You've completed all required training")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("You're now ready to become a Beacon volunteer and help your community in emergency situations.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            
            // Benefits
            VStack(alignment: .leading, spacing: 12) {
                Text("As a Beacon Volunteer, you'll:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                BeaconBenefitRow(icon: "bell.badge.fill", text: "Receive emergency notifications for nearby incidents")
                BeaconBenefitRow(icon: "map.fill", text: "Be visible to emergency services in your area")
                BeaconBenefitRow(icon: "star.fill", text: "Earn recognition for your community service")
                BeaconBenefitRow(icon: "shield.fill", text: "Help with search & rescue operations")
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Beacon Benefit Row

struct BeaconBenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 24)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Beacon Image Picker

struct BeaconImagePicker: UIViewControllerRepresentable {
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
        let parent: BeaconImagePicker
        
        init(_ parent: BeaconImagePicker) {
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

// MARK: - Beacon Document Picker

struct BeaconDocumentPicker: UIViewControllerRepresentable {
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
        let parent: BeaconDocumentPicker
        
        init(_ parent: BeaconDocumentPicker) {
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
