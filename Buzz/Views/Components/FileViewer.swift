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
    @State private var downloadProgress: Double = 0.0
    @State private var downloadedBytes: Int64 = 0
    @State private var totalBytes: Int64 = 0
    
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
                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(2.0)
                        
                        VStack(spacing: 12) {
                            Text("Downloading file...")
                                .font(.headline)
                            
                            // Progress Bar
                            VStack(spacing: 8) {
                                ProgressView(value: downloadProgress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                    .frame(height: 8)
                                
                                HStack {
                                    Text("\(Int(downloadProgress * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if totalBytes > 0 {
                                        Text(formatBytes(downloadedBytes) + " / " + formatBytes(totalBytes))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 40)
                        }
                        
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
                            
                            Text("If the file doesn't load, please check your internet connection and try again.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
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
        
        // Reset progress
        await MainActor.run {
            self.downloadProgress = 0.0
            self.downloadedBytes = 0
            self.totalBytes = 0
        }
        
        do {
            // For public buckets, we can try without auth first
            var request = URLRequest(url: url)
            request.timeoutInterval = 60.0 // Increased timeout for large files
            
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
            
            print("DEBUG FileViewer: Starting URLSession download with progress tracking...")
            
            // Use URLSession with delegate to track progress
            let (data, response) = try await downloadWithProgress(request: request)
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
    
    // Download with progress tracking
    private func downloadWithProgress(request: URLRequest) async throws -> (Data, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = DownloadDelegate { progress, downloaded, total in
                Task { @MainActor in
                    self.downloadProgress = progress
                    self.downloadedBytes = downloaded
                    self.totalBytes = total
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
    
    // Format bytes to human-readable string
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Download Delegate for Progress Tracking

class DownloadDelegate: NSObject, URLSessionDataDelegate {
    var task: URLSessionDataTask?
    var receivedData = Data()
    var expectedContentLength: Int64 = 0
    
    let progressHandler: (Double, Int64, Int64) -> Void
    let completionHandler: (Result<(Data, URLResponse), Error>) -> Void
    
    init(progress: @escaping (Double, Int64, Int64) -> Void, completion: @escaping (Result<(Data, URLResponse), Error>) -> Void) {
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
        
        progressHandler(progress, downloaded, total)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            completionHandler(.failure(error))
        } else {
            if let response = task.response {
                completionHandler(.success((receivedData, response)))
            } else {
                completionHandler(.failure(NSError(domain: "FileViewer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response received"])))
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
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemBackground
        pdfView.displaysPageBreaks = true
        pdfView.pageShadowsEnabled = true
        
        print("DEBUG PDFView: Created PDFView with \(pdfDocument.pageCount) pages")
        
        // Set up auto-scaling after view is laid out
        // This ensures the PDF fits the view properly without being zoomed in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pdfView.goToFirstPage(nil)
            // Use scaleFactorForSizeToFit to ensure it fits the view bounds
            if let firstPage = pdfDocument.page(at: 0) {
                let pageRect = firstPage.bounds(for: .mediaBox)
                let viewSize = pdfView.bounds.size
                
                if viewSize.width > 0 && viewSize.height > 0 && pageRect.width > 0 && pageRect.height > 0 {
                    let widthScale = viewSize.width / pageRect.width
                    let heightScale = viewSize.height / pageRect.height
                    let scale = min(widthScale, heightScale)
                    
                    // Set the scale to fit, but don't exceed 1.0 (no zoom in by default)
                    pdfView.scaleFactor = min(scale, 1.0)
                    pdfView.autoScales = true
                    print("DEBUG PDFView: Set scale factor to fit: \(min(scale, 1.0))")
                } else {
                    pdfView.autoScales = true
                    print("DEBUG PDFView: Using autoScales (view not laid out yet)")
                }
            } else {
                pdfView.autoScales = true
            }
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document != pdfDocument {
            print("DEBUG PDFView: Updating document")
            pdfView.document = pdfDocument
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pdfView.goToFirstPage(nil)
                pdfView.autoScales = true
            }
        }
    }
}

// MARK: - Zoomable Image View

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.backgroundColor = .systemBackground
        scrollView.bouncesZoom = true
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        scrollView.addSubview(imageView)
        
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView
        context.coordinator.image = image
        
        // Set initial layout after view is properly laid out
        // This ensures we calculate the correct fit-to-screen scale
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
            guard scrollViewSize.width > 0 && scrollViewSize.height > 0 else { 
                print("DEBUG ZoomableImageView: ScrollView not laid out yet")
                return 
            }
            
            let imageSize = image.size
            guard imageSize.width > 0 && imageSize.height > 0 else { 
                print("DEBUG ZoomableImageView: Invalid image size")
                return 
            }
            
            // Calculate scale to fit image in scroll view
            // This gives us the scale needed to fit the entire image on screen
            let widthScale = scrollViewSize.width / imageSize.width
            let heightScale = scrollViewSize.height / imageSize.height
            let fitScale = min(widthScale, heightScale)
            
            // For initial display:
            // - If image is larger than screen: scale down to fit (use fitScale, which is < 1.0)
            // - If image is smaller than screen: show at actual size (use 1.0, don't zoom in)
            // This ensures we never zoom in by default
            let initialScale = min(fitScale, 1.0)
            
            // Minimum zoom: same as initial scale
            // This prevents zooming out beyond the fit-to-screen or actual-size view
            let minZoom = initialScale
            
            print("DEBUG ZoomableImageView: ScrollView size: \(scrollViewSize)")
            print("DEBUG ZoomableImageView: Image size: \(imageSize)")
            print("DEBUG ZoomableImageView: Fit scale: \(fitScale), Initial scale: \(initialScale), Min zoom: \(minZoom)")
            
            // Set image view frame to actual image size (before zoom)
            imageView.frame = CGRect(
                x: 0,
                y: 0,
                width: imageSize.width,
                height: imageSize.height
            )
            
            // Configure zoom scales
            scrollView.minimumZoomScale = minZoom
            scrollView.maximumZoomScale = 5.0
            
            // Set initial zoom to fit screen (no zoom in by default)
            scrollView.zoomScale = initialScale
            
            // Calculate and set content size based on initial zoom
            let finalContentSize = CGSize(
                width: imageSize.width * initialScale,
                height: imageSize.height * initialScale
            )
            scrollView.contentSize = finalContentSize
            
            // Reset scroll position and insets
            scrollView.contentOffset = .zero
            scrollView.contentInset = .zero
            
            // Center the image if it's smaller than the screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.centerImage(in: scrollView)
            }
            
            print("DEBUG ZoomableImageView: Set zoomScale to \(initialScale), contentSize: \(finalContentSize)")
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            // Update content size during zoom
            let scale = scrollView.zoomScale
            scrollView.contentSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            centerImage(in: scrollView)
        }
        
        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            // Ensure content size is correct after zoom ends
            scrollView.contentSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            centerImage(in: scrollView)
        }
        
        private func centerImage(in scrollView: UIScrollView) {
            guard let imageView = imageView else { return }
            
            let boundsSize = scrollView.bounds.size
            let contentSize = scrollView.contentSize
            
            // Calculate content inset to center the image
            var insetX: CGFloat = 0
            var insetY: CGFloat = 0
            
            if contentSize.width < boundsSize.width {
                insetX = (boundsSize.width - contentSize.width) / 2.0
            }
            
            if contentSize.height < boundsSize.height {
                insetY = (boundsSize.height - contentSize.height) / 2.0
            }
            
            // Set content inset to center the image
            scrollView.contentInset = UIEdgeInsets(
                top: insetY,
                left: insetX,
                bottom: insetY,
                right: insetX
            )
        }
    }
}

