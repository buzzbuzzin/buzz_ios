//
//  ProctoredMultipleChoiceTestView.swift
//  Buzz
//
//  Wrapper for MultipleChoiceTestView that handles proctored exams
//  Saves proctor name along with test results
//

import SwiftUI
import Supabase

struct ProctoredMultipleChoiceTestView: View {
    let testId: UUID
    let course: TrainingCourse
    let pilotId: UUID
    let testName: String
    let passingScore: Int
    let durationMinutes: Int
    let proctorName: String
    let onDismiss: () -> Void
    
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
    init(testId: UUID, course: TrainingCourse, pilotId: UUID, testName: String, passingScore: Int = 70, durationMinutes: Int = 60, proctorName: String, onDismiss: @escaping () -> Void) {
        self.testId = testId
        self.course = course
        self.pilotId = pilotId
        self.testName = testName
        self.passingScore = passingScore
        self.durationMinutes = durationMinutes
        self.proctorName = proctorName
        self.onDismiss = onDismiss
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
        NavigationStack {
            testContentView
                .background(Color(.systemBackground))
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
    }
    
    @ViewBuilder
    private var testContentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading {
                    loadingView
                } else if let errorMessage = errorMessage {
                    errorView(message: errorMessage)
                } else if questions.isEmpty {
                    emptyQuestionsView
                } else if showResults {
                    resultsView
                } else {
                    activeTestView
                }
            }
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading test questions...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            Text("Error Loading Test")
                .font(.title2)
                .fontWeight(.bold)
            Text(message)
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
    }
    
    @ViewBuilder
    private var emptyQuestionsView: some View {
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
    }
    
    @ViewBuilder
    private var resultsView: some View {
        MultipleChoiceTestResultsView(
            score: testScore,
            passed: passed,
            totalQuestions: questions.count,
            wasAutoSubmitted: wasAutoSubmitted,
            testName: testName,
            passingScore: passingScore,
            onDismiss: {
                onDismiss()
            }
        )
    }
    
    @ViewBuilder
    private var activeTestView: some View {
        proctorBanner
        timerAndProgressSection
        questionSection
        navigationButtons
        submitButton
        Spacer(minLength: 40)
    }
    
    @ViewBuilder
    private var proctorBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.badge.shield.checkmark.fill")
                .foregroundColor(.orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Proctored by")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(proctorName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var timerAndProgressSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(timeRemaining < 300 ? .red : .blue)
                        Text(timeRemainingFormatted)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(timeRemaining < 300 ? .red : .primary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet.clipboard")
                            .foregroundColor(.blue)
                        Text("\(answeredQuestionsCount)/\(questions.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Question \(currentQuestionIndex + 1) of \(questions.count)")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Spacer()
                
                if let area = currentQuestion.questionArea, !area.isEmpty {
                    Text(area)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                }
            }
            
            Text(currentQuestion.questionText)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            
            if !currentQuestion.imageUrls.isEmpty {
                questionImages
            }
            
            optionsList
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var questionImages: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(currentQuestion.imageUrls, id: \.self) { imageUrl in
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 200, height: 150)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 300, maxHeight: 200)
                                .cornerRadius(8)
                                .onTapGesture {
                                    selectedChartURL = URL(string: imageUrl)
                                    showChartViewer = true
                                }
                        case .failure:
                            Image(systemName: "photo")
                                .frame(width: 200, height: 150)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var optionsList: some View {
        VStack(spacing: 12) {
            ForEach(Array(currentQuestion.options.enumerated()), id: \.offset) { index, option in
                AnswerOptionButton(
                    optionLetter: String(UnicodeScalar(65 + index)!),
                    optionText: option,
                    isSelected: selectedAnswers[currentQuestion.id] == index,
                    action: {
                        selectedAnswers[currentQuestion.id] = index
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentQuestionIndex > 0 {
                Button(action: {
                    withAnimation {
                        currentQuestionIndex -= 1
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
            }
            
            if currentQuestionIndex < questions.count - 1 {
                Button(action: {
                    withAnimation {
                        currentQuestionIndex += 1
                    }
                }) {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var submitButton: some View {
        if answeredQuestionsCount == questions.count {
            Button(action: {
                submitTest()
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Submit Test")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
    
    @ToolbarContentBuilder
    private var testToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                if showResults {
                    onDismiss()
                } else {
                    showExitAlert = true
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        
        if !showResults && !isLoading && !questions.isEmpty {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showQuestionNavigator = true
                    }) {
                        Label("Question Navigator", systemImage: "list.bullet")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: {
                        showExitAlert = true
                    }) {
                        Label("Exit Test", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    private var exitAlert: some View {
        Group {
            Button("Cancel", role: .cancel) {}
            Button("Exit", role: .destructive) {
                stopTimer()
                onDismiss()
            }
        }
    }
    
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
    
    private var chartViewerSheet: some View {
        Group {
            if let url = selectedChartURL {
                ChartImageViewer(imageURL: url)
            }
        }
    }
    
    // Test management methods (same as MultipleChoiceTestView but with proctor_name)
    private func loadTestQuestions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let supabase = SupabaseClient.shared.client
            let response: [TestQuestion] = try await supabase
                .from("test_questions")
                .select()
                .eq("test_id", value: testId.uuidString)
                .order("question_number", ascending: true)
                .execute()
                .value
            
            questions = response
            
            if !questions.isEmpty {
                startTimer()
            }
            
            isLoading = false
        } catch {
            // Check if error is a cancellation (user navigated away during load)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("⚠️ [ProctoredTest] Load cancelled - user navigated away")
                return // Don't show error for cancellation
            }
            
            errorMessage = "Error loading test: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func startTimer() {
        stopTimer()
        testStartTime = Date()
        timeRemaining = durationSeconds
        wasAutoSubmitted = false
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.stopTimer()
                self.wasAutoSubmitted = true
                self.submitTest()
            }
        }
        
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func submitTest() {
        stopTimer()
        isLoading = true
        errorMessage = nil
        
        if !wasAutoSubmitted {
            wasAutoSubmitted = false
        }
        
        var correctAnswers = 0
        for question in questions {
            if let selectedAnswer = selectedAnswers[question.id],
               selectedAnswer == question.correctAnswerIndex {
                correctAnswers += 1
            }
        }
        
        testScore = Int((Double(correctAnswers) / Double(questions.count)) * 100)
        passed = testScore >= passingScore
        
        Task {
            await saveTestResults(score: testScore, passed: passed)
        }
    }
    
    private func saveTestResults(score: Int, passed: Bool) async {
        do {
            let supabase = SupabaseClient.shared.client
            
            var answersDict: [String: AnyJSON] = [:]
            for question in questions {
                if let selectedAnswer = selectedAnswers[question.id] {
                    answersDict["question_\(question.id.uuidString)"] = .integer(selectedAnswer)
                }
            }
            
            // Include proctor_name in test results
            let testResult: [String: AnyJSON] = [
                "pilot_id": .string(pilotId.uuidString),
                "test_id": .string(testId.uuidString),
                "course_id": .string(course.id.uuidString),
                "score": .integer(score),
                "passed": .bool(passed),
                "answers": .object(answersDict),
                "attempt_number": .integer(1),
                "proctor_name": .string(proctorName)  // Add proctor name
            ]
            
            try await supabase
                .from("test_results")
                .upsert(testResult, onConflict: "pilot_id,test_id")
                .execute()
            
            if passed {
                try await badgeService.awardBadge(
                    pilotId: pilotId,
                    courseId: course.id,
                    courseTitle: course.title,
                    courseCategory: course.category.rawValue,
                    provider: Badge.CourseProvider(rawValue: course.provider.rawValue) ?? .buzz
                )
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

// MARK: - Supporting Views

struct AnswerOptionButton: View {
    let optionLetter: String
    let optionText: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                        .frame(width: 32, height: 32)
                    
                    Text(optionLetter)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .primary)
                }
                
                Text(optionText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
