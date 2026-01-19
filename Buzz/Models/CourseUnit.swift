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
    let materialUrls: [String] // NEW: Array of URLs to course materials (PDFs, images, etc.)
    let materialNames: [String] // NEW: Array of names for course materials
    let materialTypes: [String] // NEW: Array of file types (pdf, jpeg, png, etc.)
    let pdfUrls: [String] // DEPRECATED: Kept for backward compatibility, use materialUrls instead
    let pdfNames: [String] // DEPRECATED: Kept for backward compatibility, use materialNames instead
    let sectionId: UUID?  // NEW: Reference to course_sections table
    let stepNumber: Int?  // DEPRECATED: Use sectionId instead
    let isMandatory: Bool // DEPRECATED: Use sectionId instead
    let orderIndex: Int
    let prerequisiteUnits: [Int]? // Unit numbers that must be completed before this unit
    let prerequisiteTests: [UUID]? // Test IDs that must be passed before this unit

    enum CodingKeys: String, CodingKey {
        case id
        case courseId = "course_id"
        case unitNumber = "unit_number"
        case title
        case description
        case content
        case materialUrls = "material_urls"
        case materialNames = "material_names"
        case materialTypes = "material_types"
        case pdfUrl = "pdf_url"
        case pdfNames = "pdf_names"
        case sectionId = "section_id"
        case stepNumber = "step_number"
        case isMandatory = "is_mandatory"
        case orderIndex = "order_index"
        case prerequisiteUnits = "prerequisite_units"
        case prerequisiteTests = "prerequisite_tests"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        courseId = try container.decode(UUID.self, forKey: .courseId)
        unitNumber = try container.decode(Int.self, forKey: .unitNumber)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        sectionId = try container.decodeIfPresent(UUID.self, forKey: .sectionId)
        stepNumber = try container.decodeIfPresent(Int.self, forKey: .stepNumber)
        isMandatory = try container.decodeIfPresent(Bool.self, forKey: .isMandatory) ?? false
        orderIndex = try container.decode(Int.self, forKey: .orderIndex)
        prerequisiteUnits = try container.decodeIfPresent([Int].self, forKey: .prerequisiteUnits)
        prerequisiteTests = try container.decodeIfPresent([UUID].self, forKey: .prerequisiteTests)

        // Handle new material fields (preferred)
        materialUrls = (try? container.decode([String].self, forKey: .materialUrls)) ?? []
        materialNames = (try? container.decode([String].self, forKey: .materialNames)) ?? []
        materialTypes = (try? container.decode([String].self, forKey: .materialTypes)) ?? []

        // Handle pdf_url as either JSON array or single string (for backward compatibility)
        if let pdfUrlArray = try? container.decode([String].self, forKey: .pdfUrl) {
            pdfUrls = pdfUrlArray
        } else if let pdfUrlString = try? container.decode(String.self, forKey: .pdfUrl), !pdfUrlString.isEmpty {
            pdfUrls = [pdfUrlString]
        } else {
            pdfUrls = []
        }

        // Handle pdf_names as JSON array (can be null)
        if let pdfNamesArray = try? container.decode([String].self, forKey: .pdfNames) {
            pdfNames = pdfNamesArray
        } else {
            pdfNames = []
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
        try container.encode(materialUrls, forKey: .materialUrls)
        try container.encode(materialNames, forKey: .materialNames)
        try container.encode(materialTypes, forKey: .materialTypes)
        try container.encodeIfPresent(sectionId, forKey: .sectionId)
        try container.encodeIfPresent(stepNumber, forKey: .stepNumber)
        try container.encode(isMandatory, forKey: .isMandatory)
        try container.encode(orderIndex, forKey: .orderIndex)
        try container.encode(pdfUrls, forKey: .pdfUrl)
        try container.encode(pdfNames, forKey: .pdfNames)
        try container.encodeIfPresent(prerequisiteUnits, forKey: .prerequisiteUnits)
        try container.encodeIfPresent(prerequisiteTests, forKey: .prerequisiteTests)
    }

    // MARK: - Computed Properties

    /// Returns the materials for this unit, preferring new format but falling back to legacy PDF fields
    var materials: [CourseMaterial] {
        // If we have new material data, use it
        if !materialUrls.isEmpty {
            return zip(materialUrls, zip(materialNames, materialTypes)).enumerated().map { index, data in
                let (url, (name, type)) = data
                return CourseMaterial(
                    index: index,
                    url: url,
                    name: name.isEmpty ? "Material \(index + 1)" : name,
                    type: type.isEmpty ? "pdf" : type // Default to PDF for backward compatibility
                )
            }
        }

        // Fall back to legacy PDF data
        if !pdfUrls.isEmpty {
            return zip(pdfUrls, pdfNames).enumerated().map { index, data in
                let (url, name) = data
                return CourseMaterial(
                    index: index,
                    url: url,
                    name: name.isEmpty ? "Material \(index + 1)" : name,
                    type: "pdf" // Legacy data is assumed to be PDFs
                )
            }
        }

        return []
    }
}

// MARK: - Supporting Types

struct CourseMaterial {
    let index: Int
    let url: String
    let name: String
    let type: String

    var isPDF: Bool { type.lowercased() == "pdf" }
    var isImage: Bool { ["jpeg", "jpg", "png", "gif", "webp"].contains(type.lowercased()) }

    var fileViewerTypeString: String {
        if isPDF {
            return "pdf"
        } else {
            return "image"
        }
    }

    var iconName: String {
        if isPDF {
            return "doc.fill"
        } else if isImage {
            return "photo.fill"
        } else {
            return "doc.fill" // Fallback
        }
    }
}

