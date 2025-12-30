//
//  ClientShopView.swift
//  Buzz
//
//  Created for client-specific shop view (Leisure products only)
//

import SwiftUI

struct ClientShopView: View {
    @StateObject private var shopifyService = ShopifyService()
    @State private var selectedProduct: ShopifyProduct? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shop")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Browse our collection of drone equipment and accessories")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                if shopifyService.isLoading && shopifyService.products.isEmpty {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading products...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else if let errorMessage = shopifyService.errorMessage {
                    // Error state
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Unable to Load Products")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            Task {
                                try? await shopifyService.fetchProducts()
                            }
                        }) {
                            Text("Try Again")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else if shopifyService.products.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "bag.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.pink.opacity(0.6))
                        
                        Text("No Products Available")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Check back soon for new products!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    // Products grid
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 16
                    ) {
                        ForEach(shopifyService.products) { product in
                            ProductCard(product: product) {
                                selectedProduct = product
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Shop")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if shopifyService.products.isEmpty {
                try? await shopifyService.fetchProducts()
            }
        }
        .refreshable {
            try? await shopifyService.fetchProducts()
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
        }
    }
}

