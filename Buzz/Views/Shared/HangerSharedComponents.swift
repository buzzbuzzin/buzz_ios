//
//  HangerSharedComponents.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/8/26.
//

import SwiftUI

// MARK: - Time Ago Helper

func hangerTimeAgo(_ date: Date) -> String {
    let seconds = Int(Date().timeIntervalSince(date))
    if seconds < 60 { return "Just Now" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h" }
    let days = hours / 24
    if days < 7 { return "\(days)d" }
    let weeks = days / 7
    if weeks < 4 { return "\(weeks)w" }
    let months = days / 30
    if months < 12 { return "\(months)mo" }
    let years = days / 365
    return "\(years)y"
}

// MARK: - Mention Text (renders @mentions as highlighted blue text)

struct MentionText: View {
    let text: String
    let font: Font

    init(_ text: String, font: Font = .body) {
        self.text = text
        self.font = font
    }

    var body: some View {
        buildText()
            .font(font)
    }

    private func buildText() -> Text {
        let segments = MentionParser.parseSegments(from: text)
        var result = Text("")

        for segment in segments {
            switch segment {
            case .plain(let str):
                result = result + Text(str)
            case .mention(let callSign):
                result = result + Text("@\(callSign)")
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
            }
        }

        return result
    }
}

// MARK: - Image Carousel (shared component)

struct HangerImageCarousel: View {
    let imageUrls: [String]
    let height: CGFloat
    @State private var currentPage = 0

    var body: some View {
        if imageUrls.count == 1 {
            // Single image — no carousel
            singleImage(urlString: imageUrls[0])
        } else {
            // Multiple images — swipeable carousel
            ZStack(alignment: .topTrailing) {
                TabView(selection: $currentPage) {
                    ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, urlString in
                        carouselImage(urlString: urlString)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Counter badge
                Text("\(currentPage + 1) / \(imageUrls.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .padding(8)
            }
        }
    }

    private func singleImage(urlString: String) -> some View {
        Group {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: height)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        imagePlaceholder
                    case .empty:
                        imageLoading
                    @unknown default:
                        imageLoading
                    }
                }
            }
        }
    }

    private func carouselImage(urlString: String) -> some View {
        Group {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: height)
                            .clipped()
                    case .failure:
                        imagePlaceholder
                    case .empty:
                        imageLoading
                    @unknown default:
                        imageLoading
                    }
                }
            }
        }
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.2))
            .frame(height: height)
            .overlay(
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundColor(.secondary)
            )
    }

    private var imageLoading: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.1))
            .frame(height: height)
            .overlay(ProgressView())
    }
}
