//
//  NewsArticle.swift
//  Buzz
//
//  Model for drone industry news articles fetched from external sources
//

import Foundation

/// Represents a news article from external sources (FAA, Transport Canada, DroneLIFE)
struct NewsArticle: Identifiable, Codable {
    let id: String
    let title: String
    let summary: String
    let url: String
    let publishedDate: String
    let author: String
    let source: String
    let category: String
    let imageUrl: String?

    /// Parsed publication date from ISO 8601 string
    var publishDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: publishedDate) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: publishedDate) { return date }
        return Date()
    }
}

/// Response envelope from the fetch-drone-news edge function
struct DroneNewsResponse: Codable {
    let articles: [NewsArticle]
    let source: String
    let fetchedAt: String?
    let error: String?
}

/// Enum for news source tabs
enum NewsSource: String, CaseIterable {
    case faa = "faa"
    case transportCanada = "transport_canada"
    case global = "global"

    var displayName: String {
        switch self {
        case .faa: return "FAA"
        case .transportCanada: return "Transport Canada"
        case .global: return "Global"
        }
    }

    var icon: String {
        switch self {
        case .faa: return "🇺🇸"
        case .transportCanada: return "🇨🇦"
        case .global: return "globe"
        }
    }

    var accentColor: String {
        switch self {
        case .faa: return "blue"
        case .transportCanada: return "red"
        case .global: return "purple"
        }
    }
}
