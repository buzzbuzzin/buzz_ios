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
    @State private var isLoading: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var showUploadOptions: Bool = false
    @State private var selectedImage: UIImage?
    @State private var selectedDocumentURL: URL?
    @State private var currentUploadType: BeaconTrainingType?
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
                            isCompleted: completedTraining.contains(.cpr),
                            onUploadTap: {
                                currentUploadType = .cpr
                                showUploadOptions = true
                            },
                            isLoading: isLoading && currentUploadType == .cpr
                        )
                        
                    case .firefightingTraining:
                        TrainingStepView(
                            trainingType: .firefighting,
                            isCompleted: completedTraining.contains(.firefighting),
                            onUploadTap: {
                                currentUploadType = .firefighting
                                showUploadOptions = true
                            },
                            isLoading: isLoading && currentUploadType == .firefighting
                        )
                        
                    case .certTraining:
                        TrainingStepView(
                            trainingType: .cert,
                            isCompleted: completedTraining.contains(.cert),
                            onUploadTap: {
                                currentUploadType = .cert
                                showUploadOptions = true
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
        .onChange(of: selectedImage) { newImage in
            if let image = newImage, let uploadType = currentUploadType {
                Task {
                    await uploadCertificate(image: image, type: uploadType)
                }
            }
        }
        .onChange(of: selectedDocumentURL) { newURL in
            if let url = newURL, let uploadType = currentUploadType {
                Task {
                    await uploadCertificate(url: url, type: uploadType)
                }
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
                completedTraining = Set(progress.map { $0.trainingType })
                
                // Set current step based on progress
                if completedTraining.contains(.cpr) && completedTraining.contains(.firefighting) && completedTraining.contains(.cert) {
                    currentStep = .badgeAward
                } else if completedTraining.contains(.cpr) && completedTraining.contains(.firefighting) {
                    currentStep = .certTraining
                } else if completedTraining.contains(.cpr) {
                    currentStep = .firefightingTraining
                }
            }
        } catch {
            print("Error loading progress: \(error)")
        }
    }
    
    private func uploadCertificate(image: UIImage, type: BeaconTrainingType) async {
        guard let userId = authService.currentUser?.id else { return }
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to process image"
            showError = true
            return
        }
        
        isLoading = true
        
        do {
            _ = try await beaconService.uploadTrainingCertificate(
                userId: userId,
                trainingType: type,
                data: imageData,
                fileName: "\(type.rawValue)_\(Date().timeIntervalSince1970).jpg",
                isPDF: false
            )
            
            await MainActor.run {
                completedTraining.insert(type)
                selectedImage = nil
                currentUploadType = nil
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
    
    private func uploadCertificate(url: URL, type: BeaconTrainingType) async {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        
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
            
            _ = try await beaconService.uploadTrainingCertificate(
                userId: userId,
                trainingType: type,
                data: data,
                fileName: fileName,
                isPDF: isPDF
            )
            
            await MainActor.run {
                completedTraining.insert(type)
                selectedDocumentURL = nil
                currentUploadType = nil
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
    let isCompleted: Bool
    let onUploadTap: () -> Void
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
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Certificate Uploaded")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
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

