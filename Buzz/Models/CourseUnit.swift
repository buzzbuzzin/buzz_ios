//
//  CourseUnit.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/14/25.
//

import Foundation

struct CourseUnit: Identifiable, Codable {
    let id: UUID
    let courseId: UUID
    let unitNumber: Int
    let title: String
    let description: String?
    let content: String?
    let pdfUrls: [String] // Array of URLs to PDF course materials (multiple modules per unit)
    let stepNumber: Int?
    let isMandatory: Bool
    let orderIndex: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case courseId = "course_id"
        case unitNumber = "unit_number"
        case title
        case description
        case content
        case pdfUrl = "pdf_url"
        case stepNumber = "step_number"
        case isMandatory = "is_mandatory"
        case orderIndex = "order_index"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        courseId = try container.decode(UUID.self, forKey: .courseId)
        unitNumber = try container.decode(Int.self, forKey: .unitNumber)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        stepNumber = try container.decodeIfPresent(Int.self, forKey: .stepNumber)
        isMandatory = try container.decode(Bool.self, forKey: .isMandatory)
        orderIndex = try container.decode(Int.self, forKey: .orderIndex)
        
        // Handle pdf_url as either JSON array or single string (for backward compatibility)
        if let pdfUrlArray = try? container.decode([String].self, forKey: .pdfUrl) {
            pdfUrls = pdfUrlArray
        } else if let pdfUrlString = try? container.decode(String.self, forKey: .pdfUrl), !pdfUrlString.isEmpty {
            pdfUrls = [pdfUrlString]
        } else {
            pdfUrls = []
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(courseId, forKey: .courseId)
        try container.encode(unitNumber, forKey: .unitNumber)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(stepNumber, forKey: .stepNumber)
        try container.encode(isMandatory, forKey: .isMandatory)
        try container.encode(orderIndex, forKey: .orderIndex)
        try container.encode(pdfUrls, forKey: .pdfUrl)
    }
}

