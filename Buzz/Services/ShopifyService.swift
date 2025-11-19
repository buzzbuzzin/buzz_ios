//
//  ShopifyService.swift
//  Buzz
//
//  Created for Shopify integration
//

import Foundation
import Combine

@MainActor
class ShopifyService: ObservableObject {
    @Published var products: [ShopifyProduct] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let storefrontAPIURL: String
    private let accessToken: String
    
    init() {
        self.storefrontAPIURL = Config.shopifyStorefrontAPIURL
        self.accessToken = Config.shopifyStorefrontAccessToken
    }
    
    // MARK: - Fetch Products
    
    func fetchProducts(limit: Int = 20, after: String? = nil) async throws {
        isLoading = true
        errorMessage = nil
        
        // Check if Shopify is configured
        guard Config.shopifyStoreURL != "your-store.myshopify.com",
              Config.shopifyStorefrontAccessToken != "YOUR_STOREFRONT_ACCESS_TOKEN" else {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Shopify store not configured. Please add your store URL and access token in Config.swift"
            }
            return
        }
        
        do {
            let query = buildProductsQuery(limit: limit, after: after)
            let response = try await performGraphQLRequest(query: query)
            
            let products = try parseProductsResponse(response)
            
            await MainActor.run {
                if after == nil {
                    // First page - replace products
                    self.products = products
                } else {
                    // Subsequent pages - append products
                    self.products.append(contentsOf: products)
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Fetch Single Product
    
    func fetchProduct(handle: String) async throws -> ShopifyProduct? {
        isLoading = true
        errorMessage = nil
        
        do {
            let query = buildProductQuery(handle: handle)
            let response = try await performGraphQLRequest(query: query)
            
            let product = try parseProductResponse(response)
            
            await MainActor.run {
                self.isLoading = false
            }
            
            return product
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - GraphQL Request
    
    private func performGraphQLRequest(query: String) async throws -> [String: Any] {
        guard let url = URL(string: storefrontAPIURL) else {
            throw ShopifyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accessToken, forHTTPHeaderField: "X-Shopify-Storefront-Access-Token")
        
        let requestBody: [String: Any] = [
            "query": query
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShopifyError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ShopifyError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ShopifyError.invalidResponse
        }
        
        // Check for GraphQL errors
        if let errors = json["errors"] as? [[String: Any]], !errors.isEmpty {
            let errorMessages = errors.compactMap { $0["message"] as? String }.joined(separator: ", ")
            throw ShopifyError.graphQLError(message: errorMessages)
        }
        
        return json
    }
    
    // MARK: - Build GraphQL Queries
    
    private func buildProductsQuery(limit: Int, after: String?) -> String {
        let afterClause = after != nil ? ", after: \"\(after!)\"" : ""
        
        return """
        {
          products(first: \(limit)\(afterClause)) {
            edges {
              node {
                id
                title
                description
                handle
                vendor
                productType
                availableForSale
                tags
                images(first: 5) {
                  edges {
                    node {
                      id
                      url
                      altText
                      width
                      height
                    }
                  }
                }
                variants(first: 10) {
                  edges {
                    node {
                      id
                      title
                      price {
                        amount
                        currencyCode
                      }
                      compareAtPrice {
                        amount
                        currencyCode
                      }
                      availableForSale
                      selectedOptions {
                        name
                        value
                      }
                      image {
                        id
                        url
                        altText
                        width
                        height
                      }
                    }
                  }
                }
                priceRange {
                  minVariantPrice {
                    amount
                    currencyCode
                  }
                  maxVariantPrice {
                    amount
                    currencyCode
                  }
                }
              }
              cursor
            }
            pageInfo {
              hasNextPage
              endCursor
            }
          }
        }
        """
    }
    
    private func buildProductQuery(handle: String) -> String {
        return """
        {
          product(handle: "\(handle)") {
            id
            title
            description
            handle
            vendor
            productType
            availableForSale
            tags
            images(first: 10) {
              edges {
                node {
                  id
                  url
                  altText
                  width
                  height
                }
              }
            }
            variants(first: 20) {
              edges {
                node {
                  id
                  title
                  price {
                    amount
                    currencyCode
                  }
                  compareAtPrice {
                    amount
                    currencyCode
                  }
                  availableForSale
                  selectedOptions {
                    name
                    value
                  }
                  image {
                    id
                    url
                    altText
                    width
                    height
                  }
                }
              }
            }
            priceRange {
              minVariantPrice {
                amount
                currencyCode
              }
              maxVariantPrice {
                amount
                currencyCode
              }
            }
          }
        }
        """
    }
    
    // MARK: - Parse Responses
    
    private func parseProductsResponse(_ json: [String: Any]) throws -> [ShopifyProduct] {
        guard let data = json["data"] as? [String: Any],
              let products = data["products"] as? [String: Any],
              let edges = products["edges"] as? [[String: Any]] else {
            throw ShopifyError.invalidResponse
        }
        
        return try edges.compactMap { edge -> ShopifyProduct? in
            guard let node = edge["node"] as? [String: Any] else { return nil }
            return try parseProduct(from: node)
        }
    }
    
    private func parseProductResponse(_ json: [String: Any]) throws -> ShopifyProduct? {
        guard let data = json["data"] as? [String: Any],
              let product = data["product"] as? [String: Any] else {
            throw ShopifyError.invalidResponse
        }
        
        return try parseProduct(from: product)
    }
    
    private func parseProduct(from node: [String: Any]) throws -> ShopifyProduct {
        guard let id = node["id"] as? String,
              let title = node["title"] as? String else {
            throw ShopifyError.invalidResponse
        }
        
        let description = node["description"] as? String ?? ""
        let handle = node["handle"] as? String ?? ""
        let vendor = node["vendor"] as? String
        let productType = node["productType"] as? String
        let availableForSale = node["availableForSale"] as? Bool ?? false
        let tags = node["tags"] as? [String] ?? []
        
        // Parse images
        var images: [ShopifyProductImage] = []
        if let imagesData = node["images"] as? [String: Any],
           let imageEdges = imagesData["edges"] as? [[String: Any]] {
            images = try imageEdges.compactMap { edge -> ShopifyProductImage? in
                guard let imageNode = edge["node"] as? [String: Any],
                      let imageId = imageNode["id"] as? String,
                      let imageUrl = imageNode["url"] as? String else {
                    return nil
                }
                return ShopifyProductImage(
                    id: imageId,
                    url: imageUrl,
                    altText: imageNode["altText"] as? String,
                    width: imageNode["width"] as? Int,
                    height: imageNode["height"] as? Int
                )
            }
        }
        
        // Parse variants
        var variants: [ShopifyProductVariant] = []
        if let variantsData = node["variants"] as? [String: Any],
           let variantEdges = variantsData["edges"] as? [[String: Any]] {
            variants = try variantEdges.compactMap { edge -> ShopifyProductVariant? in
                guard let variantNode = edge["node"] as? [String: Any],
                      let variantId = variantNode["id"] as? String,
                      let variantTitle = variantNode["title"] as? String,
                      let priceData = variantNode["price"] as? [String: Any],
                      let variantPrice = priceData["amount"] as? String else {
                    return nil
                }
                
                // Parse compareAtPrice if available
                var compareAtPrice: String? = nil
                if let compareAtPriceData = variantNode["compareAtPrice"] as? [String: Any],
                   let compareAmount = compareAtPriceData["amount"] as? String {
                    compareAtPrice = compareAmount
                }
                
                let availableForSale = variantNode["availableForSale"] as? Bool ?? false
                
                var selectedOptions: [ShopifySelectedOption] = []
                if let options = variantNode["selectedOptions"] as? [[String: Any]] {
                    selectedOptions = options.compactMap { option -> ShopifySelectedOption? in
                        guard let name = option["name"] as? String,
                              let value = option["value"] as? String else {
                            return nil
                        }
                        return ShopifySelectedOption(name: name, value: value)
                    }
                }
                
                var variantImage: ShopifyProductImage? = nil
                if let imageData = variantNode["image"] as? [String: Any],
                   let imageId = imageData["id"] as? String,
                   let imageUrl = imageData["url"] as? String {
                    variantImage = ShopifyProductImage(
                        id: imageId,
                        url: imageUrl,
                        altText: imageData["altText"] as? String,
                        width: imageData["width"] as? Int,
                        height: imageData["height"] as? Int
                    )
                }
                
                return ShopifyProductVariant(
                    id: variantId,
                    title: variantTitle,
                    price: variantPrice,
                    compareAtPrice: compareAtPrice,
                    availableForSale: availableForSale,
                    selectedOptions: selectedOptions,
                    image: variantImage
                )
            }
        }
        
        // Parse price range
        guard let priceRangeData = node["priceRange"] as? [String: Any],
              let minPriceData = priceRangeData["minVariantPrice"] as? [String: Any],
              let minAmount = minPriceData["amount"] as? String,
              let minCurrency = minPriceData["currencyCode"] as? String,
              let maxPriceData = priceRangeData["maxVariantPrice"] as? [String: Any],
              let maxAmount = maxPriceData["amount"] as? String,
              let maxCurrency = maxPriceData["currencyCode"] as? String else {
            throw ShopifyError.invalidResponse
        }
        
        let priceRange = ShopifyPriceRange(
            minVariantPrice: ShopifyMoney(amount: minAmount, currencyCode: minCurrency),
            maxVariantPrice: ShopifyMoney(amount: maxAmount, currencyCode: maxCurrency)
        )
        
        return ShopifyProduct(
            id: id,
            title: title,
            description: description,
            handle: handle,
            vendor: vendor,
            productType: productType,
            images: images,
            variants: variants,
            priceRange: priceRange,
            availableForSale: availableForSale,
            tags: tags
        )
    }
}

// MARK: - Shopify Errors

enum ShopifyError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case graphQLError(message: String)
    case notConfigured
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Shopify API URL"
        case .invalidResponse:
            return "Invalid response from Shopify"
        case .httpError(let statusCode, let message):
            return "HTTP Error \(statusCode): \(message)"
        case .graphQLError(let message):
            return "GraphQL Error: \(message)"
        case .notConfigured:
            return "Shopify store not configured"
        }
    }
}

