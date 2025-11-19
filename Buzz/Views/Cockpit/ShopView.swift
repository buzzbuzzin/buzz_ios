//
//  ShopView.swift
//  Buzz
//
//  Created for Shop feature
//

import SwiftUI

struct ShopView: View {
    @StateObject private var shopifyService = ShopifyService()
    @State private var selectedProduct: ShopifyProduct? = nil
    @State private var showProductDetail = false
    
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
                                showProductDetail = true
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
        .sheet(isPresented: $showProductDetail) {
            if let product = selectedProduct {
                ProductDetailView(product: product)
            }
        }
    }
}

// MARK: - Product Card

struct ProductCard: View {
    let product: ShopifyProduct
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Product Image
                Group {
                    if let imageURL = product.featuredImageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(ProgressView())
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .clipped()
                .cornerRadius(12, corners: [.topLeft, .topRight])
                
                // Product Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(product.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let vendor = product.vendor {
                        Text(vendor)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack {
                        Text(product.formattedPrice)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if !product.availableForSale {
                            Text("Sold Out")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Product Detail View

struct ProductDetailView: View {
    let product: ShopifyProduct
    @Environment(\.dismiss) var dismiss
    @State private var selectedImageIndex = 0
    @State private var selectedVariant: ShopifyProductVariant?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Image Gallery
                    if !product.images.isEmpty {
                        TabView(selection: $selectedImageIndex) {
                            ForEach(Array(product.images.enumerated()), id: \.offset) { index, image in
                                if let url = URL(string: image.url) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .aspectRatio(1, contentMode: .fit)
                                                .overlay(ProgressView())
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFit()
                                        case .failure:
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .aspectRatio(1, contentMode: .fit)
                                                .overlay(
                                                    Image(systemName: "photo")
                                                        .foregroundColor(.gray)
                                                )
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                    .tag(index)
                                }
                            }
                        }
                        .tabViewStyle(.page)
                        .frame(height: 400)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Title and Vendor
                        VStack(alignment: .leading, spacing: 8) {
                            Text(product.title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                            
                            if let vendor = product.vendor {
                                Text(vendor)
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Price
                        Text(product.formattedPrice)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Divider()
                        
                        // Description
                        if !product.description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(product.description)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        // Variants
                        if product.variants.count > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Options")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                ForEach(product.variants) { variant in
                                    Button(action: {
                                        selectedVariant = variant
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(variant.title)
                                                    .font(.subheadline)
                                                    .foregroundColor(.primary)
                                                
                                                Text(variant.formattedPrice)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            if selectedVariant?.id == variant.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        .padding()
                                        .background(
                                            selectedVariant?.id == variant.id
                                                ? Color.blue.opacity(0.1)
                                                : Color(.secondarySystemBackground)
                                        )
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        
                        // Availability
                        if !product.availableForSale {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("This product is currently unavailable")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Buy Button
                        Button(action: {
                            openProductInShopify(product: product)
                        }) {
                            HStack {
                                Spacer()
                                Text("View on Shopify")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.vertical, 16)
                            .background(product.availableForSale ? Color.black : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!product.availableForSale)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            selectedVariant = product.variants.first
        }
    }
    
    private func openProductInShopify(product: ShopifyProduct) {
        let shopifyURL = "https://\(Config.shopifyStoreURL)/products/\(product.handle)"
        if let url = URL(string: shopifyURL) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
