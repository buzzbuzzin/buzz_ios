//
//  ShopifyProduct.swift
//  Buzz
//
//  Created for Shopify integration
//

import Foundation

// MARK: - Shopify Product Model

struct ShopifyProduct: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let handle: String
    let vendor: String?
    let productType: String?
    let images: [ShopifyProductImage]
    let variants: [ShopifyProductVariant]
    let priceRange: ShopifyPriceRange
    let availableForSale: Bool
    let tags: [String]
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case handle
        case vendor
        case productType
        case images
        case variants
        case priceRange
        case availableForSale
        case tags
    }
    
    // Computed property for the first image URL
    var featuredImageURL: String? {
        return images.first?.url
    }
    
    // Computed property for the minimum price
    var minPrice: String {
        return priceRange.minVariantPrice.amount
    }
    
    // Computed property for formatted price
    var formattedPrice: String {
        let currencyCode = priceRange.minVariantPrice.currencyCode
        let amount = Double(priceRange.minVariantPrice.amount) ?? 0
        return formatPrice(amount: amount, currencyCode: currencyCode)
    }
}

// MARK: - Shopify Product Image

struct ShopifyProductImage: Identifiable, Codable {
    let id: String
    let url: String
    let altText: String?
    let width: Int?
    let height: Int?
}

// MARK: - Shopify Product Variant

struct ShopifyProductVariant: Identifiable, Codable {
    let id: String
    let title: String
    let price: String
    let compareAtPrice: String?
    let availableForSale: Bool
    let selectedOptions: [ShopifySelectedOption]
    let image: ShopifyProductImage?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case price
        case compareAtPrice
        case availableForSale
        case selectedOptions
        case image
    }
    
    var formattedPrice: String {
        let amount = Double(price) ?? 0
        return formatPrice(amount: amount, currencyCode: "USD")
    }
}

// MARK: - Shopify Selected Option

struct ShopifySelectedOption: Codable {
    let name: String
    let value: String
}

// MARK: - Shopify Price Range

struct ShopifyPriceRange: Codable {
    let minVariantPrice: ShopifyMoney
    let maxVariantPrice: ShopifyMoney
}

// MARK: - Shopify Money

struct ShopifyMoney: Codable {
    let amount: String
    let currencyCode: String
}

// MARK: - Helper Functions

private func formatPrice(amount: Double, currencyCode: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currencyCode
    return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
}

