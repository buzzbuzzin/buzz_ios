//
//  ImageSlideView.swift
//  Buzz
//
//  Image slide renderer with auto-completion
//

import SwiftUI
import Supabase
import Auth

struct ImageSlideView: View {
    let url: String
    let name: String
    let onComplete: () -> Void
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasAutoCompleted = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading image...")
                        .font(.headline)
                }
            } else if let errorMessage = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "photo.badge.exclamationmark.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    Text("Error Loading Image")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        Task {
                            await loadImage()
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
            } else if let image = image {
                SlideZoomableImageView(image: image)
                    .ignoresSafeArea()
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        isLoading = true
        errorMessage = nil
        hasAutoCompleted = false
        
        guard let fileUrl = URL(string: url) else {
            errorMessage = "Invalid image URL"
            isLoading = false
            return
        }
        
        do {
            // Create download request
            var request = URLRequest(url: fileUrl)
            request.timeoutInterval = 30.0
            
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
            
            // Download image data
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                throw NSError(domain: "ImageSlideView", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
            }
            
            guard let uiImage = UIImage(data: data) else {
                throw NSError(domain: "ImageSlideView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode image data"])
            }
            
            await MainActor.run {
                self.image = uiImage
                self.isLoading = false
                print("✅ Image loaded successfully: \(name)")
                
                // Auto-complete after successful load
                if !hasAutoCompleted {
                    hasAutoCompleted = true
                    // Small delay to ensure smooth transition
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        onComplete()
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load image: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Image load error: \(error)")
            }
        }
    }
}

// MARK: - Zoomable Image View

private struct SlideZoomableImageView: UIViewRepresentable {
    let image: UIImage
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.bouncesZoom = true
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        scrollView.addSubview(imageView)
        
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView
        context.coordinator.image = image
        
        // Set initial layout after view is properly laid out
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
            let fitScale = min(widthScale, heightScale)
            
            // Initial scale: fit to screen or actual size (no zoom in by default)
            let initialScale = min(fitScale, 1.0)
            let minZoom = initialScale
            
            // Set image view frame to actual image size (before zoom)
            imageView.frame = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
            
            // Configure zoom scales
            scrollView.minimumZoomScale = minZoom
            scrollView.maximumZoomScale = 5.0
            scrollView.zoomScale = initialScale
            
            // Set content size
            let finalContentSize = CGSize(
                width: imageSize.width * initialScale,
                height: imageSize.height * initialScale
            )
            scrollView.contentSize = finalContentSize
            
            // Reset scroll position
            scrollView.contentOffset = .zero
            scrollView.contentInset = .zero
            
            // Center the image
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.centerImage(in: scrollView)
            }
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let scale = scrollView.zoomScale
            scrollView.contentSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            centerImage(in: scrollView)
        }
        
        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
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
            
            var insetX: CGFloat = 0
            var insetY: CGFloat = 0
            
            if contentSize.width < boundsSize.width {
                insetX = (boundsSize.width - contentSize.width) / 2.0
            }
            
            if contentSize.height < boundsSize.height {
                insetY = (boundsSize.height - contentSize.height) / 2.0
            }
            
            scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
        }
    }
}
