//
//  SlideshowViewModel.swift
//  Buzz
//
//  ViewModel for managing slideshow state and navigation
//

import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
class SlideshowViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentSlideIndex: Int = 0
    @Published var completedSlides: Set<Int> = []
    @Published var selectedAnswer: Int? = nil
    @Published var showAnswerFeedback: Bool = false
    @Published var isAnswerCorrect: Bool? = nil
    
    // MARK: - Properties

    let slideContents: [SlideContent]
    let onComplete: () -> Void
    private var imageCache: [Int: UIImage] = [:]
    
    // MARK: - Computed Properties
    
    var currentSlide: SlideContent? {
        guard currentSlideIndex >= 0 && currentSlideIndex < slideContents.count else {
            return nil
        }
        return slideContents[currentSlideIndex]
    }
    
    var isLastSlide: Bool {
        return currentSlideIndex == slideContents.count - 1
    }
    
    var isCurrentSlideCompleted: Bool {
        return completedSlides.contains(currentSlideIndex)
    }
    
    var progressPercentage: Double {
        guard slideContents.count > 0 else { return 0 }
        return Double(currentSlideIndex + 1) / Double(slideContents.count) * 100
    }
    
    var completionPercentage: Double {
        guard slideContents.count > 0 else { return 0 }
        return Double(completedSlides.count) / Double(slideContents.count) * 100
    }
    
    var canGoNext: Bool {
        return isCurrentSlideCompleted && !isLastSlide
    }
    
    var canGoPrevious: Bool {
        return currentSlideIndex > 0
    }
    
    // MARK: - Initialization
    
    init(materials: [CourseMaterial], onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        self.slideContents = Self.convertMaterialsToSlides(materials)
        
        print("📊 [SlideshowViewModel] Initialized with \(slideContents.count) slides")
        for (index, slide) in slideContents.enumerated() {
            print("  Slide \(index + 1): \(slide.type) - \(slide.name)")
        }
    }
    
    // MARK: - Material Conversion
    
    private static func convertMaterialsToSlides(_ materials: [CourseMaterial]) -> [SlideContent] {
        var slides: [SlideContent] = []
        
        for material in materials {
            if material.type.lowercased() == "question" {
                // Decode question from URL
                if let questionData = QuestionData.decode(from: material.url) {
                    slides.append(.question(questionData))
                } else {
                    // Fallback question if decoding fails
                    slides.append(.question(QuestionData.fallback(name: material.name)))
                }
            } else if material.isVideo {
                slides.append(.video(url: material.url, name: material.name))
            } else if material.isImage {
                slides.append(.image(url: material.url, name: material.name))
            } else if material.isPDF {
                slides.append(.pdf(url: material.url, name: material.name))
            } else {
                // Default to PDF for unknown types
                print("⚠️ Unknown material type: \(material.type), treating as PDF")
                slides.append(.pdf(url: material.url, name: material.name))
            }
        }
        
        return slides
    }
    
    // MARK: - Navigation Actions
    
    func handleNextSlide() {
        guard isCurrentSlideCompleted else {
            print("⚠️ Cannot advance - current slide not completed")
            return
        }

        guard currentSlideIndex < slideContents.count - 1 else {
            print("✅ Last slide completed - triggering completion")
            checkAndCompleteIfAllSlidesCompleted()
            return
        }

        print("➡️ Advancing to slide \(currentSlideIndex + 2)")
        currentSlideIndex += 1

        // Reset question state only if the new slide is a question
        if isQuestionSlide(at: currentSlideIndex) {
            resetQuestionState()
        }
    }
    
    func handlePreviousSlide() {
        guard currentSlideIndex > 0 else {
            print("⚠️ Already at first slide")
            return
        }

        print("⬅️ Going back to slide \(currentSlideIndex)")
        currentSlideIndex -= 1

        // Reset question state only if the new slide is a question
        if isQuestionSlide(at: currentSlideIndex) {
            resetQuestionState()
        }
    }
    
    // MARK: - Completion Tracking
    
    func markSlideCompleted(_ index: Int) {
        guard index >= 0 && index < slideContents.count else {
            print("⚠️ Invalid slide index: \(index)")
            return
        }

        if !completedSlides.contains(index) {
            print("✓ Slide \(index + 1) completed")
            completedSlides.insert(index)
            checkAndCompleteIfAllSlidesCompleted()

            // Preload the next image slide
            preloadNextImageSlide(from: index)
        }
    }
    
    private func checkAndCompleteIfAllSlidesCompleted() {
        if completedSlides.count == slideContents.count && slideContents.count > 0 {
            print("🎉 All slides completed - calling onComplete")
            onComplete()
        }
    }

    // MARK: - Image Preloading

    private func preloadNextImageSlide(from currentIndex: Int) {
        let nextIndex = currentIndex + 1
        guard nextIndex < slideContents.count else { return }

        if case .image(let url, _) = slideContents[nextIndex], imageCache[nextIndex] == nil {
            Task {
                await preloadImage(from: url, for: nextIndex)
            }
        }
    }

    private func preloadImage(from url: String, for index: Int) async {
        guard let fileUrl = URL(string: url) else { return }

        do {
            var request = URLRequest(url: fileUrl)
            request.timeoutInterval = 30.0

            // Try to add auth headers if available
            do {
                let supabase = SupabaseClient.shared.client
                let session = try await supabase.auth.session
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            } catch {
                // Continue without auth for public buckets
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                return // Silently fail for preloading
            }

            guard let uiImage = UIImage(data: data) else { return }

            await MainActor.run {
                imageCache[index] = uiImage
                print("📦 Preloaded image for slide \(index + 1)")
            }
        } catch {
            // Silently fail for preloading
        }
    }

    func getCachedImage(for index: Int) -> UIImage? {
        return imageCache[index]
    }
    
    // MARK: - Question Actions
    
    func handleAnswerSubmit() {
        guard case .question(let questionData) = currentSlide,
              let selectedIndex = selectedAnswer else {
            print("⚠️ Cannot submit - no question or no answer selected")
            return
        }
        
        let isCorrect = selectedIndex == questionData.correctAnswerIndex
        isAnswerCorrect = isCorrect
        showAnswerFeedback = true
        
        print("📝 Answer submitted: \(isCorrect ? "Correct ✓" : "Incorrect ✗")")
        
        if isCorrect {
            markSlideCompleted(currentSlideIndex)
        }
    }
    
    func selectAnswer(_ index: Int) {
        selectedAnswer = index
        print("📌 Answer selected: Option \(index + 1)")
    }
    
    func resetQuestionState() {
        selectedAnswer = nil
        showAnswerFeedback = false
        isAnswerCorrect = nil
        print("🔄 Question state reset")
    }
    
    func retryQuestion() {
        resetQuestionState()
        print("🔁 Retrying question")
    }
    
    // MARK: - Slide Type Helpers
    
    func isQuestionSlide(at index: Int) -> Bool {
        guard index >= 0 && index < slideContents.count else { return false }
        if case .question = slideContents[index] {
            return true
        }
        return false
    }
    
    // MARK: - Debug
    
    func printDebugInfo() {
        print("""
        📊 Slideshow Debug Info:
        - Current Slide: \(currentSlideIndex + 1) / \(slideContents.count)
        - Completed: \(completedSlides.count) / \(slideContents.count)
        - Progress: \(String(format: "%.1f", progressPercentage))%
        - Can Go Next: \(canGoNext)
        - Can Go Previous: \(canGoPrevious)
        - Is Last Slide: \(isLastSlide)
        """)
    }
}
