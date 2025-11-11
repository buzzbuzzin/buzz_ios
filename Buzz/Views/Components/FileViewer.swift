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
        ZStack {
            // Background - use a distinct color to verify view is rendering
            Color(UIColor.secondarySystemBackground)
                .ignoresSafeArea()
            
            VStack {
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(2.0)
                        Text("Loading file...")
                            .font(.headline)
                        Text(fileUrl)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding()
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    ScrollView {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.red)
                            Text("Error Loading File")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(errorMessage)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("File URL:")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text(fileUrl)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .textSelection(.enabled)
                            }
                            .padding()
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(8)
                            
                            Button(action: {
                                if let url = URL(string: fileUrl) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "safari")
                                    Text("Open in Browser")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                    }
                } else if fileType == .pdf {
                    if let pdfDocument = pdfDocument {
                        PDFViewRepresentable(pdfDocument: pdfDocument)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(2.0)
                            Text("Loading PDF...")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else if fileType == .image {
                    if let image = image {
                        ZoomableImageView(image: image)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(2.0)
                            Text("Loading image...")
                                .font(.headline)
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
                    print("DEBUG FileViewer: Done button tapped")
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    print("DEBUG FileViewer: Open in browser tapped")
                    if let url = URL(string: fileUrl) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Browser", systemImage: "safari")
                }
            }
        }
        .onAppear {
            print("DEBUG FileViewer: ========== VIEW APPEARED ==========")
            print("DEBUG FileViewer: URL: \(fileUrl)")
            print("DEBUG FileViewer: Bucket: \(bucketName)")
            print("DEBUG FileViewer: Type: \(fileType == .pdf ? "PDF" : "Image")")
            print("DEBUG FileViewer: isLoading: \(isLoading)")
            print("DEBUG FileViewer: errorMessage: \(errorMessage ?? "nil")")
            print("DEBUG FileViewer: pdfDocument: \(pdfDocument != nil ? "exists" : "nil")")
            print("DEBUG FileViewer: image: \(image != nil ? "exists" : "nil")")
        }
        .task {
            print("DEBUG FileViewer: ========== TASK STARTED ==========")
            await loadFile()
        }
    }
    
    private func loadFile() async {
        print("DEBUG FileViewer: loadFile() called")
        print("DEBUG FileViewer: fileUrl = \(fileUrl)")
        print("DEBUG FileViewer: bucketName = \(bucketName)")
        
        // First, try direct URL download (simplest approach for public buckets)
        await loadFileFromURL()
    }
    
    private func loadFileFromURL() async {
        print("DEBUG FileViewer: loadFileFromURL() called")
        
        guard let url = URL(string: fileUrl) else {
            print("DEBUG FileViewer: Invalid URL string: \(fileUrl)")
            await MainActor.run {
                self.errorMessage = "Invalid file URL: \(fileUrl)"
                self.isLoading = false
            }
            return
        }
        
        print("DEBUG FileViewer: Created URL: \(url.absoluteString)")
        print("DEBUG FileViewer: URL path: \(url.path)")
        print("DEBUG FileViewer: URL host: \(url.host ?? "nil")")
        
        do {
            // For public buckets, we can try without auth first
            var request = URLRequest(url: url)
            request.timeoutInterval = 30.0
            
            // Try with authentication if available
            do {
                let session = try await supabase.auth.session
                print("DEBUG FileViewer: Got auth session, adding headers")
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            } catch {
                print("DEBUG FileViewer: No auth session available: \(error.localizedDescription)")
                print("DEBUG FileViewer: Trying without authentication (public bucket)")
            }
            
            print("DEBUG FileViewer: Starting URLSession download...")
            let (data, response) = try await URLSession.shared.data(for: request)
            print("DEBUG FileViewer: Download completed, data size: \(data.count) bytes")
            
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG FileViewer: HTTP Status: \(httpResponse.statusCode)")
                print("DEBUG FileViewer: HTTP Headers: \(httpResponse.allHeaderFields)")
                
                if httpResponse.statusCode != 200 {
                    let errorMsg = "Failed to load file (HTTP \(httpResponse.statusCode))"
                    print("DEBUG FileViewer: \(errorMsg)")
                    await MainActor.run {
                        self.errorMessage = errorMsg
                        self.isLoading = false
                    }
                    return
                }
            }
            
            guard data.count > 0 else {
                print("DEBUG FileViewer: Received empty data")
                await MainActor.run {
                    self.errorMessage = "Received empty file data"
                    self.isLoading = false
                }
                return
            }
            
            print("DEBUG FileViewer: Processing \(data.count) bytes of data")
            await processFileData(data: data)
        } catch {
            print("DEBUG FileViewer: Error downloading file: \(error)")
            print("DEBUG FileViewer: Error details: \(error.localizedDescription)")
            
            // Try fallback: Use Supabase storage client
            if let filePath = filePath {
                print("DEBUG FileViewer: Trying Supabase storage client as fallback...")
                await loadFileFromSupabaseStorage(filePath: filePath)
            } else {
                await MainActor.run {
                    self.errorMessage = "Failed to load file: \(error.localizedDescription)\n\nURL: \(fileUrl)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadFileFromSupabaseStorage(filePath: String) async {
        do {
            print("DEBUG FileViewer: Downloading from Supabase storage")
            print("DEBUG FileViewer: Bucket: \(bucketName), Path: \(filePath)")
            
            let data = try await supabase.storage
                .from(bucketName)
                .download(path: filePath)
            
            print("DEBUG FileViewer: Supabase download successful, size: \(data.count) bytes")
            await processFileData(data: data)
        } catch {
            print("DEBUG FileViewer: Supabase storage download also failed: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to load file from storage: \(error.localizedDescription)\n\nPlease try opening in browser."
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
        
        print("DEBUG PDFView: Created PDFView with \(pdfDocument.pageCount) pages")
        
        // Ensure PDF is visible and scaled properly
        DispatchQueue.main.async {
            pdfView.goToFirstPage(nil)
            pdfView.autoScales = true
            print("DEBUG PDFView: Navigated to first page, autoScales: \(pdfView.autoScales)")
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document != pdfDocument {
            print("DEBUG PDFView: Updating document")
            pdfView.document = pdfDocument
            pdfView.autoScales = true
            DispatchQueue.main.async {
                pdfView.goToFirstPage(nil)
            }
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

