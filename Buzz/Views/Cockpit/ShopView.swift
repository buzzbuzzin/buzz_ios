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
                                print("🛍️ Product tapped: \(product.title)")
                                print("🛍️ Product has \(product.images.count) images")
                                print("🛍️ Product description: \(product.description.prefix(100))")
                                print("🛍️ Setting selectedProduct...")
                                selectedProduct = product
                                print("🛍️ selectedProduct is now: \(selectedProduct?.title ?? "nil")")
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
    
    init(product: ShopifyProduct) {
        self.product = product
        print("📱 ProductDetailView initialized for: \(product.title)")
        print("📱 Product ID: \(product.id)")
        print("📱 Images count: \(product.images.count)")
        print("📱 Description length: \(product.description.count) chars")
    }
    
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
                                                .frame(height: 400)
                                                .overlay(ProgressView())
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFit()
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 400)
                                        case .failure:
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(height: 400)
                                                .overlay(
                                                    Image(systemName: "photo")
                                                        .font(.system(size: 50))
                                                        .foregroundColor(.gray)
                                                )
                                        @unknown default:
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(height: 400)
                                        }
                                    }
                                    .tag(index)
                                }
                            }
                        }
                        .tabViewStyle(.page)
                        .frame(height: 400)
                        .background(Color(.systemGray6))
                    } else {
                        // Placeholder if no images
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 400)
                            .overlay(
                                VStack(spacing: 12) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)
                                    Text("No Image Available")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            )
                            .background(Color(.systemGray6))
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
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(product.formattedPrice)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            // Show availability badge
                            if product.availableForSale {
                                Text("In Stock")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        
                        Divider()
                        
                        // Description
                        if !product.description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(stripHTML(from: product.description))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("No description available for this product.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                        
                        // Variants
                        if product.variants.count > 1 {
                            VStack(alignment: .leading, spacing: 12) {
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
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                                
                                                HStack(spacing: 8) {
                                                    Text(variant.formattedPrice)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    
                                                    if !variant.availableForSale {
                                                        Text("Out of Stock")
                                                            .font(.caption2)
                                                            .foregroundColor(.red)
                                                    }
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            if selectedVariant?.id == variant.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.blue)
                                                    .font(.system(size: 20))
                                            } else {
                                                Image(systemName: "circle")
                                                    .foregroundColor(.gray.opacity(0.3))
                                                    .font(.system(size: 20))
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
                        } else if !product.variants.isEmpty {
                            // Show single variant info
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Product Details")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text("SKU:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(product.variants.first?.title ?? "Default")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
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
    
    // Helper function to strip HTML tags from description
    private func stripHTML(from string: String) -> String {
        let pattern = "<[^>]+>"
        let plainText = string.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        
        // Decode HTML entities
        var decodedText = plainText
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&rsquo;", with: "'")
            .replacingOccurrences(of: "&lsquo;", with: "'")
            .replacingOccurrences(of: "&rdquo;", with: "\"")
            .replacingOccurrences(of: "&ldquo;", with: "\"")
        
        // Remove excessive whitespace and newlines
        decodedText = decodedText
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        return decodedText.trimmingCharacters(in: .whitespacesAndNewlines)
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
