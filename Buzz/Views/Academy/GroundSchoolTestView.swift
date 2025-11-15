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
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswers: [Int: Int] = [:]
    @State private var showResults = false
    @State private var testScore = 0
    @State private var passed = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Sample test questions - In production, these should come from the database
    private let questions: [TestQuestion] = [
        TestQuestion(
            id: 1,
            question: "What is the maximum altitude for small unmanned aircraft operations under Part 107?",
            options: [
                "100 feet AGL",
                "400 feet AGL",
                "500 feet AGL",
                "1000 feet AGL"
            ],
            correctAnswer: 1 // Index 1 = "400 feet AGL"
        ),
        TestQuestion(
            id: 2,
            question: "What is the minimum visibility required for small UAS operations?",
            options: [
                "1 statute mile",
                "2 statute miles",
                "3 statute miles",
                "5 statute miles"
            ],
            correctAnswer: 2 // Index 2 = "3 statute miles"
        ),
        TestQuestion(
            id: 3,
            question: "When must a remote pilot in command conduct a preflight inspection?",
            options: [
                "Only before the first flight of the day",
                "Before each flight",
                "Only if the aircraft has been damaged",
                "Only for commercial operations"
            ],
            correctAnswer: 1 // Index 1 = "Before each flight"
        ),
        TestQuestion(
            id: 4,
            question: "What is required for operating a small UAS over people?",
            options: [
                "No special requirements",
                "A waiver from the FAA",
                "Written permission from property owners",
                "Only during daylight hours"
            ],
            correctAnswer: 1 // Index 1 = "A waiver from the FAA"
        ),
        TestQuestion(
            id: 5,
            question: "What is the minimum age requirement to obtain a remote pilot certificate?",
            options: [
                "16 years old",
                "18 years old",
                "21 years old",
                "No age requirement"
            ],
            correctAnswer: 1 // Index 1 = "18 years old"
        )
    ]
    
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
                    if showResults {
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
                if !showResults {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
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
                "course_id": .string(course.id.uuidString),
                "score": .integer(score),
                "passed": .bool(passed),
                "answers": .object(answersDict)
            ]
            
            try await supabase
                .from("ground_school_test_results")
                .upsert(testResult, onConflict: "pilot_id,course_id")
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

