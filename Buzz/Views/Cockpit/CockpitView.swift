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
                    
                    // Menu Cards Grid
                    let columns = [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ]
                    
                    VStack(alignment: .leading, spacing: 24) {
                        // Flight Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Flight")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 16)
                            
                            LazyVGrid(columns: columns, spacing: 12) {
                                // Weather Card
                                NavigationLink(destination: WeatherView().environmentObject(authService)) {
                                    CockpitGridCard(
                                        title: "Weather",
                                        icon: "cloud.sun.fill",
                                        color: .cyan
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Transponder Card
                                NavigationLink(destination: TransponderView().environmentObject(authService)) {
                                    CockpitGridCard(
                                        title: "Transponder",
                                        icon: "antenna.radiowaves.left.and.right",
                                        color: .teal
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Flight Radar Card
                                NavigationLink(destination: FlightRadarView()) {
                                    CockpitGridCard(
                                        title: "Flight Radar",
                                        icon: "airplane.departure",
                                        color: .red
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // General Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("General")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 16)
                            
                            LazyVGrid(columns: columns, spacing: 12) {
                                // Leaderboard Card
                                NavigationLink(destination: LeaderboardView()) {
                                    CockpitGridCard(
                                        title: "Leaderboard",
                                        icon: "chart.bar.fill",
                                        color: .blue
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Revenue Card
                                NavigationLink(destination: RevenueDetailsView().environmentObject(authService)) {
                                    CockpitGridCard(
                                        title: "Revenue",
                                        icon: "dollarsign.circle.fill",
                                        color: .green
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Industry News Card
                                NavigationLink(destination: IndustryNewsView()) {
                                    CockpitGridCard(
                                        title: "News",
                                        icon: "newspaper.fill",
                                        color: .orange
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Availability Card
                                NavigationLink(destination: AvailabilityView().environmentObject(authService)) {
                                    CockpitGridCard(
                                        title: "Availability",
                                        icon: "calendar",
                                        color: .purple
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Progress Card
                                NavigationLink(destination: PilotProgressView().environmentObject(authService)) {
                                    CockpitGridCard(
                                        title: "Progress",
                                        icon: "chart.line.uptrend.xyaxis",
                                        color: .indigo
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // Community Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Community")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 16)
                            
                            LazyVGrid(columns: columns, spacing: 12) {
                                // TopGun Card
                                NavigationLink(destination: TopGunView().environmentObject(authService)) {
                                    CockpitGridCard(
                                        title: "TopGun",
                                        icon: "airplane.circle.fill",
                                        color: .red
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Cockpit Grid Card

struct CockpitGridCard: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(color)
            }
            
            // Title
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator).opacity(0.15), lineWidth: 0.5)
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
                            .padding(.bottom, 24)
                    }
                    
                    // Secondary Stories Grid
                    if newsArticles.count > 1 {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(Array(newsArticles.dropFirst().prefix(4))) { article in
                                SecondaryNewsCard(article: article)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                        
                        // Additional Stories (if more than 5)
                        if newsArticles.count > 5 {
                            VStack(spacing: 12) {
                                ForEach(Array(newsArticles.dropFirst(5))) { article in
                                    CompactNewsCard(article: article)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
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
                                .frame(maxWidth: .infinity)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 280)
                                .frame(maxWidth: .infinity)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 280)
                                .frame(maxWidth: .infinity)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
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
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
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
                                .frame(height: 140)
                                .frame(maxWidth: .infinity)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 140)
                                .frame(maxWidth: .infinity)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 140)
                                .frame(maxWidth: .infinity)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
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
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    
                    Spacer(minLength: 4)
                    
                    // Timestamp and Author with Menu dots
                    HStack(spacing: 4) {
                        Text(timeAgoString(from: article.publishedDate))
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text(article.author.prefix(10) + (article.author.count > 10 ? "..." : ""))
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
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
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
                                .frame(width: 90, height: 90)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 90, height: 90)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 90, height: 90)
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
                    
                    Spacer(minLength: 2)
                    
                    // Timestamp
                    Text(timeAgoString(from: article.publishedDate))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Menu dots
                VStack {
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(4)
                    }
                    Spacer()
                }
            }
            .padding(12)
            .frame(minHeight: 90)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
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

// MARK: - Availability View

struct AvailabilityView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    @StateObject private var blockoutService = AvailabilityBlockoutService()
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var showBlockoutSheet = false
    @State private var blockoutToEdit: AvailabilityBlockout? = nil
    @State private var editingBlockout: AvailabilityBlockout? = nil
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Blockout Button Section
                VStack(spacing: 12) {
                    Button(action: {
                        editingBlockout = nil
                        showBlockoutSheet = true
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.minus")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Block Out Availability")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Show existing blockouts count
                    if !blockoutService.blockouts.isEmpty {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.black)
                            Text("\(blockoutService.blockouts.count) blockout\(blockoutService.blockouts.count == 1 ? "" : "s") active")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                
                // Month Navigation
                HStack {
                    Button(action: {
                        withAnimation {
                            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Text(dateFormatter.string(from: currentMonth))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                // Calendar Grid
                VStack(spacing: 0) {
                    // Day Headers
                    HStack(spacing: 0) {
                        ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                            Text(day)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Calendar Days
                    let days = generateDaysForMonth()
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(Array(days.enumerated()), id: \.offset) { index, date in
                            if let date = date {
                                CalendarDayView(
                                    date: date,
                                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                    hasBooking: hasBookingOnDate(date),
                                    isBlocked: hasBlockoutOnDate(date),
                                    isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                                    isToday: calendar.isDateInToday(date),
                                    bookingCount: bookingCountForDate(date)
                                )
                                .onTapGesture {
                                    selectedDate = date
                                }
                            } else {
                                Color.clear
                                    .frame(height: 44)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Selected Date Details
                VStack(alignment: .leading, spacing: 16) {
                    // Show bookings for selected date
                    if hasBookingOnDate(selectedDate) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Bookings on \(formatDate(selectedDate))")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(bookingsForDate(selectedDate)) { booking in
                                NavigationLink(destination: BookingDetailView(booking: booking)) {
                                    BookingCalendarCard(booking: booking)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.top)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No bookings on \(formatDate(selectedDate))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                    }
                }
                
                // Active Blockouts Section
                if !blockoutService.blockouts.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Active Blockouts")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(blockoutService.blockouts) { blockout in
                            BlockoutCard(
                                blockout: blockout,
                                onEdit: {
                                    editingBlockout = blockout
                                },
                                onDelete: {
                                    Task {
                                        try? await blockoutService.deleteBlockout(blockoutId: blockout.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.top, 24)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Availability")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBlockoutSheet) {
            BlockoutCreationView(
                blockoutService: blockoutService,
                pilotId: authService.currentUser?.id ?? UUID(),
                blockoutToEdit: nil
            )
        }
        .sheet(item: $editingBlockout) { blockout in
            BlockoutCreationView(
                blockoutService: blockoutService,
                pilotId: authService.currentUser?.id ?? UUID(),
                blockoutToEdit: blockout
            )
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }
    
    private func loadData() async {
        guard let currentUser = authService.currentUser,
              let userProfile = authService.userProfile,
              userProfile.userType == .pilot else { return }
        
        async let bookingsTask = bookingService.fetchMyBookings(userId: currentUser.id, isPilot: true)
        async let blockoutsTask = blockoutService.fetchBlockouts(pilotId: currentUser.id)
        
        _ = try? await bookingsTask
        _ = try? await blockoutsTask
    }
    
    private func isDateBlocked(_ date: Date) -> Bool {
        return blockoutService.isDateBlocked(date)
    }
    
    private func hasBlockoutOnDate(_ date: Date) -> Bool {
        // Check if any blockout exists for this day (not just specific time)
        return blockoutService.blockouts.contains { blockout in
            let calendar = Calendar.current
            let dateStart = calendar.startOfDay(for: date)
            let dateEnd = calendar.date(byAdding: .day, value: 1, to: dateStart) ?? dateStart
            
            // For non-recurring blockouts
            if blockout.recurrenceType == .none {
                return blockout.startDate < dateEnd && blockout.endDate >= dateStart
            }
            
            // For recurring blockouts, check if this day matches the pattern
            // Check if date is within recurrence range
            if let recurrenceEndDate = blockout.recurrenceEndDate {
                guard date >= calendar.startOfDay(for: blockout.startDate) && date <= recurrenceEndDate else {
                    return false
                }
            } else {
                guard date >= calendar.startOfDay(for: blockout.startDate) else {
                    return false
                }
            }
            
            // Check if day matches recurrence pattern
            switch blockout.recurrenceType {
            case .none:
                return false
            case .daily:
                return true // Daily matches any day
            case .weekly:
                let startWeekday = calendar.component(.weekday, from: blockout.startDate)
                let dateWeekday = calendar.component(.weekday, from: date)
                return startWeekday == dateWeekday
            case .weekdays:
                let weekday = calendar.component(.weekday, from: date)
                return weekday >= 2 && weekday <= 6 // Monday to Friday
            case .weekends:
                let weekday = calendar.component(.weekday, from: date)
                return weekday == 1 || weekday == 7 // Saturday or Sunday
            case .monthly:
                let startDay = calendar.component(.day, from: blockout.startDate)
                let dateDay = calendar.component(.day, from: date)
                return startDay == dateDay
            }
        }
    }
    
    private func generateDaysForMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.end - 1) else {
            return []
        }
        
        var days: [Date?] = []
        var currentDate = monthFirstWeek.start
        
        // Add days from previous month to fill first week
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start) - 1
        for _ in 0..<firstWeekday {
            days.append(nil)
        }
        
        // Add days of current month
        while currentDate < monthLastWeek.end {
            if calendar.isDate(currentDate, equalTo: currentMonth, toGranularity: .month) {
                days.append(currentDate)
            } else {
                days.append(nil)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    private func hasBookingOnDate(_ date: Date) -> Bool {
        return bookingService.myBookings.contains { booking in
            guard let scheduledDate = booking.scheduledDate else { return false }
            return calendar.isDate(scheduledDate, inSameDayAs: date) &&
                   (booking.status == .accepted || booking.status == .completed)
        }
    }
    
    private func bookingCountForDate(_ date: Date) -> Int {
        return bookingService.myBookings.filter { booking in
            guard let scheduledDate = booking.scheduledDate else { return false }
            return calendar.isDate(scheduledDate, inSameDayAs: date) &&
                   (booking.status == .accepted || booking.status == .completed)
        }.count
    }
    
    private func bookingsForDate(_ date: Date) -> [Booking] {
        return bookingService.myBookings.filter { booking in
            guard let scheduledDate = booking.scheduledDate else { return false }
            return calendar.isDate(scheduledDate, inSameDayAs: date) &&
                   (booking.status == .accepted || booking.status == .completed)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Calendar Day View

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let hasBooking: Bool
    let isBlocked: Bool
    let isCurrentMonth: Bool
    let isToday: Bool
    let bookingCount: Int
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16, weight: isToday ? .bold : .regular))
                .foregroundColor(dayTextColor)
            
            if isBlocked {
                // Show gray indicator for blocked days
                Circle()
                    .fill(Color.gray)
                    .frame(width: 6, height: 6)
            } else if hasBooking {
                HStack(spacing: 2) {
                    ForEach(0..<min(bookingCount, 3), id: \.self) { _ in
                        Circle()
                            .fill(bookingDotColor)
                            .frame(width: 4, height: 4)
                    }
                    if bookingCount > 3 {
                        Text("+")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(bookingDotColor)
                    }
                }
            }
        }
        .frame(width: 44, height: 60)
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
    
    private var dayTextColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .blue
        } else if isCurrentMonth {
            return .primary
        } else {
            return .secondary.opacity(0.5)
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .blue
        } else if isBlocked {
            return .gray.opacity(0.3)
        } else if isToday {
            return .blue.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    private var bookingDotColor: Color {
        if isSelected {
            return .white
        } else {
            return .blue
        }
    }
}

// MARK: - Booking Calendar Card

struct BookingCalendarCard: View {
    let booking: Booking
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(booking.locationName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let specialization = booking.specialization {
                    Label(specialization.displayName, systemImage: specialization.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 16) {
                    if let scheduledDate = booking.scheduledDate {
                        Label(formatTime(scheduledDate), systemImage: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Label(
                        String(format: "$%.2f", NSDecimalNumber(decimal: booking.paymentAmount).doubleValue),
                        systemImage: "dollarsign.circle.fill"
                    )
                    .font(.caption)
                    .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private var statusColor: Color {
        switch booking.status {
        case .accepted:
            return .blue
        case .completed:
            return .green
        default:
            return .gray
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Pilot Progress View

struct PilotProgressView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var rankingService = RankingService()
    @StateObject private var bookingService = BookingService()
    @StateObject private var academyService = AcademyService()
    @State private var completedCourses: Int = 0
    @State private var noShowCount: Int = 0
    @State private var lateCount: Int = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if rankingService.isLoading {
                    ProgressView()
                        .padding(.top, 100)
                } else if let stats = rankingService.pilotStats {
                    // Current Rank Display
                    VStack(spacing: 16) {
                        Text("Current Rank")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(stats.tierName)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(tierColor(for: stats.tier))
                        
                        if stats.tier < 4 {
                            Text("Next Rank: \(nextRankName(for: stats.tier))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Maximum Rank Achieved!")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    .padding(.horizontal)
                    
                    // Progress to Next Rank
                    if stats.tier < 4 {
                        let progress = calculateRankProgress(stats: stats)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Progress to \(nextRankName(for: stats.tier))")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(progress.percentage))%")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            
                            // Progress Bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(height: 12)
                                        .cornerRadius(6)
                                    
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .blue.opacity(0.7)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * CGFloat(progress.percentage / 100), height: 12)
                                        .cornerRadius(6)
                                }
                            }
                            .frame(height: 12)
                            
                            // Requirements
                            VStack(alignment: .leading, spacing: 8) {
                                ProgressRequirementRow(
                                    icon: "airplane.departure",
                                    title: "Flight Hours",
                                    current: String(format: "%.1f", stats.totalFlightHours),
                                    required: String(format: "%.0f", progress.hoursNeeded),
                                    unit: "hours",
                                    isComplete: progress.hoursNeeded <= 0
                                )
                                
                                ProgressRequirementRow(
                                    icon: "checkmark.circle.fill",
                                    title: "Completed Bookings",
                                    current: "\(stats.completedBookings)",
                                    required: "\(progress.bookingsRequired)",
                                    unit: "bookings",
                                    isComplete: stats.completedBookings >= progress.bookingsRequired
                                )
                                
                                ProgressRequirementRow(
                                    icon: "graduationcap.fill",
                                    title: "Courses Completed",
                                    current: "\(completedCourses)",
                                    required: "\(progress.coursesRequired)",
                                    unit: "courses",
                                    isComplete: completedCourses >= progress.coursesRequired
                                )
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                    
                    // Penalties Section
                    if noShowCount > 0 || lateCount > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Penalties")
                                    .font(.headline)
                            }
                            
                            VStack(spacing: 8) {
                                if noShowCount > 0 {
                                    HStack {
                                        Text("No-Shows")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(noShowCount)")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.red)
                                    }
                                }
                                
                                if lateCount > 0 {
                                    HStack {
                                        Text("Late Arrivals")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(lateCount)")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                            
                            Text("Having no penalties is required for rank progression")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                            Text("No Penalties")
                                .font(.headline)
                            Text("Great job maintaining your schedule!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                } else {
                    Text("Unable to load progress data")
                        .foregroundColor(.secondary)
                        .padding(.top, 100)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }
    
    private func loadData() async {
        guard let currentUser = authService.currentUser,
              let userProfile = authService.userProfile,
              userProfile.userType == .pilot else { return }
        
        // Load pilot stats
        try? await rankingService.getPilotStats(pilotId: currentUser.id)
        
        // Load bookings to check for penalties
        try? await bookingService.fetchMyBookings(userId: currentUser.id, isPilot: true)
        
        // Calculate penalties
        calculatePenalties()
        
        // Load completed courses (for demo, we'll use a placeholder)
        // In production, this would fetch from course_enrollments table
        completedCourses = calculateCompletedCourses()
    }
    
    private func calculateRankProgress(stats: PilotStats) -> RankProgress {
        let currentTier = stats.tier
        let currentHours = stats.totalFlightHours
        
        var hoursNeeded: Double = 0
        var bookingsRequired: Int = 0
        var coursesRequired: Int = 0
        
        switch currentTier {
        case 0: // Ensign -> Sub Lieutenant
            hoursNeeded = max(0, 25 - currentHours)
            bookingsRequired = 5
            coursesRequired = 1
        case 1: // Sub Lieutenant -> Lieutenant
            hoursNeeded = max(0, 75 - currentHours)
            bookingsRequired = 15
            coursesRequired = 2
        case 2: // Lieutenant -> Commander
            hoursNeeded = max(0, 200 - currentHours)
            bookingsRequired = 30
            coursesRequired = 3
        case 3: // Commander -> Captain
            hoursNeeded = max(0, 500 - currentHours)
            bookingsRequired = 50
            coursesRequired = 5
        default: // Captain (max rank)
            hoursNeeded = 0
            bookingsRequired = 0
            coursesRequired = 0
        }
        
        let nextRankHours = nextRankFlightHoursRequirement(for: currentTier)
        let percentage = nextRankHours > 0 ? min(100, (currentHours / nextRankHours) * 100) : 100
        
        return RankProgress(
            hoursNeeded: hoursNeeded,
            bookingsRequired: bookingsRequired,
            coursesRequired: coursesRequired,
            percentage: percentage
        )
    }
    
    private func nextRankFlightHoursRequirement(for tier: Int) -> Double {
        switch tier {
        case 0: return 25
        case 1: return 75
        case 2: return 200
        case 3: return 500
        default: return 500
        }
    }
    
    private func nextRankName(for tier: Int) -> String {
        switch tier {
        case 0: return "Sub Lieutenant"
        case 1: return "Lieutenant"
        case 2: return "Commander"
        case 3: return "Captain"
        default: return "N/A"
        }
    }
    
    private func tierColor(for tier: Int) -> Color {
        switch tier {
        case 0: return .gray
        case 1: return .blue
        case 2: return .green
        case 3: return .orange
        case 4: return .purple
        default: return .gray
        }
    }
    
    private func calculatePenalties() {
        var noShows = 0
        var late = 0
        
        let now = Date()
        
        for booking in bookingService.myBookings {
            // No-show: Booking was accepted but cancelled after scheduled date
            // Only count if pilot was assigned (accepted the booking)
            if booking.status == .cancelled,
               booking.pilotId != nil,
               let scheduledDate = booking.scheduledDate,
               scheduledDate < now {
                noShows += 1
            }
            
            // Late: Booking completed significantly after scheduled date
            // Check if completion happened well after the scheduled time
            if booking.status == .completed,
               booking.pilotId != nil,
               let scheduledDate = booking.scheduledDate,
               let endDate = booking.endDate {
                // If there's an estimated flight hours, use that to determine if late
                if let estimatedHours = booking.estimatedFlightHours {
                    let expectedEndTime = scheduledDate.addingTimeInterval(estimatedHours * 3600)
                    let hoursLate = max(0, endDate.timeIntervalSince(expectedEndTime) / 3600)
                    // Consider late if completed more than 1 hour after expected completion
                    if hoursLate > 1 {
                        late += 1
                    }
                } else {
                    // Fallback: if no estimated hours, check if end date is significantly after scheduled date
                    let hoursBetween = endDate.timeIntervalSince(scheduledDate) / 3600
                    // If booking took more than 6 hours, might be late (depending on context)
                    // This is a simple heuristic
                    if hoursBetween > 6 {
                        late += 1
                    }
                }
            }
        }
        
        noShowCount = noShows
        lateCount = late
    }
    
    private func calculateCompletedCourses() -> Int {
        // For demo purposes, return a placeholder
        // In production, this would query course_enrollments with completion status
        // For now, we'll return 0 as courses aren't fully implemented yet
        return 0
    }
}

// MARK: - Rank Progress Model

struct RankProgress {
    let hoursNeeded: Double
    let bookingsRequired: Int
    let coursesRequired: Int
    let percentage: Double
}

// MARK: - Progress Requirement Row

struct ProgressRequirementRow: View {
    let icon: String
    let title: String
    let current: String
    let required: String
    let unit: String
    let isComplete: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isComplete ? .green : .blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Text(current)
                        .font(.headline)
                        .foregroundColor(isComplete ? .green : .primary)
                    
                    Text("/ \(required) \(unit)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Blockout Creation View

struct BlockoutCreationView: View {
    @ObservedObject var blockoutService: AvailabilityBlockoutService
    let pilotId: UUID
    let blockoutToEdit: AvailabilityBlockout?
    @Environment(\.dismiss) var dismiss
    
    @State private var label: String = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600) // Default 1 hour
    @State private var recurrenceType: RecurrenceType = .none
    @State private var recurrenceEndDate: Date? = nil
    @State private var showRecurrenceEndDate = false
    @State private var isCreating = false
    
    private var isEditMode: Bool {
        blockoutToEdit != nil
    }
    
    // Initialize state based on blockoutToEdit
    init(blockoutService: AvailabilityBlockoutService, pilotId: UUID, blockoutToEdit: AvailabilityBlockout?) {
        self.blockoutService = blockoutService
        self.pilotId = pilotId
        self.blockoutToEdit = blockoutToEdit
        
        // Pre-populate fields if editing
        if let blockout = blockoutToEdit {
            _label = State(initialValue: blockout.label ?? "")
            _startDate = State(initialValue: blockout.startDate)
            _endDate = State(initialValue: blockout.endDate)
            _recurrenceType = State(initialValue: blockout.recurrenceType)
            _recurrenceEndDate = State(initialValue: blockout.recurrenceEndDate)
            _showRecurrenceEndDate = State(initialValue: blockout.recurrenceEndDate != nil)
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.gray)
                    Text("Label")
                }) {
                    TextField("e.g., Vacation, Family Time, Maintenance", text: $label)
                        .textInputAutocapitalization(.words)
                }
                
                Section(header: HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                    Text("Date & Time")
                }) {
                    DatePicker("Starts", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    
                    DatePicker("Ends", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: HStack {
                    Image(systemName: "repeat")
                        .foregroundColor(.gray)
                    Text("Recurrence")
                }) {
                    Picker("Repeat", selection: $recurrenceType) {
                        ForEach(RecurrenceType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    if recurrenceType != .none {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.gray)
                                .font(.title3)
                            Toggle("Set End Date for Recurrence", isOn: $showRecurrenceEndDate)
                        }
                        
                        if showRecurrenceEndDate {
                            HStack {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .foregroundColor(.gray)
                                    .font(.title3)
                                DatePicker("Recurrence End Date", selection: Binding(
                                    get: { recurrenceEndDate ?? Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? Date() },
                                    set: { recurrenceEndDate = $0 }
                                ), displayedComponents: [.date])
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            await createBlockout()
                        }
                    }) {
                        HStack {
                            Spacer()
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(isEditMode ? "Edit Blockout" : "Create Blockout")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isCreating || endDate <= startDate ? Color.gray : Color.black)
                        .cornerRadius(10)
                    }
                    .disabled(isCreating || endDate <= startDate)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
            .navigationTitle(isEditMode ? "Edit Blockout" : "Block Out Availability")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Ensure fields are populated if editing (backup to init)
                if let blockout = blockoutToEdit {
                    label = blockout.label ?? ""
                    startDate = blockout.startDate
                    endDate = blockout.endDate
                    recurrenceType = blockout.recurrenceType
                    recurrenceEndDate = blockout.recurrenceEndDate
                    showRecurrenceEndDate = blockout.recurrenceEndDate != nil
                }
            }
        }
    }
    
    private func createBlockout() async {
        isCreating = true
        
        let finalRecurrenceEndDate = (recurrenceType != .none && showRecurrenceEndDate) ? recurrenceEndDate : nil
        
        do {
            if let blockout = blockoutToEdit {
                // Update existing blockout
                try await blockoutService.updateBlockout(
                    blockoutId: blockout.id,
                    label: label.isEmpty ? nil : label,
                    startDate: startDate,
                    endDate: endDate,
                    recurrenceType: recurrenceType,
                    recurrenceEndDate: finalRecurrenceEndDate
                )
            } else {
                // Create new blockout
                try await blockoutService.createBlockout(
                    pilotId: pilotId,
                    label: label.isEmpty ? nil : label,
                    startDate: startDate,
                    endDate: endDate,
                    recurrenceType: recurrenceType,
                    recurrenceEndDate: finalRecurrenceEndDate
                )
            }
            dismiss()
        } catch {
            // Error handling - could show an alert here
            print("Error \(isEditMode ? "updating" : "creating") blockout: \(error)")
        }
        
        isCreating = false
    }
}

// MARK: - Blockout Card

struct BlockoutCard: View {
    let blockout: AvailabilityBlockout
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showActionSheet = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        Button(action: {
            showActionSheet = true
        }) {
            HStack(spacing: 12) {
                // Blockout Indicator
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    if let label = blockout.label, !label.isEmpty {
                        Text(label)
                            .font(.headline)
                            .foregroundColor(.primary)
                    } else {
                        Text("Blocked Out")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Text("\(dateFormatter.string(from: blockout.startDate)) - \(dateFormatter.string(from: blockout.endDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if blockout.recurrenceType != .none {
                        HStack(spacing: 4) {
                            Image(systemName: "repeat")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(blockout.recurrenceType.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
        .confirmationDialog("Blockout Options", isPresented: $showActionSheet, titleVisibility: .visible) {
            Button("Edit") {
                onEdit()
            }
            Button("Remove", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}
