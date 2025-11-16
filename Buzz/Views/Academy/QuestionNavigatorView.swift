import SwiftUI

struct QuestionNavigatorView: View {
    let questions: [TestQuestion]
    let selectedAnswers: [Int: Int]
    @Binding var currentQuestionIndex: Int
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // Grid layout
    let columns = [
        GridItem(.adaptive(minimum: 60))
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Progress Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test Progress")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 30) {
                            ProgressSummaryItem(
                                count: selectedAnswers.count,
                                total: questions.count,
                                label: "Answered",
                                color: .blue
                            )
                            
                            ProgressSummaryItem(
                                count: questions.count - selectedAnswers.count,
                                total: questions.count,
                                label: "Remaining",
                                color: .gray
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Legend
                    HStack(spacing: 20) {
                        LegendItem(color: .blue, label: "Answered")
                        LegendItem(color: .gray.opacity(0.3), label: "Unanswered")
                        LegendItem(color: .green, label: "Current")
                    }
                    .padding(.horizontal)
                    
                    // Question Grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                            QuestionGridItem(
                                questionNumber: index + 1,
                                isAnswered: selectedAnswers[question.id] != nil,
                                isCurrent: index == currentQuestionIndex,
                                onTap: {
                                    currentQuestionIndex = index
                                    onDismiss()
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Questions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct QuestionGridItem: View {
    let questionNumber: Int
    let isAnswered: Bool
    let isCurrent: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text("\(questionNumber)")
                .font(.headline)
                .foregroundColor(isCurrent ? .white : (isAnswered ? .white : .primary))
                .frame(width: 60, height: 60)
                .background(
                    isCurrent
                        ? Color.green
                        : (isAnswered ? Color.blue : Color.gray.opacity(0.3))
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCurrent ? Color.green : Color.clear, lineWidth: 3)
                )
        }
    }
}

struct ProgressSummaryItem: View {
    let count: Int
    let total: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(count)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text("/ \(total)")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 24, height: 24)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    QuestionNavigatorView(
        questions: [
            TestQuestion(id: 1, question: "Test 1", options: ["A", "B", "C"], correctAnswer: 0),
            TestQuestion(id: 2, question: "Test 2", options: ["A", "B", "C"], correctAnswer: 1),
            TestQuestion(id: 3, question: "Test 3", options: ["A", "B", "C"], correctAnswer: 2),
            TestQuestion(id: 4, question: "Test 4", options: ["A", "B", "C"], correctAnswer: 0),
            TestQuestion(id: 5, question: "Test 5", options: ["A", "B", "C"], correctAnswer: 1),
        ],
        selectedAnswers: [1: 0, 2: 1],
        currentQuestionIndex: .constant(0),
        onDismiss: {}
    )
}

