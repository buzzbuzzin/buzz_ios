//
//  PDFSlideView.swift
//  Buzz
//
//  PDF slide renderer with continue button
//

import SwiftUI
import PDFKit
import Supabase
import Auth

struct PDFSlideView: View {
    let url: String
    let name: String
    let bucketName: String = "course-materials"
    let onComplete: () -> Void
    
    @State private var pdfDocument: PDFDocument?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var downloadProgress: Double = 0.0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // PDF Content
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading PDF...")
                            .font(.headline)
                        
                        if downloadProgress > 0 {
                            ProgressView(value: downloadProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .frame(width: 200)
                        }
                    }
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        Text("Error Loading PDF")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            Task {
                                await loadPDF()
                            }
                        }) {
                            Text("Retry")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                } else if let pdfDocument = pdfDocument {
                    PDFViewRepresentable(pdfDocument: pdfDocument)
                        .ignoresSafeArea()
                }
            }
            
            // Continue Button Overlay
            if !isLoading && errorMessage == nil {
                Button(action: onComplete) {
                    HStack {
                        Text("Continue")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .padding()
            }
        }
        .task {
            await loadPDF()
        }
    }
    
    private func loadPDF() async {
        isLoading = true
        errorMessage = nil
        
        guard let fileUrl = URL(string: url) else {
            errorMessage = "Invalid PDF URL"
            isLoading = false
            return
        }
        
        do {
            // Create download request
            var request = URLRequest(url: fileUrl)
            request.timeoutInterval = 60.0
            
            // Try to add auth headers if available
            do {
                let supabase = SupabaseClient.shared.client
                let session = try await supabase.auth.session
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            } catch {
                // Continue without auth for public buckets
                print("⚠️ No auth available, trying public access")
            }
            
            // Download with progress tracking
            let (data, response) = try await downloadWithProgress(request: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                throw NSError(domain: "PDFSlideView", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
            }
            
            guard let pdfDoc = PDFDocument(data: data) else {
                throw NSError(domain: "PDFSlideView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF document"])
            }
            
            await MainActor.run {
                self.pdfDocument = pdfDoc
                self.isLoading = false
                print("✅ PDF loaded successfully: \(name)")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load PDF: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ PDF load error: \(error)")
            }
        }
    }
    
    private func downloadWithProgress(request: URLRequest) async throws -> (Data, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = PDFDownloadDelegate { progress in
                Task { @MainActor in
                    self.downloadProgress = progress
                }
            } completion: { result in
                continuation.resume(with: result)
            }
            
            let configuration = URLSessionConfiguration.default
            let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            
            let task = session.dataTask(with: request)
            delegate.task = task
            task.resume()
        }
    }
}

// MARK: - Download Delegate

private class PDFDownloadDelegate: NSObject, URLSessionDataDelegate {
    var task: URLSessionDataTask?
    var receivedData = Data()
    var expectedContentLength: Int64 = 0
    
    let progressHandler: (Double) -> Void
    let completionHandler: (Result<(Data, URLResponse), Error>) -> Void
    
    init(progress: @escaping (Double) -> Void, completion: @escaping (Result<(Data, URLResponse), Error>) -> Void) {
        self.progressHandler = progress
        self.completionHandler = completion
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        expectedContentLength = response.expectedContentLength
        receivedData = Data()
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
        
        let downloaded = Int64(receivedData.count)
        let total = expectedContentLength > 0 ? expectedContentLength : downloaded
        let progress = total > 0 ? Double(downloaded) / Double(total) : 0.0
        
        progressHandler(progress)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            completionHandler(.failure(error))
        } else {
            if let response = task.response {
                completionHandler(.success((receivedData, response)))
            } else {
                completionHandler(.failure(NSError(domain: "PDFSlideView", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response received"])))
            }
        }
    }
}
