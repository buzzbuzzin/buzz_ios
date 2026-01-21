//
//  QuestionSlideView.swift
//  Buzz
//
//  Interactive quiz question slide with feedback
//

import SwiftUI

struct QuestionSlideView: View {
    let questionData: QuestionData
    let onComplete: () -> Void
    
    @State private var selectedAnswer: Int?
    @State private var showFeedback: Bool = false
    @State private var isCorrect: Bool = false
    
    private let optionLabels = ["A", "B", "C", "D", "E", "F", "G", "H"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Quiz Question")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Question Text
                VStack(alignment: .leading, spacing: 12) {
                    Text(questionData.questionText)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Options
                VStack(spacing: 12) {
                    ForEach(Array(questionData.options.enumerated()), id: \.offset) { index, option in
                        OptionButton(
                            label: optionLabels[safe: index] ?? "\(index + 1)",
                            text: option,
                            isSelected: selectedAnswer == index,
                            showFeedback: showFeedback,
                            isCorrect: index == questionData.correctAnswerIndex,
                            action: {
                                if !showFeedback {
                                    selectedAnswer = index
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                
                // Submit/Retry Button
                if !showFeedback {
                    Button(action: handleSubmit) {
                        HStack {
                            Text("Submit Answer")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedAnswer != nil ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(selectedAnswer == nil)
                    .padding(.horizontal)
                } else if !isCorrect {
                    Button(action: handleRetry) {
                        HStack {
                            Text("Try Again")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // Feedback Section
                if showFeedback {
                    VStack(alignment: .leading, spacing: 16) {
                        // Result Header
                        HStack {
                            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(isCorrect ? .green : .red)
                            Text(isCorrect ? "Correct!" : "Incorrect")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(isCorrect ? .green : .red)
                            Spacer()
                        }
                        
                        // Explanation
                        if let explanation = questionData.explanation, !explanation.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Explanation")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Text(explanation)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        // Correct Answer (if incorrect)
                        if !isCorrect {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Correct Answer")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Text("\(optionLabels[safe: questionData.correctAnswerIndex] ?? ""): \(questionData.options[safe: questionData.correctAnswerIndex] ?? "")")
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding()
                    .background(isCorrect ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.vertical)
        }
        .background(Color(.systemBackground))
    }
    
    private func handleSubmit() {
        guard let selected = selectedAnswer else { return }
        
        isCorrect = selected == questionData.correctAnswerIndex
        showFeedback = true
        
        print("📝 Answer submitted: \(isCorrect ? "Correct ✓" : "Incorrect ✗")")
        
        if isCorrect {
            // Auto-complete after short delay to show feedback
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                onComplete()
            }
        }
    }
    
    private func handleRetry() {
        selectedAnswer = nil
        showFeedback = false
        isCorrect = false
        print("🔁 Retrying question")
    }
}

// MARK: - Option Button

struct OptionButton: View {
    let label: String
    let text: String
    let isSelected: Bool
    let showFeedback: Bool
    let isCorrect: Bool
    let action: () -> Void
    
    private var backgroundColor: Color {
        if showFeedback {
            if isCorrect {
                return Color.green.opacity(0.2)
            } else if isSelected {
                return Color.red.opacity(0.2)
            } else {
                return Color(.systemGray6)
            }
        } else if isSelected {
            return Color.blue.opacity(0.2)
        } else {
            return Color(.systemGray6)
        }
    }
    
    private var borderColor: Color {
        if showFeedback {
            if isCorrect {
                return Color.green
            } else if isSelected {
                return Color.red
            } else {
                return Color.clear
            }
        } else if isSelected {
            return Color.blue
        } else {
            return Color.clear
        }
    }
    
    private var iconName: String? {
        if showFeedback {
            if isCorrect {
                return "checkmark.circle.fill"
            } else if isSelected {
                return "xmark.circle.fill"
            }
        }
        return nil
    }
    
    private var iconColor: Color {
        if isCorrect {
            return .green
        } else {
            return .red
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Label (A, B, C, D)
                ZStack {
                    Circle()
                        .fill(isSelected && !showFeedback ? Color.blue : Color(.systemGray5))
                        .frame(width: 36, height: 36)
                    Text(label)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected && !showFeedback ? .white : .primary)
                }
                
                // Option Text
                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                // Feedback Icon
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.title3)
                        .foregroundColor(iconColor)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(showFeedback)
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
