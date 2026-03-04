//
//  IndustryNewsView.swift
//  Buzz
//
//  Real-time drone industry news from FAA, Transport Canada, and global sources
//

import SwiftUI
import SafariServices

// MARK: - Industry News View

struct IndustryNewsView: View {
    @StateObject private var newsService = NewsService()
    @State private var selectedSource: NewsSource = .faa
    @State private var selectedArticleURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            // Source Picker
            Picker("Source", selection: $selectedSource) {
                ForEach(NewsSource.allCases, id: \.self) { source in
                    Text(source.displayName)
                        .tag(source)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Content
            ScrollView {
                VStack(spacing: 0) {
                    // Source Header
                    HStack(spacing: 8) {
                        if selectedSource == .global {
                            Image(systemName: selectedSource.icon)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(sourceColor)
                        } else {
                            Text(selectedSource.icon)
                                .font(.system(size: 24))
                        }
                        Text(selectedSource.displayName + " News")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    let currentArticles = newsService.articles(for: selectedSource)

                    if newsService.isLoading && currentArticles.isEmpty {
                        loadingView
                    } else if let error = newsService.errorMessage, currentArticles.isEmpty {
                        errorView(error)
                    } else if currentArticles.isEmpty {
                        emptyView
                    } else {
                        // Show refresh error banner when stale articles are displayed
                        if let error = newsService.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Refresh failed: \(error)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    Task {
                                        await newsService.fetchArticles(source: selectedSource, forceRefresh: true)
                                    }
                                } label: {
                                    Text("Retry")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(sourceColor)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                        articleListView(currentArticles)
                    }
                }
            }
            .refreshable {
                await newsService.fetchArticles(source: selectedSource, forceRefresh: true)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Industry News")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await newsService.fetchArticles(source: selectedSource)
        }
        .onChange(of: selectedSource) { _, _ in
            Task {
                await newsService.fetchArticles(source: selectedSource)
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedArticleURL != nil },
            set: { if !$0 { selectedArticleURL = nil } }
        )) {
            if let url = selectedArticleURL {
                SafariView(url: url)
            }
        }
    }

    // MARK: - Source Color

    private var sourceColor: Color {
        switch selectedSource {
        case .faa: return .blue
        case .transportCanada: return .red
        case .global: return .purple
        }
    }

    // MARK: - Article List

    @ViewBuilder
    private func articleListView(_ articles: [NewsArticle]) -> some View {
        // Hero Story (first article)
        if let heroArticle = articles.first {
            NewsHeroCard(article: heroArticle, accentColor: sourceColor) {
                if let url = URL(string: heroArticle.url) {
                    selectedArticleURL = url
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }

        // Secondary Stories Grid (articles 2-5)
        if articles.count > 1 {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(Array(articles.dropFirst().prefix(4))) { article in
                    NewsSecondaryCard(article: article) {
                        if let url = URL(string: article.url) {
                            selectedArticleURL = url
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }

        // Compact Stories (articles 6+)
        if articles.count > 5 {
            VStack(spacing: 12) {
                ForEach(Array(articles.dropFirst(5))) { article in
                    NewsCompactCard(article: article) {
                        if let url = URL(string: article.url) {
                            selectedArticleURL = url
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading \(selectedSource.displayName) news...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 100)
    }

    @ViewBuilder
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("Unable to Load News")
                .font(.headline)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task {
                    await newsService.fetchArticles(source: selectedSource, forceRefresh: true)
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(sourceColor)
                .cornerRadius(20)
            }
        }
        .padding(.top, 80)
        .padding(.horizontal, 32)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            Text("No Articles Available")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Pull down to refresh")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.top, 100)
    }
}

// MARK: - News Time Ago Helper

private func newsTimeAgo(from date: Date) -> String {
    let timeInterval = Date().timeIntervalSince(date)
    let days = Int(timeInterval / 86400)
    let hours = Int(timeInterval / 3600)
    let minutes = Int(timeInterval / 60)

    if days > 0 {
        return "\(days)d ago"
    } else if hours > 0 {
        return "\(hours)h ago"
    } else if minutes > 0 {
        return "\(minutes)m ago"
    } else {
        return "Just now"
    }
}

// MARK: - Hero News Card

struct NewsHeroCard: View {
    let article: NewsArticle
    var accentColor: Color = .blue
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image or Placeholder
                if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            placeholderImage(height: 220)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 220)
                                .frame(maxWidth: .infinity)
                                .clipped()
                        case .failure:
                            placeholderGradient(height: 220)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    placeholderGradient(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Content
                VStack(alignment: .leading, spacing: 10) {
                    // Source badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 8, height: 8)
                        Text(article.source.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                    }
                    .padding(.top, 14)

                    // Title
                    Text(article.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)

                    // Summary
                    Text(article.summary)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Footer
                    HStack {
                        Text(newsTimeAgo(from: article.publishDate))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        if !article.author.isEmpty {
                            Text("\u{2022}")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Text(article.author)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 14)
                }
                .padding(.horizontal, 14)
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.separator).opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func placeholderImage(height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.15))
            .frame(height: height)
            .frame(maxWidth: .infinity)
    }

    private func placeholderGradient(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(
                LinearGradient(
                    colors: [accentColor.opacity(0.15), accentColor.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 32))
                        .foregroundColor(accentColor.opacity(0.4))
                    Text(article.source)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(accentColor.opacity(0.5))
                }
            )
    }
}

// MARK: - Secondary News Card

struct NewsSecondaryCard: View {
    let article: NewsArticle
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image or Placeholder
                if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 120)
                                .frame(maxWidth: .infinity)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 120)
                                .frame(maxWidth: .infinity)
                                .clipped()
                        case .failure:
                            secondaryPlaceholder
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    secondaryPlaceholder
                }

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Source
                    Text(article.source.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(0.3)
                        .lineLimit(1)
                        .padding(.top, 10)

                    // Title
                    Text(article.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)

                    Spacer(minLength: 4)

                    // Timestamp
                    HStack(spacing: 4) {
                        Text(newsTimeAgo(from: article.publishDate))
                            .font(.system(size: 11))
                            .foregroundColor(.gray)

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 10)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator).opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var secondaryPlaceholder: some View {
        Rectangle()
            .fill(Color(.secondarySystemBackground))
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .overlay(
                Image(systemName: "newspaper")
                    .font(.system(size: 24))
                    .foregroundColor(.gray.opacity(0.3))
            )
    }
}

// MARK: - Compact News Card

struct NewsCompactCard: View {
    let article: NewsArticle
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail or Placeholder
                if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            compactPlaceholder
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipped()
                        case .failure:
                            compactPlaceholder
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .cornerRadius(10)
                } else {
                    compactPlaceholder
                }

                // Content
                VStack(alignment: .leading, spacing: 5) {
                    // Source
                    Text(article.source.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(0.3)
                        .lineLimit(1)

                    // Title
                    Text(article.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Spacer(minLength: 2)

                    // Timestamp
                    HStack(spacing: 4) {
                        Text(newsTimeAgo(from: article.publishDate))
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        if !article.category.isEmpty {
                            Text("\u{2022}")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Text(article.category)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(12)
            .frame(minHeight: 80)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator).opacity(0.15), lineWidth: 0.5)
        )
        .buttonStyle(PlainButtonStyle())
    }

    private var compactPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(.secondarySystemBackground))
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "newspaper")
                    .font(.system(size: 20))
                    .foregroundColor(.gray.opacity(0.3))
            )
    }
}
