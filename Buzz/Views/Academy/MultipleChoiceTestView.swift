//
//  MultipleChoiceTestView.swift
//  Buzz
//
//  Generic multiple choice test view that works for any test
//  Fetches questions, answers, and images from the test_questions table
//

import SwiftUI
import Supabase

struct MultipleChoiceTestView: View {
    let testId: UUID
    let course: TrainingCourse
    let pilotId: UUID
    let testName: String
    let passingScore: Int
    let durationMinutes: Int
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var badgeService = BadgeService()
    @StateObject private var academyService = AcademyService()
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswers: [UUID: Int] = [:]
    @State private var showResults = false
    @State private var testScore = 0
    @State private var passed = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var questions: [TestQuestion] = []
    @State private var showQuestionNavigator = false
    @State private var showExitAlert = false
    @State private var selectedChartURL: URL? = nil
    @State private var showChartViewer = false
    @State private var timeRemaining: TimeInterval
    @State private var timer: Timer? = nil
    @State private var testStartTime: Date? = nil
    @State private var wasAutoSubmitted = false
    
    // Computed property for duration in seconds
    private var durationSeconds: TimeInterval {
        TimeInterval(durationMinutes * 60)
    }
    
    // Custom initializer
    init(testId: UUID, course: TrainingCourse, pilotId: UUID, testName: String, passingScore: Int = 70, durationMinutes: Int = 60) {
        self.testId = testId
        self.course = course
        self.pilotId = pilotId
        self.testName = testName
        self.passingScore = passingScore
        self.durationMinutes = durationMinutes
        self._timeRemaining = State(initialValue: TimeInterval(durationMinutes * 60))
    }
    
    var currentQuestion: TestQuestion {
        questions[currentQuestionIndex]
    }
    
    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(selectedAnswers.count) / Double(questions.count)
    }
    
    var answeredQuestionsCount: Int {
        selectedAnswers.count
    }
    
    var timeRemainingFormatted: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        testContentView
            .navigationTitle(testName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                testToolbar
            }
            .alert("Exit Test?", isPresented: $showExitAlert) {
                exitAlert
            } message: {
                Text("By exiting you will lose all your test progress and you will have to retake the exam.")
            }
            .sheet(isPresented: $showQuestionNavigator) {
                questionNavigatorSheet
            }
            .sheet(isPresented: $showChartViewer) {
                chartViewerSheet
            }
            .task {
                await loadTestQuestions()
            }
            .onDisappear {
                stopTimer()
            }
    }
    
    @ViewBuilder
    private var testContentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                    if isLoading {
                        // Loading state
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading test questions...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else if let errorMessage = errorMessage {
                        // Error state
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            Text("Error Loading Test")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                Task {
                                    await loadTestQuestions()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                    } else if questions.isEmpty {
                        // No questions state
                        VStack(spacing: 16) {
                            Image(systemName: "doc.questionmark")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            Text("No Test Questions")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("This test doesn't have any questions yet.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else if showResults {
                        // Results View
                        MultipleChoiceTestResultsView(
                            score: testScore,
                            passed: passed,
                            totalQuestions: questions.count,
                            wasAutoSubmitted: wasAutoSubmitted,
                            testName: testName,
                            passingScore: passingScore,
                            onDismiss: {
                                dismiss()
                            }
                        )
                    } else {
                        // Test View
                        VStack(alignment: .leading, spacing: 20) {
                            // Timer Display (above progress bar)
                            HStack {
                                Spacer()
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(timeRemaining < 300 ? .red : .blue)
                                        .font(.title3)
                                    Text(timeRemainingFormatted)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(timeRemaining < 300 ? .red : .blue)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    timeRemaining < 300
                                        ? Color.red.opacity(0.15)
                                        : Color.blue.opacity(0.15)
                                )
                                .cornerRadius(10)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            
                            // Progress Bar Section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Question \(currentQuestionIndex + 1) of \(questions.count)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(answeredQuestionsCount)/\(questions.count) answered")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(answeredQuestionsCount == questions.count ? .green : .blue)
                                }
                                
                                ProgressView(value: progress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: answeredQuestionsCount == questions.count ? .green : .blue))
                            }
                            .padding(.horizontal)
                            
                            // Question
                            VStack(alignment: .leading, spacing: 16) {
                                Text(currentQuestion.questionText)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal)
                                
                                // Chart images (if available from database)
                                if !currentQuestion.imageUrls.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(currentQuestion.imageUrls, id: \.self) { urlString in
                                                if let url = URL(string: urlString) {
                                                    Button(action: {
                                                        selectedChartURL = url
                                                        showChartViewer = true
                                                    }) {
                                                        AsyncImage(url: url) { image in
                                                            image
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fit)
                                                                .frame(height: 200)
                                                                .cornerRadius(8)
                                                                .overlay(
                                                                    VStack {
                                                                        Spacer()
                                                                        HStack {
                                                                            Spacer()
                                                                            Image(systemName: "magnifyingglass")
                                                                                .padding(8)
                                                                                .background(Color.black.opacity(0.6))
                                                                                .foregroundColor(.white)
                                                                                .cornerRadius(6)
                                                                                .padding(8)
                                                                        }
                                                                    }
                                                                )
                                                        } placeholder: {
                                                            ProgressView()
                                                                .frame(height: 200)
                                                        }
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                
                                // Answer Options
                                VStack(spacing: 12) {
                                    ForEach(Array(currentQuestion.options.enumerated()), id: \.offset) { index, option in
                                        Button(action: {
                                            selectedAnswers[currentQuestion.id] = index
                                        }) {
                                            HStack {
                                                Text(option)
                                                    .font(.body)
                                                    .foregroundColor(.primary)
                                                    .multilineTextAlignment(.leading)
                                                
                                                Spacer()
                                            }
                                            .padding()
                                            .background(
                                                selectedAnswers[currentQuestion.id] == index
                                                    ? Color.blue.opacity(0.1)
                                                    : Color(.systemGray6)
                                            )
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(
                                                        selectedAnswers[currentQuestion.id] == index
                                                            ? Color.blue
                                                            : Color.clear,
                                                        lineWidth: 2
                                                    )
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Navigation Buttons
                            VStack(spacing: 12) {
                                // Skip Button (always visible)
                                Button(action: {
                                    withAnimation {
                                        if currentQuestionIndex < questions.count - 1 {
                                            currentQuestionIndex += 1
                                        }
                                    }
                                }) {
                                    Text("Skip")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(12)
                                }
                                .disabled(currentQuestionIndex == questions.count - 1)
                                
                                HStack(spacing: 16) {
                                    // Previous Button
                                    if currentQuestionIndex > 0 {
                                        Button(action: {
                                            withAnimation {
                                                currentQuestionIndex -= 1
                                            }
                                        }) {
                                            Text("Previous")
                                                .font(.headline)
                                                .foregroundColor(.blue)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 50)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(12)
                                        }
                                    }
                                    
                                    // Next/Submit Button
                                    Button(action: {
                                        if currentQuestionIndex < questions.count - 1 {
                                            withAnimation {
                                                currentQuestionIndex += 1
                                            }
                                        } else {
                                            submitTest()
                                        }
                                    }) {
                                        Text(currentQuestionIndex < questions.count - 1 ? "Next" : "Submit Test")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 50)
                                            .background(
                                                (currentQuestionIndex < questions.count - 1)
                                                    ? (selectedAnswers[currentQuestion.id] != nil ? Color.blue : Color.gray)
                                                    : (selectedAnswers.count == questions.count ? Color.green : Color.gray)
                                            )
                                            .cornerRadius(12)
                                    }
                                    .disabled(
                                        (currentQuestionIndex < questions.count - 1 && selectedAnswers[currentQuestion.id] == nil) ||
                                        (currentQuestionIndex == questions.count - 1 && selectedAnswers.count != questions.count)
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                    }
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
            }
        }
    }
    
    @ToolbarContentBuilder
    private var testToolbar: some ToolbarContent {
        if !showResults && !isLoading {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Exit") {
                    stopTimer()
                    showExitAlert = true
                }
                .foregroundColor(.red)
            }
            
            if !questions.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showQuestionNavigator = true
                    }) {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.title3)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var exitAlert: some View {
        Button("Cancel", role: .cancel) {
            startTimer() // Resume timer if canceling exit
        }
        Button("Exit", role: .destructive) {
            stopTimer()
            dismiss()
        }
    }
    
    @ViewBuilder
    private var questionNavigatorSheet: some View {
        QuestionNavigatorView(
            questions: questions,
            selectedAnswers: selectedAnswers,
            currentQuestionIndex: $currentQuestionIndex,
            onDismiss: {
                showQuestionNavigator = false
            }
        )
    }
    
    @ViewBuilder
    private var chartViewerSheet: some View {
        if let chartURL = selectedChartURL {
            ChartImageViewer(imageURL: chartURL)
        }
    }
    
    private func loadTestQuestions() async {
        print("🚀 [MultipleChoiceTestView] Starting to load test questions for test: \(testId)")
        print("🌐 [MultipleChoiceTestView] Fetching from database...")
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch questions from database
            let loadedQuestions = try await academyService.fetchTestQuestions(testId: testId)
            
            print("✅ [MultipleChoiceTestView] Successfully loaded \(loadedQuestions.count) question(s)")
            
            if loadedQuestions.isEmpty {
                print("❌ [MultipleChoiceTestView] No valid questions found")
                errorMessage = "No questions found in test"
            } else {
                questions = loadedQuestions
                print("🎉 [MultipleChoiceTestView] Test ready with \(questions.count) questions!")
                // Start the timer when questions are loaded
                startTimer()
            }
            
            isLoading = false
        } catch {
            print("❌ [MultipleChoiceTestView] Error loading test: \(error)")
            errorMessage = "Error loading test: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func startTimer() {
        stopTimer() // Stop any existing timer
        testStartTime = Date()
        timeRemaining = durationSeconds
        wasAutoSubmitted = false
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                // Time's up - auto submit
                self.stopTimer()
                self.wasAutoSubmitted = true
                self.submitTest()
            }
        }
        
        // Add timer to common run loop modes so it continues during scrolling
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func submitTest() {
        stopTimer() // Stop timer when submitting
        isLoading = true
        errorMessage = nil
        
        // If manually submitted, clear auto-submit flag
        if !wasAutoSubmitted {
            wasAutoSubmitted = false
        }
        
        // Calculate score
        var correctAnswers = 0
        for question in questions {
            if let selectedAnswer = selectedAnswers[question.id],
               selectedAnswer == question.correctAnswerIndex {
                correctAnswers += 1
            }
        }
        
        testScore = Int((Double(correctAnswers) / Double(questions.count)) * 100)
        passed = testScore >= passingScore
        
        // Save test results
        Task {
            await saveTestResults(score: testScore, passed: passed)
        }
    }
    
    private func saveTestResults(score: Int, passed: Bool) async {
        do {
            let supabase = SupabaseClient.shared.client
            
            // Prepare answers JSON
            var answersDict: [String: AnyJSON] = [:]
            for question in questions {
                if let selectedAnswer = selectedAnswers[question.id] {
                    answersDict["question_\(question.id.uuidString)"] = .integer(selectedAnswer)
                }
            }
            
            let testResult: [String: AnyJSON] = [
                "pilot_id": .string(pilotId.uuidString),
                "test_id": .string(testId.uuidString),
                "course_id": .string(course.id.uuidString),
                "score": .integer(score),
                "passed": .bool(passed),
                "answers": .object(answersDict),
                "attempt_number": .integer(1)
            ]
            
            try await supabase
                .from("test_results")
                .upsert(testResult, onConflict: "pilot_id,test_id")
                .execute()
            
            // If passed, award the course badge
            if passed {
                try await badgeService.awardBadge(
                    pilotId: pilotId,
                    courseId: course.id,
                    courseTitle: course.title,
                    courseCategory: course.category.rawValue,
                    provider: Badge.CourseProvider(rawValue: course.provider.rawValue) ?? .buzz
                )
                
                // Express Promotion: Auto-promote to Commander (only for UAS Pilot Course)
                // Requires BOTH conditions:
                // 1. Test passed (already satisfied - we're inside the `if passed` block)
                // 2. Step 1 completed (Lieutenant promotion verified)
                let uasCourseId = UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-ef1234567890")
                if course.id == uasCourseId {
                    let expressPromotionService = ExpressPromotionService()
                    let hasLieutenantPromotion = await expressPromotionService.hasLieutenantPromotion(pilotId: pilotId)
                    
                    if passed && hasLieutenantPromotion {
                        print("🚀 [MultipleChoiceTestView] Both conditions met - Test passed AND Lieutenant verified. Auto-promoting to Commander...")
                        do {
                            try await expressPromotionService.autoPromoteToCommander(pilotId: pilotId)
                            print("✅ [MultipleChoiceTestView] Successfully auto-promoted to Commander")
                        } catch {
                            print("⚠️ [MultipleChoiceTestView] Error auto-promoting to Commander: \(error.localizedDescription)")
                        }
                    } else if passed && !hasLieutenantPromotion {
                        print("ℹ️ [MultipleChoiceTestView] Test passed but Step 1 (Lieutenant promotion) not completed. Commander promotion skipped.")
                    }
                }
            }
            
            isLoading = false
            withAnimation {
                showResults = true
            }
        } catch {
            isLoading = false
            errorMessage = "Error saving test results: \(error.localizedDescription)"
        }
    }
}

// MARK: - Generic Test Results View

struct MultipleChoiceTestResultsView: View {
    let score: Int
    let passed: Bool
    let totalQuestions: Int
    let wasAutoSubmitted: Bool
    let testName: String
    let passingScore: Int
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Result Icon
            Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(passed ? .green : .red)
                .font(.system(size: 80))
            
            // Score
            VStack(spacing: 8) {
                Text("\(score)%")
                    .font(.system(size: 64))
                    .fontWeight(.bold)
                    .foregroundColor(passed ? .green : .red)
                
                Text(passed ? "Congratulations! You passed!" : "You did not pass")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if wasAutoSubmitted {
                    Text("Time's up! Your test was automatically submitted.")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Text(passed ? "You've completed the \(testName)!" : "You need \(passingScore)% to pass. Try again!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Score:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(score)%")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Status:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(passed ? "Passed" : "Failed")
                        .fontWeight(.semibold)
                        .foregroundColor(passed ? .green : .red)
                }
                
                HStack {
                    Text("Required:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(passingScore)%")
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Action Button
            Button(action: onDismiss) {
                Text(passed ? "Continue" : "Retake Test")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(passed ? Color.green : Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top)
    }
}
