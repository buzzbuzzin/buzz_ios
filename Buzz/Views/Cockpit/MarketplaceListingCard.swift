//
//  MarketplaceListingCard.swift
//  Buzz
//
//  Created for Marketplace feature
//

import SwiftUI

struct MarketplaceListingCard: View {
    let listing: MarketplaceListingWithSeller
    let onFavoriteTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            ZStack(alignment: .topTrailing) {
                if let firstImageUrl = listing.listing.imageUrls.first,
                   let url = URL(string: firstImageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            imagePlaceholder
                        default:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(.systemGray6))
                        }
                    }
                    .frame(height: 140)
                    .clipped()
                } else {
                    imagePlaceholder
                }

                // Favorite button
                Button(action: onFavoriteTap) {
                    Image(systemName: listing.isFavoritedByCurrentUser ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(listing.isFavoritedByCurrentUser ? .red : .white)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .accessibilityLabel(listing.isFavoritedByCurrentUser ? "Remove from favorites" : "Add to favorites")
                .padding(8)

                // Price badge
                VStack {
                    Spacer()
                    HStack {
                        Text(listing.listing.formattedPrice)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(6)
                        Spacer()
                    }
                    .padding(8)
                }
            }
            .frame(height: 140)
            .clipped()

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.listing.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    // Condition badge
                    Text(listing.listing.condition.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(listing.listing.condition.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(listing.listing.condition.color.opacity(0.15))
                        .cornerRadius(4)

                    // Transaction type icon
                    Image(systemName: listing.listing.transactionType.icon)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Spacer()
                }

                HStack(spacing: 4) {
                    if let brand = listing.listing.brand {
                        Text(brand)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(hangerTimeAgo(listing.listing.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var imagePlaceholder: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: listing.listing.category.icon)
                .font(.system(size: 30))
                .foregroundColor(.gray)
        }
        .frame(height: 140)
    }
}
