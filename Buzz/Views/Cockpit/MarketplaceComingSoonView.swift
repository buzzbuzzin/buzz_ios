//
//  MarketplaceComingSoonView.swift
//  Buzz
//
//  Created for Marketplace feature
//

import SwiftUI

struct MarketplaceComingSoonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 40)

                // Coming Soon Badge
                VStack(spacing: 24) {
                    // Icon with background
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.2), Color.yellow.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)

                        Image(systemName: "storefront.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: 12) {
                        Text("Coming Soon")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)

                        Text("Pilot Marketplace")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }

                // Description
                Text("A marketplace built by pilots, for pilots. Buy and sell drones, accessories, and pilot-specific gear within the Buzz community.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Value Proposition
                VStack(alignment: .leading, spacing: 16) {
                    Text("What to expect:")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    MarketplacePreviewCard(
                        icon: "drone",
                        title: "Buy & Sell Drones",
                        description: "Find second-hand drones at great prices or sell your used equipment"
                    )

                    MarketplacePreviewCard(
                        icon: "wrench.and.screwdriver.fill",
                        title: "Pilot Gear & Accessories",
                        description: "Batteries, propellers, cases, and other essentials from fellow pilots"
                    )

                    MarketplacePreviewCard(
                        icon: "arrow.up.right.circle.fill",
                        title: "Upgrade Path",
                        description: "Start affordable with pre-owned gear, then invest in quality equipment through Buzz as you grow"
                    )

                    MarketplacePreviewCard(
                        icon: "person.2.fill",
                        title: "Trusted Community",
                        description: "Trade within the verified Buzz pilot network with confidence"
                    )
                }
                .padding(.horizontal)
                .padding(.top, 16)

                Spacer()
                    .frame(height: 40)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Marketplace")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Marketplace Preview Card

struct MarketplacePreviewCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        MarketplaceComingSoonView()
    }
}
