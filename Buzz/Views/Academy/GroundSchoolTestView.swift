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
    
    // Ground School Test ID (fixed UUID)
    private let groundSchoolTestId = UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-000000000001")!
    
    var currentQuestion: TestQuestion {
        questions[currentQuestionIndex]
    }
    
    var progress: Double {
        Double(currentQuestionIndex + 1) / Double(questions.count)
    }
    
    var body: some View {
        NavigationView {
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
                                    Text("\(Int(progress * 100))%")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                
                                ProgressView(value: progress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            
                            // Question
                            VStack(alignment: .leading, spacing: 16) {
                                Text(currentQuestion.question)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal)
                                
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
                                                
                                                Spacer()
                                                
                                                if selectedAnswers[currentQuestion.id] == index {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.blue)
                                                        .font(.title3)
                                                } else {
                                                    Image(systemName: "circle")
                                                        .foregroundColor(.secondary)
                                                        .font(.title3)
                                                }
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
                            HStack(spacing: 16) {
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
                                            selectedAnswers[currentQuestion.id] != nil
                                                ? Color.blue
                                                : Color.gray
                                        )
                                        .cornerRadius(12)
                                }
                                .disabled(selectedAnswers[currentQuestion.id] == nil)
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
            .navigationTitle("Ground School Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !showResults && !isLoading {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .task {
                await loadTestQuestions()
            }
        }
    }
    
    private func loadTestQuestions() async {
        print("🚀 [GroundSchoolTestView] Starting to load test questions...")
        print("🎯 [GroundSchoolTestView] Test ID: \(groundSchoolTestId)")
        print("📚 [GroundSchoolTestView] Course ID: \(course.id)")
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch the test from database
            print("🔄 [GroundSchoolTestView] Fetching course tests...")
            let tests = try await academyService.fetchCourseTests(courseId: course.id)
            print("📊 [GroundSchoolTestView] Found \(tests.count) test(s) for this course")
            
            guard let groundSchoolTest = tests.first(where: { $0.id == groundSchoolTestId }) else {
                print("❌ [GroundSchoolTestView] Ground School Test not found!")
                print("📋 [GroundSchoolTestView] Available test IDs: \(tests.map { $0.id })")
                errorMessage = "Ground School Test not found"
                isLoading = false
                return
            }
            
            print("✅ [GroundSchoolTestView] Found Ground School Test: \(groundSchoolTest.testName)")
            
            // Parse questions from the test
            print("🔄 [GroundSchoolTestView] Fetching questions from database...")
            let supabase = SupabaseClient.shared.client
            let response = try await supabase
                .from("course_tests")
                .select("questions")
                .eq("id", value: groundSchoolTestId.uuidString)
                .execute()
            
            let data = response.data
            print("📦 [GroundSchoolTestView] Response data size: \(data.count) bytes")
            
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                print("❌ [GroundSchoolTestView] Failed to parse response as JSON array")
                errorMessage = "Failed to load test questions"
                isLoading = false
                return
            }
            
            print("📊 [GroundSchoolTestView] JSON array has \(jsonArray.count) item(s)")
            
            guard let firstResult = jsonArray.first else {
                print("❌ [GroundSchoolTestView] JSON array is empty")
                errorMessage = "Failed to load test questions"
                isLoading = false
                return
            }
            
            guard let questionsData = firstResult["questions"] as? [String: Any] else {
                print("❌ [GroundSchoolTestView] No 'questions' field in response")
                print("📋 [GroundSchoolTestView] Available keys: \(firstResult.keys)")
                errorMessage = "Failed to load test questions"
                isLoading = false
                return
            }
            
            guard let questionsArray = questionsData["questions"] as? [[String: Any]] else {
                print("❌ [GroundSchoolTestView] 'questions' is not an array")
                errorMessage = "Failed to load test questions"
                isLoading = false
                return
            }
            
            print("📚 [GroundSchoolTestView] Found \(questionsArray.count) question(s)")
            
            // Parse questions
            var loadedQuestions: [TestQuestion] = []
            for (index, questionDict) in questionsArray.enumerated() {
                guard let id = questionDict["id"] as? Int,
                      let question = questionDict["question"] as? String,
                      let options = questionDict["options"] as? [String],
                      let correctAnswer = questionDict["correctAnswer"] as? Int else {
                    print("⚠️ [GroundSchoolTestView] Skipping question \(index) - invalid format")
                    continue
                }
                
                loadedQuestions.append(TestQuestion(
                    id: id,
                    question: question,
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

