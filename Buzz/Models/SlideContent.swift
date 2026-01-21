//
//  SlideContent.swift
//  Buzz
//
//  Model for slideshow content types
//

import Foundation

enum SlideContent: Identifiable, Equatable {
    case pdf(url: String, name: String)
    case image(url: String, name: String)
    case video(url: String, name: String)
    case question(QuestionData)
    
    var id: String {
        switch self {
        case .pdf(let url, _):
            return "pdf_\(url)"
        case .image(let url, _):
            return "image_\(url)"
        case .video(let url, _):
            return "video_\(url)"
        case .question(let data):
            return "question_\(data.id.uuidString)"
        }
    }
    
    var name: String {
        switch self {
        case .pdf(_, let name):
            return name
        case .image(_, let name):
            return name
        case .video(_, let name):
            return name
        case .question(let data):
            return data.questionText
        }
    }
    
    var type: String {
        switch self {
        case .pdf:
            return "PDF"
        case .image:
            return "Image"
        case .video:
            return "Video"
        case .question:
            return "Question"
        }
    }
    
    static func == (lhs: SlideContent, rhs: SlideContent) -> Bool {
        lhs.id == rhs.id
    }
}

struct QuestionData: Identifiable, Equatable {
    let id: UUID
    let questionText: String
    let options: [String]
    let correctAnswerIndex: Int
    let explanation: String?
    
    init(id: UUID = UUID(), questionText: String, options: [String], correctAnswerIndex: Int, explanation: String? = nil) {
        self.id = id
        self.questionText = questionText
        self.options = options
        self.correctAnswerIndex = correctAnswerIndex
        self.explanation = explanation
    }
    
    static func == (lhs: QuestionData, rhs: QuestionData) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Question Decoding Helper

extension QuestionData {
    /// Decode question from data URL format: data:application/json;base64,{base64data}
    /// This matches the storage format described in the Unit Material Questions Storage Guide
    static func decode(from url: String) -> QuestionData? {
        guard url.hasPrefix("data:application/json;base64,") else { return nil }

        let base64String = String(url.dropFirst("data:application/json;base64,".count))
        guard let data = Data(base64Encoded: base64String) else {
            print("Failed to decode base64 from question data URL")
            return nil
        }

        struct QuestionJSON: Codable {
            let question_text: String
            let options: [String]
            let correct_answer_index: Int
            let explanation: String?
        }

        do {
            let decoded = try JSONDecoder().decode(QuestionJSON.self, from: data)
            return QuestionData(
                questionText: decoded.question_text,
                options: decoded.options,
                correctAnswerIndex: decoded.correct_answer_index,
                explanation: decoded.explanation
            )
        } catch {
            print("Failed to decode question JSON: \(error)")
            return nil
        }
    }
    
    /// Create a fallback question when decoding fails
    static func fallback(name: String) -> QuestionData {
        return QuestionData(
            questionText: "Question data could not be loaded: \(name)",
            options: ["Continue"],
            correctAnswerIndex: 0,
            explanation: "Please continue to the next slide."
        )
    }
}
