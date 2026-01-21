//
//  SlidePresentationView.swift
//  Buzz
//
//  Main slideshow presentation with preview, fullscreen, and navigation
//

import SwiftUI
import UIKit

struct SlidePresentationView: View {
    let unit: CourseUnit
    let materials: [CourseMaterial]
    let onComplete: () -> Void
    
    @StateObject private var viewModel: SlideshowViewModel
    @State private var isPreviewMode = true
    @State private var showExitAlert = false
    @Environment(\.dismiss) var dismiss
    
    init(unit: CourseUnit, materials: [CourseMaterial], onComplete: @escaping () -> Void) {
        self.unit = unit
        self.materials = materials
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: SlideshowViewModel(
            materials: materials,
            onComplete: {
                onComplete()
            }
        ))
    }
    
    var body: some View {
        ZStack {
            if isPreviewMode {
                previewView
            } else {
                slideshowView
            }
        }
        .statusBar(hidden: !isPreviewMode)
        .onChange(of: isPreviewMode) { _, newValue in
            if !newValue {
                // Force landscape when entering slideshow mode
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                }
            }
        }
    }
    
    // MARK: - Preview Mode
    
    private var previewView: some View {
        ZStack {
            // Blurred background (first slide preview)
            if let firstSlide = viewModel.slideContents.first {
                slidePreviewBackground(firstSlide)
                    .blur(radius: 20)
                    .opacity(0.3)
            }
            
            // Overlay content
            VStack(spacing: 32) {
                Spacer()
                
                // Play button
                Button(action: startSlideshow) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 100, height: 100)
                            .shadow(color: Color.blue.opacity(0.4), radius: 20, x: 0, y: 10)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                }
                
                // Title and info
                VStack(spacing: 12) {
                    Text(unit.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    if let description = unit.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    HStack(spacing: 20) {
                        Label("\(viewModel.slideContents.count) slides", systemImage: "square.stack.3d.up.fill")
                        Label("Interactive", systemImage: "hand.tap.fill")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                // Start button
                Button(action: startSlideshow) {
                    Text("Start")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .background(Color(.systemBackground))
    }
    
    private func slidePreviewBackground(_ slide: SlideContent) -> some View {
        Group {
            switch slide {
            case .pdf:
                Color.gray.opacity(0.3)
            case .image:
                Color.blue.opacity(0.3)
            case .video:
                Color.purple.opacity(0.3)
            case .question:
                Color.green.opacity(0.3)
            }
        }
    }
    
    // MARK: - Slideshow View
    
    private var slideshowView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress Bar
                progressBar
                
                // Current Slide Content
                if let currentSlide = viewModel.currentSlide {
                    slideContentView(currentSlide)
                } else {
                    Text("No slides available")
                        .foregroundColor(.white)
                }
            }
            
            // Floating Navigation Controls
            navigationControls
            
            // Exit Button
            exitButton
        }
        .alert("Exit Slideshow?", isPresented: $showExitAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Exit", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("Your progress will be saved, but you'll need to restart the slideshow from the beginning.")
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)
                    
                    // Progress
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * (viewModel.progressPercentage / 100), height: 4)
                }
            }
            .frame(height: 4)
            
            // Slide counter
            HStack {
                Text("\(viewModel.currentSlideIndex + 1) / \(viewModel.slideContents.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(viewModel.currentSlide?.type ?? "")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
        .background(Color.black.opacity(0.3))
    }
    
    // MARK: - Slide Content
    
    @ViewBuilder
    private func slideContentView(_ slide: SlideContent) -> some View {
        switch slide {
        case .pdf(let url, let name):
            PDFSlideView(
                url: url,
                name: name,
                onComplete: {
                    viewModel.markSlideCompleted(viewModel.currentSlideIndex)
                }
            )
            .id("\(viewModel.currentSlideIndex)-\(url)")
            
        case .image(let url, let name):
            ImageSlideView(
                url: url,
                name: name,
                cachedImage: viewModel.getCachedImage(for: viewModel.currentSlideIndex),
                onComplete: {
                    viewModel.markSlideCompleted(viewModel.currentSlideIndex)
                }
            )
            .id("\(viewModel.currentSlideIndex)-\(url)")
            
        case .video(let url, let name):
            VideoSlideView(
                url: url,
                name: name,
                onComplete: {
                    viewModel.markSlideCompleted(viewModel.currentSlideIndex)
                }
            )
            .id("\(viewModel.currentSlideIndex)-\(url)")
            
        case .question(let questionData):
            QuestionSlideView(
                questionData: questionData,
                onComplete: {
                    viewModel.markSlideCompleted(viewModel.currentSlideIndex)
                }
            )
            .id("\(viewModel.currentSlideIndex)-\(questionData.questionText)")
        }
    }
    
    // MARK: - Navigation Controls
    
    private var navigationControls: some View {
        HStack {
            // Previous Button
            if viewModel.canGoPrevious {
                Button(action: {
                    viewModel.handlePreviousSlide()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                        .shadow(radius: 10)
                }
                .padding(.leading, 20)
            }
            
            Spacer()
            
            // Next Button
            if viewModel.canGoNext {
                Button(action: {
                    viewModel.handleNextSlide()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                        .shadow(radius: 10)
                }
                .padding(.trailing, 20)
            } else if viewModel.isCurrentSlideCompleted && viewModel.isLastSlide {
                // Complete Button on last slide
                Button(action: {
                    onComplete()
                    dismiss()
                }) {
                    HStack {
                        Text("Complete")
                            .fontWeight(.semibold)
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(25)
                    .shadow(radius: 10)
                }
                .padding(.trailing, 20)
            }
        }
    }
    
    // MARK: - Exit Button
    
    private var exitButton: some View {
        VStack {
            HStack {
                Button(action: {
                    showExitAlert = true
                }) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                        .shadow(radius: 10)
                }
                .padding(.top, 16)
                .padding(.leading, 20)
                
                Spacer()
            }
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func startSlideshow() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPreviewMode = false
        }
    }
}
