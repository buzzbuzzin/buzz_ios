//
//  GroundSchoolTestView.swift
//  Buzz
//
//  Created for Ground School test after units 1-3
//

import SwiftUI
import Supabase

struct GroundSchoolTestView: View {
    let course: TrainingCourse
    let pilotId: UUID
    @Environment(\.dismiss) var dismiss
    @StateObject private var badgeService = BadgeService()
    @StateObject private var academyService = AcademyService()
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswers: [Int: Int] = [:]
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
    
    // Ground School Test ID (fixed UUID)
    private let groundSchoolTestId = UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-000000000001")!
    
    // Chart URLs mapping based on available files in Supabase storage
    private let chartURLsMapping: [Int: [URL]] = {
        let baseURL = "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/test-1/materials"
        return [
            12: [URL(string: "\(baseURL)/Q_12.png")!],
            15: [URL(string: "\(baseURL)/Q_15.png")!],
            22: [URL(string: "\(baseURL)/Q_22.png")!],
            23: [URL(string: "\(baseURL)/Q_23.png")!],
            25: [URL(string: "\(baseURL)/Q_25.png")!],
            26: [URL(string: "\(baseURL)/Q_26.png")!],
            27: [URL(string: "\(baseURL)/Q_27.png")!],
            28: [URL(string: "\(baseURL)/Q_28_1.png")!, URL(string: "\(baseURL)/Q_28_2.png")!],
            30: [URL(string: "\(baseURL)/Q_30.png")!],
            31: [URL(string: "\(baseURL)/Q_31.png")!],
            32: [URL(string: "\(baseURL)/Q_32.png")!],
            42: [URL(string: "\(baseURL)/Q_42.png")!],
            43: [URL(string: "\(baseURL)/Q_43.png")!],
            44: [URL(string: "\(baseURL)/Q_44.png")!],
            45: [URL(string: "\(baseURL)/Q_45.png")!],
            46: [URL(string: "\(baseURL)/Q_46.png")!],
            47: [URL(string: "\(baseURL)/Q_47.png")!],
            48: [URL(string: "\(baseURL)/Q_48.png")!],
            49: [URL(string: "\(baseURL)/Q_49.png")!],
            50: [URL(string: "\(baseURL)/Q_50.png")!],
            51: [URL(string: "\(baseURL)/Q_51.png")!],
            52: [URL(string: "\(baseURL)/Q_52.png")!],
            53: [URL(string: "\(baseURL)/Q_53.png")!]
        ]
    }()
    
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
    
    var body: some View {
        testContentView
            .navigationTitle("Ground School Test")
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
                        TestResultsView(
                            score: testScore,
                            passed: passed,
                            totalQuestions: questions.count,
                            onDismiss: {
                                dismiss()
                            }
                        )
                    } else {
                        // Test View
                        VStack(alignment: .leading, spacing: 20) {
                            // Progress Bar
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
                            .padding(.top)
                            
                            // Question
                            VStack(alignment: .leading, spacing: 16) {
                                Text(currentQuestion.question)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal)
                                
                                // Chart images (if available)
                                if let chartURLs = chartURLsMapping[currentQuestion.id], !chartURLs.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(chartURLs, id: \.self) { url in
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
        Button("Cancel", role: .cancel) { }
        Button("Exit", role: .destructive) {
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
        print("🚀 [GroundSchoolTestView] Starting to load test questions...")
        print("🌐 [GroundSchoolTestView] Fetching from backend storage...")
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch CSV directly from backend storage
            let csvURL = URL(string: "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/test-1/ground_school_exam_questions.csv")!
            
            print("🔄 [GroundSchoolTestView] Downloading CSV from: \(csvURL)")
            
            let (data, response) = try await URLSession.shared.data(from: csvURL)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("❌ [GroundSchoolTestView] Failed to download CSV - invalid response")
                errorMessage = "Failed to download test questions"
                isLoading = false
                return
            }
            
            print("✅ [GroundSchoolTestView] CSV downloaded successfully - \(data.count) bytes")
            
            guard let csvString = String(data: data, encoding: .utf8) else {
                print("❌ [GroundSchoolTestView] Failed to parse CSV as UTF-8")
                errorMessage = "Failed to parse test questions"
                isLoading = false
                return
            }
            
            // Parse CSV
            print("🔄 [GroundSchoolTestView] Parsing CSV data...")
            let lines = csvString.components(separatedBy: .newlines)
            print("📊 [GroundSchoolTestView] CSV has \(lines.count) line(s)")
            
            var loadedQuestions: [TestQuestion] = []
            
            // Skip header line (line 0)
            for (index, line) in lines.enumerated() where index > 0 {
                // Skip empty lines
                guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                
                // Parse CSV line - handle quoted fields with commas
                let fields = parseCSVLine(line)
                
                guard fields.count >= 7 else {
                    print("⚠️ [GroundSchoolTestView] Skipping line \(index) - not enough fields (\(fields.count))")
                    continue
                }
                
                // CSV format: problem_number, problem_area, problem_statement, option_1, option_2, option_3, correct_answer
                guard let questionNumber = Int(fields[0]),
                      let correctAnswerIndex = Int(fields[6]) else {
                    print("⚠️ [GroundSchoolTestView] Skipping line \(index) - invalid number format")
                    continue
                }
                
                let questionText = fields[2]
                let options = [fields[3], fields[4], fields[5]]
                
                // CSV uses 1-indexed (1, 2, 3), we need 0-indexed (0, 1, 2)
                let correctAnswer = correctAnswerIndex - 1
                
                loadedQuestions.append(TestQuestion(
                    id: questionNumber,
                    question: questionText,
                    options: options,
                    correctAnswer: correctAnswer
                ))
            }
            
            print("✅ [GroundSchoolTestView] Successfully parsed \(loadedQuestions.count) question(s)")
            
            if loadedQuestions.isEmpty {
                print("❌ [GroundSchoolTestView] No valid questions found")
                errorMessage = "No questions found in test"
            } else {
                questions = loadedQuestions
                print("🎉 [GroundSchoolTestView] Test ready with \(questions.count) questions!")
            }
            
            isLoading = false
        } catch {
            print("❌ [GroundSchoolTestView] Error loading test: \(error)")
            errorMessage = "Error loading test: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // Helper function to parse CSV line with quoted fields
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        
        // Add the last field
        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        
        return fields
    }
    
    private func submitTest() {
        isLoading = true
        errorMessage = nil
        
        // Calculate score
        var correctAnswers = 0
        for question in questions {
            if let selectedAnswer = selectedAnswers[question.id],
               selectedAnswer == question.correctAnswer {
                correctAnswers += 1
            }
        }
        
        testScore = Int((Double(correctAnswers) / Double(questions.count)) * 100)
        passed = testScore >= 70 // Passing score is 70%
        
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
                    answersDict["question_\(question.id)"] = .integer(selectedAnswer)
                }
            }
            
            let testResult: [String: AnyJSON] = [
                "pilot_id": .string(pilotId.uuidString),
                "test_id": .string(groundSchoolTestId.uuidString),
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
            
            // If passed, award the ground school badge
            if passed {
                try await badgeService.awardBadge(
                    pilotId: pilotId,
                    courseId: course.id,
                    courseTitle: "Ground School - UAS Pilot Course",
                    courseCategory: "Safety & Regulations",
                    provider: .buzz
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

// MARK: - Test Question Model

struct TestQuestion {
    let id: Int
    let question: String
    let options: [String]
    let correctAnswer: Int // Index of correct answer
}

// MARK: - Test Results View

struct TestResultsView: View {
    let score: Int
    let passed: Bool
    let totalQuestions: Int
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
                
                Text(passed ? "You've earned the Ground School badge!" : "You need 70% to pass. Try again!")
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
                    Text("70%")
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

