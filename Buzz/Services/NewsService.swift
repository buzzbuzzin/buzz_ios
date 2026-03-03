//
//  NewsService.swift
//  Buzz
//
//  Service for fetching drone industry news from FAA, Transport Canada, and DroneLIFE
//

import Foundation
import Combine
import Supabase

@MainActor
class NewsService: ObservableObject {
    @Published var faaArticles: [NewsArticle] = []
    @Published var tcArticles: [NewsArticle] = []
    @Published var globalArticles: [NewsArticle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseClient.shared.client

    // In-memory cache timestamps per source
    private var faaLastFetch: Date?
    private var tcLastFetch: Date?
    private var globalLastFetch: Date?
    private let cacheValiditySeconds: TimeInterval = 600 // 10 minutes

    // MARK: - Fetch Articles by Source

    func fetchArticles(source: NewsSource, forceRefresh: Bool = false) async {
        // Check demo mode
        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 300_000_000)
            loadDemoData(for: source)
            return
        }

        // Check cache validity
        if !forceRefresh,
           let lastFetch = lastFetchTime(for: source),
           Date().timeIntervalSince(lastFetch) < cacheValiditySeconds,
           !articles(for: source).isEmpty {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            struct NewsRequest: Codable {
                let source: String
            }

            let request = NewsRequest(source: source.rawValue)

            let response: DroneNewsResponse = try await supabase.functions
                .invoke("fetch-drone-news", options: FunctionInvokeOptions(
                    body: request
                ))

            if let error = response.error, !error.isEmpty {
                throw NewsError.apiError(message: error)
            }

            // Sort by published date, newest first
            let sorted = response.articles.sorted { $0.publishDate > $1.publishDate }

            switch source {
            case .faa:
                faaArticles = sorted
                faaLastFetch = Date()
            case .transportCanada:
                tcArticles = sorted
                tcLastFetch = Date()
            case .global:
                globalArticles = sorted
                globalLastFetch = Date()
            }

            isLoading = false

        } catch {
            isLoading = false
            let nsError = error as NSError
            // Don't report cancellation errors
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            errorMessage = error.localizedDescription
            print("NewsService error for \(source.displayName): \(error)")
        }
    }

    /// Get cached articles for a source
    func articles(for source: NewsSource) -> [NewsArticle] {
        switch source {
        case .faa: return faaArticles
        case .transportCanada: return tcArticles
        case .global: return globalArticles
        }
    }

    // MARK: - Private Helpers

    private func lastFetchTime(for source: NewsSource) -> Date? {
        switch source {
        case .faa: return faaLastFetch
        case .transportCanada: return tcLastFetch
        case .global: return globalLastFetch
        }
    }

    private func loadDemoData(for source: NewsSource) {
        let formatter = ISO8601DateFormatter()
        let demoArticles: [NewsArticle] = [
            NewsArticle(
                id: "demo-1",
                title: "New Drone Regulations Announced for Urban Air Mobility",
                summary: "Updated regulations will streamline commercial drone operations in urban environments, opening new opportunities for delivery services and infrastructure inspection.",
                url: "https://www.faa.gov/newsroom",
                publishedDate: formatter.string(from: Date().addingTimeInterval(-3600 * 2)),
                author: source.displayName,
                source: source.displayName,
                category: "Regulations",
                imageUrl: nil
            ),
            NewsArticle(
                id: "demo-2",
                title: "Commercial Drone Pilots See Significant Income Growth",
                summary: "Recent industry survey reveals that 25% of certified commercial drone pilots are earning over $100,000 annually.",
                url: "https://dronelife.com",
                publishedDate: formatter.string(from: Date().addingTimeInterval(-3600 * 4)),
                author: source.displayName,
                source: source.displayName,
                category: "Industry",
                imageUrl: nil
            ),
            NewsArticle(
                id: "demo-3",
                title: "Drone Delivery Services Expand to 50 New Cities",
                summary: "Leading drone delivery companies announce expansion plans, bringing drone delivery services to urban and suburban areas.",
                url: "https://dronelife.com",
                publishedDate: formatter.string(from: Date().addingTimeInterval(-3600 * 6)),
                author: source.displayName,
                source: source.displayName,
                category: "Technology",
                imageUrl: nil
            ),
            NewsArticle(
                id: "demo-4",
                title: "Enhanced Safety Protocols Reduce Drone Accidents by 40%",
                summary: "Industry-wide adoption of new safety protocols has resulted in a dramatic reduction in drone-related incidents.",
                url: "https://www.faa.gov/newsroom",
                publishedDate: formatter.string(from: Date().addingTimeInterval(-3600 * 8)),
                author: source.displayName,
                source: source.displayName,
                category: "Safety",
                imageUrl: nil
            ),
            NewsArticle(
                id: "demo-5",
                title: "Agricultural Drone Technology Increases Crop Yields",
                summary: "Farms using precision agriculture drones have seen average crop yield increases of 30% according to a new study.",
                url: "https://dronelife.com",
                publishedDate: formatter.string(from: Date().addingTimeInterval(-3600 * 10)),
                author: source.displayName,
                source: source.displayName,
                category: "Agriculture",
                imageUrl: nil
            ),
        ]

        switch source {
        case .faa: faaArticles = demoArticles
        case .transportCanada: tcArticles = demoArticles
        case .global: globalArticles = demoArticles
        }
    }
}

// MARK: - News Error

enum NewsError: LocalizedError {
    case apiError(message: String)

    var errorDescription: String? {
        switch self {
        case .apiError(let message): return message
        }
    }
}
