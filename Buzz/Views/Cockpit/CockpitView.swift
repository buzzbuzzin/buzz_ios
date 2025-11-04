//
//  CockpitView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct CockpitView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cockpit")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Manage your performance, revenue, and stay updated")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Menu Cards
                    VStack(spacing: 16) {
                        // Leaderboard Card
                        NavigationLink(destination: LeaderboardView()) {
                            CockpitMenuCard(
                                title: "Leaderboard",
                                description: "View rankings and compare your performance with other pilots",
                                icon: "chart.bar.fill",
                                color: .blue
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Revenue Card
                        NavigationLink(destination: RevenueDetailsView().environmentObject(authService)) {
                            CockpitMenuCard(
                                title: "Revenue",
                                description: "Track your earnings, tips, and revenue trends",
                                icon: "dollarsign.circle.fill",
                                color: .green
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Industry News Card
                        NavigationLink(destination: IndustryNewsView()) {
                            CockpitMenuCard(
                                title: "Industry News",
                                description: "Stay updated with the latest drone industry news and regulations",
                                icon: "newspaper.fill",
                                color: .orange
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Cockpit Menu Card

struct CockpitMenuCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator).opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Industry News View

struct IndustryNewsView: View {
    @State private var newsArticles: [NewsArticle] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Top Stories Header
                HStack {
                    Text("Top Stories")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.pink.opacity(0.9))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                if !newsArticles.isEmpty {
                    // Hero Story (first article)
                    if let heroArticle = newsArticles.first {
                        HeroNewsCard(article: heroArticle)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                    }
                    
                    // Secondary Stories Grid
                    if newsArticles.count > 1 {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 16) {
                            ForEach(Array(newsArticles.dropFirst().prefix(4))) { article in
                                SecondaryNewsCard(article: article)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                        
                        // Additional Stories (if more than 5)
                        if newsArticles.count > 5 {
                            VStack(spacing: 12) {
                                ForEach(Array(newsArticles.dropFirst(5))) { article in
                                    CompactNewsCard(article: article)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        }
                    }
                } else {
                    ProgressView()
                        .padding(.top, 100)
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Stories")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadNews()
        }
    }
    
    private func loadNews() async {
        // Simulate API call
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Demo news articles
        newsArticles = [
            NewsArticle(
                id: UUID(),
                title: "FAA Announces New Drone Regulations for Urban Air Mobility",
                summary: "The Federal Aviation Administration has unveiled updated regulations that will streamline commercial drone operations in urban environments, opening new opportunities for delivery services and infrastructure inspection.",
                content: """
                The Federal Aviation Administration (FAA) has announced significant updates to drone regulations that will reshape commercial drone operations across the United States. The new rules, set to take effect next quarter, focus on enabling safer and more efficient drone operations in urban environments.
                
                Key highlights of the new regulations include:
                
                • Expanded Beyond Visual Line of Sight (BVLOS) operations for certified pilots
                • Simplified approval process for drone delivery services
                • Enhanced safety requirements for operations near airports
                • New certification pathways for specialized commercial operations
                
                Industry experts predict these changes will accelerate the adoption of drone technology for delivery, inspection, and emergency response services. Major companies like Amazon Prime Air and Wing have already expressed support for the new framework.
                
                "This is a game-changer for commercial drone pilots," said FAA Administrator Jane Smith. "We're creating a regulatory environment that prioritizes safety while enabling innovation and economic growth."
                
                Pilots are encouraged to review the new regulations and complete any required training updates through certified training programs.
                """,
                publishedDate: Date().addingTimeInterval(-3600 * 2), // 2 hours ago
                author: "Sarah Martinez",
                category: "Regulations",
                imageUrl: "https://images.unsplash.com/photo-1473968512647-3e447244af8f?w=800&h=400&fit=crop",
                source: "FAA News",
                sourceIcon: nil
            ),
            NewsArticle(
                id: UUID(),
                title: "New Data Shows 1 in 4 Commercial Drone Pilots Earn Over $100K Annually",
                summary: "Recent industry survey reveals significant income growth for certified commercial drone pilots, with top earners reporting six-figure salaries.",
                content: """
                A comprehensive industry survey has revealed that commercial drone pilots are earning significantly more than previously reported. The data shows that 25% of certified commercial drone pilots are earning over $100,000 annually, with top performers in specialized fields like infrastructure inspection and agricultural surveying reporting even higher earnings.
                
                The survey, conducted by the Commercial Drone Alliance, polled over 5,000 certified pilots across various sectors including real estate, construction, agriculture, and emergency services.
                """,
                publishedDate: Date().addingTimeInterval(-3600 * 2), // 2 hours ago
                author: "Michael Chen",
                category: "Industry",
                imageUrl: "https://images.unsplash.com/photo-1581092160562-40aa08e78837?w=600&h=400&fit=crop",
                source: "Drone Industry News",
                sourceIcon: "✈️"
            ),
            NewsArticle(
                id: UUID(),
                title: "Drone Delivery Services Expand to 50 New Cities",
                summary: "Major delivery companies announce expansion plans, bringing drone delivery services to urban and suburban areas across the country.",
                content: """
                Leading drone delivery companies have announced plans to expand their services to 50 new cities in the next quarter. This expansion marks a significant milestone in the adoption of commercial drone technology for last-mile delivery.
                
                Companies including Wing, Zipline, and Amazon Prime Air are leading the charge, with each planning to deploy hundreds of drones to serve customers in both urban and suburban environments.
                """,
                publishedDate: Date().addingTimeInterval(-3600 * 3), // 3 hours ago
                author: "Emily Rodriguez",
                category: "Technology",
                imageUrl: "https://images.unsplash.com/photo-1573164713714-d95e436ab8d6?w=600&h=400&fit=crop",
                source: "TechDrone Weekly",
                sourceIcon: nil
            ),
            NewsArticle(
                id: UUID(),
                title: "New Safety Protocols Reduce Drone Accidents by 40%",
                summary: "Industry-wide adoption of enhanced safety protocols has resulted in a dramatic reduction in drone-related incidents.",
                content: """
                The commercial drone industry has seen a 40% reduction in accidents following the adoption of new safety protocols developed by the FAA and industry leaders. The protocols include mandatory pre-flight checklists, enhanced pilot training requirements, and real-time weather monitoring systems.
                
                "Safety is our top priority," said industry spokesperson John Williams. "These results demonstrate that when we work together as an industry, we can achieve remarkable improvements in safety outcomes."
                """,
                publishedDate: Date().addingTimeInterval(-3600 * 4), // 4 hours ago
                author: "David Kim",
                category: "Safety",
                imageUrl: "https://images.unsplash.com/photo-1536431311719-398b6704d4cc?w=600&h=400&fit=crop",
                source: "Aviation Safety Journal",
                sourceIcon: nil
            ),
            NewsArticle(
                id: UUID(),
                title: "Drone Racing League Announces $5M Championship Prize",
                summary: "Professional drone racing circuit announces record-breaking prize pool for upcoming championship season.",
                content: """
                The Drone Racing League (DRL) has announced a record-breaking $5 million prize pool for its upcoming championship season. The league has also expanded to include new venues and competition formats, attracting top pilots from around the world.
                
                "This is a game-changer for competitive drone racing," said DRL Commissioner Lisa Thompson. "We're seeing unprecedented interest from both pilots and sponsors, and this prize pool reflects the growing prestige of the sport."
                """,
                publishedDate: Date().addingTimeInterval(-3600 * 5), // 5 hours ago
                author: "Alex Thompson",
                category: "Sports",
                imageUrl: "https://images.unsplash.com/photo-1519904981063-b0cf448d479e?w=600&h=400&fit=crop",
                source: "Drone Sports Network",
                sourceIcon: nil
            ),
            NewsArticle(
                id: UUID(),
                title: "Agricultural Drone Technology Increases Crop Yields by 30%",
                summary: "Farmers report significant improvements in crop yields through the use of precision agriculture drones.",
                content: """
                A new study published in Agricultural Technology Today reveals that farms using precision agriculture drones have seen average crop yield increases of 30%. The drones enable farmers to monitor crop health, optimize irrigation, and identify problem areas earlier than traditional methods.
                
                "The technology has transformed how we manage our fields," said farmer Mark Johnson, who participated in the study. "We can now respond to issues in real-time, which has made a huge difference in our productivity."
                """,
                publishedDate: Date().addingTimeInterval(-3600 * 6), // 6 hours ago
                author: "Jennifer Lee",
                category: "Agriculture",
                imageUrl: "https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=600&h=400&fit=crop",
                source: "AgTech News",
                sourceIcon: nil
            )
        ]
    }
}

// MARK: - News Article Model

struct NewsArticle: Identifiable {
    let id: UUID
    let title: String
    let summary: String
    let content: String
    let publishedDate: Date
    let author: String
    let category: String
    let imageUrl: String?
    let source: String
    let sourceIcon: String? // Optional icon/emoji for source
}

// MARK: - Hero News Card

struct HeroNewsCard: View {
    let article: NewsArticle
    @State private var showDetail = false
    
    var body: some View {
        Button(action: {
            showDetail = true
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image
                if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 280)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 280)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 280)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .cornerRadius(0)
                }
                
                // Content Section
                VStack(alignment: .leading, spacing: 12) {
                    // Source
                    HStack(spacing: 6) {
                        if let icon = article.sourceIcon {
                            Text(icon)
                                .font(.caption)
                        }
                        Text(article.source.uppercased())
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 16)
                    
                    // Title
                    Text(article.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                    
                    // Category Button
                    HStack {
                        Text("More \(article.category.lowercased()) coverage")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        // Menu dots
                        Button(action: {}) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .padding(4)
                        }
                    }
                    .padding(.bottom, 4)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetail) {
            NewsArticleDetailView(article: article)
        }
    }
}

// MARK: - Secondary News Card

struct SecondaryNewsCard: View {
    let article: NewsArticle
    @State private var showDetail = false
    
    var body: some View {
        Button(action: {
            showDetail = true
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Image
                if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 160)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 160)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 160)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .cornerRadius(0)
                }
                
                // Content Section
                VStack(alignment: .leading, spacing: 8) {
                    // Source with optional icon
                    HStack(spacing: 4) {
                        if let icon = article.sourceIcon {
                            Text(icon)
                                .font(.caption2)
                        }
                        Text(article.source.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    .padding(.top, 10)
                    
                    // Title
                    Text(article.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    
                    // Timestamp and Author with Menu dots
                    HStack(spacing: 4) {
                        Text(timeAgoString(from: article.publishedDate))
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text(article.author.prefix(8) + (article.author.count > 8 ? "..." : ""))
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Menu dots
                        Button(action: {}) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .padding(4)
                        }
                    }
                    .padding(.bottom, 10)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetail) {
            NewsArticleDetailView(article: article)
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let timeInterval = Date().timeIntervalSince(date)
        let hours = Int(timeInterval / 3600)
        let minutes = Int(timeInterval / 60)
        
        if hours > 0 {
            return "\(hours)h ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Compact News Card

struct CompactNewsCard: View {
    let article: NewsArticle
    @State private var showDetail = false
    
    var body: some View {
        Button(action: {
            showDetail = true
        }) {
            HStack(spacing: 12) {
                // Image
                if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .cornerRadius(8)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Source
                    HStack(spacing: 4) {
                        if let icon = article.sourceIcon {
                            Text(icon)
                                .font(.caption2)
                        }
                        Text(article.source.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    
                    // Title
                    Text(article.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    // Timestamp
                    Text(timeAgoString(from: article.publishedDate))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Menu dots
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(6)
                }
            }
            .frame(height: 100)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetail) {
            NewsArticleDetailView(article: article)
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let timeInterval = Date().timeIntervalSince(date)
        let hours = Int(timeInterval / 3600)
        let minutes = Int(timeInterval / 60)
        
        if hours > 0 {
            return "\(hours)h ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - News Article Detail View

struct NewsArticleDetailView: View {
    let article: NewsArticle
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    // Image
                    if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 250)
                                    .overlay(ProgressView())
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 250)
                                    .clipped()
                            case .failure:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 250)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Source
                        HStack(spacing: 6) {
                            if let icon = article.sourceIcon {
                                Text(icon)
                                    .font(.caption)
                            }
                            Text(article.source.uppercased())
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        // Title
                        Text(article.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                        
                        // Author and Date
                        HStack {
                            Text(article.author)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Text(article.publishedDate, style: .relative)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        
                        Divider()
                        
                        // Content
                        Text(article.content)
                            .font(.body)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)
            }
            .navigationTitle("Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
