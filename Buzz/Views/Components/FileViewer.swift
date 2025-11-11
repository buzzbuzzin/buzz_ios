//
//  FileViewer.swift
//  Buzz
//
//  Created for viewing uploaded files (PDFs and images)
//

import SwiftUI
import PDFKit
import UIKit
import Supabase

struct FileViewer: View {
    let fileUrl: String
    let fileType: FileViewerType
    let bucketName: String
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var pdfDocument: PDFDocument?
    @State private var image: UIImage?
    
    private let supabase = SupabaseClient.shared.client
    
    enum FileViewerType {
        case pdf
        case image
    }
    
    // Extract file path from URL
    private var filePath: String? {
        // URL format: https://xxx.supabase.co/storage/v1/object/public/bucket-name/path/to/file
        guard let url = URL(string: fileUrl) else { 
            print("DEBUG FileViewer: Invalid URL: \(fileUrl)")
            return nil 
        }
        
        let path = url.path
        print("DEBUG FileViewer: Full URL path: \(path)")
        
        // Path format: /storage/v1/object/public/bucket-name/path/to/file
        // We need to extract everything after "/storage/v1/object/public/bucket-name/"
        let prefix = "/storage/v1/object/public/\(bucketName)/"
        if path.hasPrefix(prefix) {
            let filePath = String(path.dropFirst(prefix.count))
            print("DEBUG FileViewer: Extracted file path: \(filePath)")
            return filePath.isEmpty ? nil : filePath
        }
        
        // Alternative: Try to find bucket name in path
        if let range = path.range(of: "/\(bucketName)/") {
            let filePath = String(path[range.upperBound...])
            print("DEBUG FileViewer: Extracted file path (alternative): \(filePath)")
            return filePath.isEmpty ? nil : filePath
        }
        
        print("DEBUG FileViewer: Could not extract path from URL: \(fileUrl)")
        return nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color to see if view is rendering
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading file...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    ScrollView {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            Text("Error loading file")
                                .font(.headline)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button("Open in Browser") {
                                if let url = URL(string: fileUrl) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding()
                    }
                } else {
                    // Content viewer
                    if fileType == .pdf {
                        if let pdfDocument = pdfDocument {
                            PDFViewRepresentable(pdfDocument: pdfDocument)
                                .background(Color(UIColor.systemBackground))
                        } else {
                            VStack(spacing: 16) {
                                ProgressView()
                                Text("Processing PDF...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        if let image = image {
                            ZoomableImageView(image: image)
                                .background(Color(UIColor.systemBackground))
                        } else {
                            VStack(spacing: 16) {
                                ProgressView()
                                Text("Processing image...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(fileType == .pdf ? "PDF Document" : "Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if let url = URL(string: fileUrl) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("Open in Browser", systemImage: "safari")
                    }
                }
            }
            .task {
                await loadFile()
            }
        }
    }
    
    private func loadFile() async {
        // Try to download using Supabase storage client (with authentication)
        if let filePath = filePath {
            do {
                print("DEBUG FileViewer: Downloading from bucket: \(bucketName), path: \(filePath)")
                let data = try await supabase.storage
                    .from(bucketName)
                    .download(path: filePath)
                
                await processFileData(data: data)
            } catch {
                print("DEBUG FileViewer: Supabase download failed: \(error.localizedDescription)")
                // Fallback to direct URL if Supabase download fails
                await loadFileFromURL()
            }
        } else {
            // If we can't extract path, try direct URL
            await loadFileFromURL()
        }
    }
    
    private func loadFileFromURL() async {
        guard let url = URL(string: fileUrl) else {
            await MainActor.run {
                self.errorMessage = "Invalid file URL"
                self.isLoading = false
            }
            return
        }
        
        do {
            var request = URLRequest(url: url)
            // Try to get auth token and add it to the request
            do {
                let session = try await supabase.auth.session
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
                // Get the API key from Config
                request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            } catch {
                print("DEBUG FileViewer: Could not get auth token, trying without authentication")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG FileViewer: HTTP Status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    await MainActor.run {
                        self.errorMessage = "Failed to load file (HTTP \(httpResponse.statusCode))"
                        self.isLoading = false
                    }
                    return
                }
            }
            
            await processFileData(data: data)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load file: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func processFileData(data: Data) async {
        print("DEBUG FileViewer: Processing file data, size: \(data.count) bytes, type: \(fileType)")
        
        if fileType == .pdf {
            if let pdfDoc = PDFDocument(data: data) {
                print("DEBUG FileViewer: PDF document loaded successfully, page count: \(pdfDoc.pageCount)")
                await MainActor.run {
                    self.pdfDocument = pdfDoc
                    self.isLoading = false
                }
            } else {
                print("DEBUG FileViewer: Failed to create PDFDocument from data")
                await MainActor.run {
                    self.errorMessage = "Failed to load PDF document. The file may be corrupted or invalid."
                    self.isLoading = false
                }
            }
        } else {
            if let img = UIImage(data: data) {
                print("DEBUG FileViewer: Image loaded successfully, size: \(img.size)")
                await MainActor.run {
                    self.image = img
                    self.isLoading = false
                }
            } else {
                print("DEBUG FileViewer: Failed to create UIImage from data")
                await MainActor.run {
                    self.errorMessage = "Failed to load image. The file may be corrupted or in an unsupported format."
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - PDFView Representable

struct PDFViewRepresentable: UIViewRepresentable {
    let pdfDocument: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = pdfDocument
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemBackground
        pdfView.displaysPageBreaks = true
        pdfView.pageShadowsEnabled = true
        
        // Ensure PDF is visible
        DispatchQueue.main.async {
            pdfView.goToFirstPage(nil)
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document != pdfDocument {
            pdfView.document = pdfDocument
        }
    }
}

// MARK: - Zoomable Image View

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.delegate = context.coordinator
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.backgroundColor = .systemBackground
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
        
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView
        context.coordinator.image = image
        
        // Set initial layout after a brief delay to ensure view is laid out
        DispatchQueue.main.async {
            context.coordinator.updateLayout(for: scrollView)
        }
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Update layout when view size changes
        if scrollView.bounds.size.width > 0 && scrollView.bounds.size.height > 0 {
            context.coordinator.updateLayout(for: scrollView)
        }
    }
    
    static func dismantleUIView(_ scrollView: UIScrollView, coordinator: Coordinator) {
        // Cleanup if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(image: image)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var image: UIImage
        var imageView: UIImageView?
        var scrollView: UIScrollView?
        
        init(image: UIImage) {
            self.image = image
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }
        
        func updateLayout(for scrollView: UIScrollView) {
            guard let imageView = imageView else { return }
            
            let scrollViewSize = scrollView.bounds.size
            guard scrollViewSize.width > 0 && scrollViewSize.height > 0 else { return }
            
            let imageSize = image.size
            guard imageSize.width > 0 && imageSize.height > 0 else { return }
            
            // Calculate scale to fit image in scroll view
            let widthScale = scrollViewSize.width / imageSize.width
            let heightScale = scrollViewSize.height / imageSize.height
            let minScale = min(widthScale, heightScale, 1.0)
            
            // Set image view frame
            let scaledImageSize = CGSize(
                width: imageSize.width * minScale,
                height: imageSize.height * minScale
            )
            
            imageView.frame = CGRect(
                x: 0,
                y: 0,
                width: scaledImageSize.width,
                height: scaledImageSize.height
            )
            
            scrollView.contentSize = scaledImageSize
            scrollView.minimumZoomScale = minScale
            scrollView.maximumZoomScale = 5.0
            
            if scrollView.zoomScale < minScale {
                scrollView.zoomScale = minScale
            }
            
            centerImage(in: scrollView)
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage(in: scrollView)
        }
        
        private func centerImage(in scrollView: UIScrollView) {
            guard let imageView = imageView else { return }
            
            let boundsSize = scrollView.bounds.size
            var frameToCenter = imageView.frame
            
            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
            } else {
                frameToCenter.origin.x = 0
            }
            
            if frameToCenter.size.height < boundsSize.height {
                frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
            } else {
                frameToCenter.origin.y = 0
            }
            
            imageView.frame = frameToCenter
        }
    }
}

