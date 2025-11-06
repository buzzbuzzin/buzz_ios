//
//  TaxDocument.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation

struct TaxDocument: Codable, Identifiable {
    let id: UUID
    let pilotId: UUID
    let documentType: TaxDocumentType
    let year: Int
    let fileUrl: String
    let issuedAt: Date
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case documentType = "document_type"
        case year
        case fileUrl = "file_url"
        case issuedAt = "issued_at"
        case createdAt = "created_at"
    }
}

enum TaxDocumentType: String, Codable {
    case w2 = "w2"
    case form1099 = "form_1099"
    case taxSummary = "tax_summary"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .w2: return "W-2"
        case .form1099: return "Form 1099"
        case .taxSummary: return "Tax Summary"
        case .other: return "Other"
        }
    }
}

