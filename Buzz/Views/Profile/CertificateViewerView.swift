//
//  CertificateViewerView.swift
//  Buzz
//
//  Created by Xinyu Fang on 1/14/26.
//

import SwiftUI
import PDFKit

/// A view that displays an uploaded certificate for First Aid or Basic Firefighter badges
struct CertificateViewerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var beaconService = BeaconService()
    let userId: UUID
    let badgeType: Badge.BadgeType
    let earnedDate: Date
    
    @State private var certificateURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private var trainingType: BeaconTrainingType? {
        badgeType.beaconTrainingType
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with badge info
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(badgeType.color.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: badgeType.icon)
                            .font(.system(size: 36))
                            .foregroundColor(badgeType.color)
                    }
                    
                    VStack(spacing: 4) {
                        Text(badgeType.displayName)
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text("Earned \(earnedDate, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                
                Divider()
                
                // Certificate content
                if isLoading {
                    Spacer()
                    ProgressView("Loading certificate...")
                    Spacer()
                } else if let errorMessage = errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("Unable to load certificate")
                            .font(.headline)
                        
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Spacer()
                } else if let url = certificateURL {
                    CertificateContentView(url: url)
                } else {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "doc.questionmark.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No certificate found")
                            .font(.headline)
                        
                        Text("The certificate for this badge could not be found.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Spacer()
                }
            }
            .navigationTitle("Certificate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadCertificate()
            }
        }
    }
    
    private func loadCertificate() async {
        guard let trainingType = trainingType else {
            errorMessage = "Invalid badge type"
            isLoading = false
            return
        }
        
        do {
            let progress = try await beaconService.getTrainingProgress(userId: userId)
            
            // Find the training progress for this badge type
            if let trainingProgress = progress.first(where: { $0.trainingType == trainingType }) {
                await MainActor.run {
                    certificateURL = URL(string: trainingProgress.certificateUrl)
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    errorMessage = "Certificate record not found"
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Certificate Content View

private struct CertificateContentView: View {
    let url: URL
    
    @State private var imageData: Data?
    @State private var isLoading = true
    @State private var loadError: String?
    
    private var isPDF: Bool {
        url.pathExtension.lowercased() == "pdf" || url.absoluteString.lowercased().contains(".pdf")
    }
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                }
            } else if let error = loadError {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("Failed to load certificate")
                        .font(.headline)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Open in browser button
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "safari")
                            Text("Open in Browser")
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                }
            } else if let data = imageData {
                if isPDF, let pdfDocument = PDFDocument(data: data) {
                    PDFViewRepresentable(pdfDocument: pdfDocument)
                } else if let uiImage = UIImage(data: data) {
                    ScrollView {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    }
                } else {
                    Text("Unable to display certificate")
                        .foregroundColor(.secondary)
                }
            }
        }
        .task {
            await loadContent()
        }
    }
    
    private func loadContent() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run {
                imageData = data
                isLoading = false
            }
        } catch {
            await MainActor.run {
                loadError = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// Note: Uses PDFViewRepresentable from FileViewer.swift
