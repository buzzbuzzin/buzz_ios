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
        List {
            ForEach(newsArticles) { article in
                NewsArticleRow(article: article)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
        .navigationTitle("Industry News")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadNews()
        }
    }
    
    private func loadNews() async {
        // Simulate API call
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Demo news article
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
                publishedDate: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                author: "Drone Industry News",
                category: "Regulations",
                imageUrl: "https://images.unsplash.com/photo-1473968512647-3e447244af8f?w=800&h=400&fit=crop"
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
}

// MARK: - News Article Row

struct NewsArticleRow: View {
    let article: NewsArticle
    @State private var showDetail = false
    
    var body: some View {
        Button(action: {
            showDetail = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Image
                if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .cornerRadius(12)
                }
                
                // Category Badge
                Text(article.category)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                
                // Title
                Text(article.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                
                // Summary
                Text(article.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                
                // Author and Date
                HStack {
                    Text(article.author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(article.publishedDate, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetail) {
            NewsArticleDetailView(article: article)
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
                        // Category Badge
                        Text(article.category)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                        
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
                            
                            Text(article.publishedDate, style: .date)
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
