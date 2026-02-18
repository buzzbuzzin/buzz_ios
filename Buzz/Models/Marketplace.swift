//
//  Marketplace.swift
//  Buzz
//
//  Created for Marketplace feature
//

import Foundation
import SwiftUI

// MARK: - Marketplace Category

enum MarketplaceCategory: String, Codable, CaseIterable, Identifiable {
    case drones
    case batteries
    case propellers
    case controllers
    case cameraGimbal = "camera_gimbal"
    case fpvGear = "fpv_gear"
    case casesBags = "cases_bags"
    case accessories
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .drones: return "Drones"
        case .batteries: return "Batteries"
        case .propellers: return "Propellers"
        case .controllers: return "Controllers"
        case .cameraGimbal: return "Camera & Gimbal"
        case .fpvGear: return "FPV Gear"
        case .casesBags: return "Cases & Bags"
        case .accessories: return "Accessories"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .drones: return "airplane"
        case .batteries: return "battery.100"
        case .propellers: return "fan.fill"
        case .controllers: return "gamecontroller.fill"
        case .cameraGimbal: return "camera.fill"
        case .fpvGear: return "eye.fill"
        case .casesBags: return "bag.fill"
        case .accessories: return "wrench.and.screwdriver.fill"
        case .other: return "shippingbox.fill"
        }
    }
}

// MARK: - Listing Condition

enum ListingCondition: String, Codable, CaseIterable, Identifiable {
    case new
    case likeNew = "like_new"
    case good
    case fair
    case partsOnly = "parts_only"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .new: return "New"
        case .likeNew: return "Like New"
        case .good: return "Good"
        case .fair: return "Fair"
        case .partsOnly: return "Parts Only"
        }
    }

    var color: Color {
        switch self {
        case .new: return .green
        case .likeNew: return .blue
        case .good: return .orange
        case .fair: return .yellow
        case .partsOnly: return .red
        }
    }
}

// MARK: - Transaction Type

enum MarketplaceTransactionType: String, Codable, CaseIterable, Identifiable {
    case ship
    case meetup
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ship: return "Ship"
        case .meetup: return "Meetup"
        case .both: return "Ship or Meetup"
        }
    }

    var icon: String {
        switch self {
        case .ship: return "shippingbox.fill"
        case .meetup: return "person.2.fill"
        case .both: return "arrow.left.arrow.right"
        }
    }
}

// MARK: - Listing Status

enum ListingStatus: String, Codable {
    case active
    case sold
    case reserved
    case expired
    case removed

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .sold: return "Sold"
        case .reserved: return "Reserved"
        case .expired: return "Expired"
        case .removed: return "Removed"
        }
    }

    var color: Color {
        switch self {
        case .active: return .green
        case .sold: return .blue
        case .reserved: return .orange
        case .expired: return .gray
        case .removed: return .red
        }
    }
}

// MARK: - Offer Status

enum MarketplaceOfferStatus: String, Codable {
    case pending
    case accepted
    case declined
    case withdrawn
    case expired

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        case .withdrawn: return "Withdrawn"
        case .expired: return "Expired"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .accepted: return .green
        case .declined: return .red
        case .withdrawn: return .gray
        case .expired: return .gray
        }
    }
}

// MARK: - Transaction Status

enum MarketplaceTransactionStatus: String, Codable {
    case pendingPayment = "pending_payment"
    case paid
    case shipped
    case delivered
    case completed
    case meetupScheduled = "meetup_scheduled"
    case meetupCompleted = "meetup_completed"
    case disputed
    case refunded
    case cancelled

    var displayName: String {
        switch self {
        case .pendingPayment: return "Pending Payment"
        case .paid: return "Paid"
        case .shipped: return "Shipped"
        case .delivered: return "Delivered"
        case .completed: return "Completed"
        case .meetupScheduled: return "Meetup Scheduled"
        case .meetupCompleted: return "Meetup Complete"
        case .disputed: return "Disputed"
        case .refunded: return "Refunded"
        case .cancelled: return "Cancelled"
        }
    }

    var icon: String {
        switch self {
        case .pendingPayment: return "creditcard"
        case .paid: return "checkmark.circle"
        case .shipped: return "shippingbox"
        case .delivered: return "house"
        case .completed: return "checkmark.seal.fill"
        case .meetupScheduled: return "calendar"
        case .meetupCompleted: return "checkmark.seal.fill"
        case .disputed: return "exclamationmark.triangle"
        case .refunded: return "arrow.uturn.left"
        case .cancelled: return "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .pendingPayment: return .orange
        case .paid: return .blue
        case .shipped: return .purple
        case .delivered: return .teal
        case .completed, .meetupCompleted: return .green
        case .meetupScheduled: return .blue
        case .disputed: return .red
        case .refunded: return .orange
        case .cancelled: return .gray
        }
    }
}

// MARK: - Sort Option

enum MarketplaceSortOption: String, CaseIterable, Identifiable {
    case newest
    case priceLowToHigh
    case priceHighToLow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .newest: return "Newest"
        case .priceLowToHigh: return "Price: Low to High"
        case .priceHighToLow: return "Price: High to Low"
        }
    }
}

// MARK: - Marketplace Listing

struct MarketplaceListing: Codable, Identifiable {
    let id: UUID
    let sellerId: UUID
    let title: String
    let description: String
    let price: Decimal
    let category: MarketplaceCategory
    let condition: ListingCondition
    let transactionType: MarketplaceTransactionType
    let status: ListingStatus
    let imageUrls: [String]
    let locationName: String?
    let locationLat: Double?
    let locationLng: Double?
    let brand: String?
    let model: String?
    let shippingCost: Decimal?
    let viewCount: Int
    let favoriteCount: Int
    let offerCount: Int
    let createdAt: Date
    let updatedAt: Date
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case sellerId = "seller_id"
        case title, description, price, category, condition
        case transactionType = "transaction_type"
        case status
        case imageUrls = "image_urls"
        case locationName = "location_name"
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case brand, model
        case shippingCost = "shipping_cost"
        case viewCount = "view_count"
        case favoriteCount = "favorite_count"
        case offerCount = "offer_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case expiresAt = "expires_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sellerId = try container.decode(UUID.self, forKey: .sellerId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        price = try container.decode(Decimal.self, forKey: .price)
        category = try container.decode(MarketplaceCategory.self, forKey: .category)
        condition = try container.decode(ListingCondition.self, forKey: .condition)
        transactionType = try container.decode(MarketplaceTransactionType.self, forKey: .transactionType)
        status = try container.decode(ListingStatus.self, forKey: .status)
        imageUrls = try container.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        locationLat = try container.decodeIfPresent(Double.self, forKey: .locationLat)
        locationLng = try container.decodeIfPresent(Double.self, forKey: .locationLng)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        shippingCost = try container.decodeIfPresent(Decimal.self, forKey: .shippingCost)
        viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount) ?? 0
        favoriteCount = try container.decodeIfPresent(Int.self, forKey: .favoriteCount) ?? 0
        offerCount = try container.decodeIfPresent(Int.self, forKey: .offerCount) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
    }

    init(id: UUID, sellerId: UUID, title: String, description: String, price: Decimal,
         category: MarketplaceCategory, condition: ListingCondition,
         transactionType: MarketplaceTransactionType, status: ListingStatus,
         imageUrls: [String] = [], locationName: String? = nil,
         locationLat: Double? = nil, locationLng: Double? = nil,
         brand: String? = nil, model: String? = nil, shippingCost: Decimal? = nil,
         viewCount: Int = 0, favoriteCount: Int = 0, offerCount: Int = 0,
         createdAt: Date = Date(), updatedAt: Date = Date(), expiresAt: Date? = nil) {
        self.id = id
        self.sellerId = sellerId
        self.title = title
        self.description = description
        self.price = price
        self.category = category
        self.condition = condition
        self.transactionType = transactionType
        self.status = status
        self.imageUrls = imageUrls
        self.locationName = locationName
        self.locationLat = locationLat
        self.locationLng = locationLng
        self.brand = brand
        self.model = model
        self.shippingCost = shippingCost
        self.viewCount = viewCount
        self.favoriteCount = favoriteCount
        self.offerCount = offerCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
    }

    var formattedPrice: String {
        Self.currencyFormatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }

    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()
}

// MARK: - Marketplace Listing Update

struct MarketplaceListingUpdate: Encodable {
    var title: String?
    var description: String?
    var price: Decimal?
    var category: String?
    var condition: String?
    var transactionType: String?
    var status: String?
    var imageUrls: [String]?
    var locationName: String?
    var locationLat: Double?
    var locationLng: Double?
    var brand: String?
    var model: String?
    var shippingCost: Decimal?

    enum CodingKeys: String, CodingKey {
        case title, description, price, category, condition
        case transactionType = "transaction_type"
        case status
        case imageUrls = "image_urls"
        case locationName = "location_name"
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case brand, model
        case shippingCost = "shipping_cost"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let title { try container.encode(title, forKey: .title) }
        if let description { try container.encode(description, forKey: .description) }
        if let price { try container.encode(price, forKey: .price) }
        if let category { try container.encode(category, forKey: .category) }
        if let condition { try container.encode(condition, forKey: .condition) }
        if let transactionType { try container.encode(transactionType, forKey: .transactionType) }
        if let status { try container.encode(status, forKey: .status) }
        if let imageUrls { try container.encode(imageUrls, forKey: .imageUrls) }
        if let locationName { try container.encode(locationName, forKey: .locationName) }
        if let locationLat { try container.encode(locationLat, forKey: .locationLat) }
        if let locationLng { try container.encode(locationLng, forKey: .locationLng) }
        if let brand { try container.encode(brand, forKey: .brand) }
        if let model { try container.encode(model, forKey: .model) }
        if let shippingCost { try container.encode(shippingCost, forKey: .shippingCost) }
    }
}

// MARK: - Marketplace Listing Insert

struct MarketplaceListingInsert: Codable {
    let sellerId: UUID
    let title: String
    let description: String
    let price: Decimal
    let category: MarketplaceCategory
    let condition: ListingCondition
    let transactionType: MarketplaceTransactionType
    let imageUrls: [String]
    let locationName: String?
    let locationLat: Double?
    let locationLng: Double?
    let brand: String?
    let model: String?
    let shippingCost: Decimal?

    enum CodingKeys: String, CodingKey {
        case sellerId = "seller_id"
        case title, description, price, category, condition
        case transactionType = "transaction_type"
        case imageUrls = "image_urls"
        case locationName = "location_name"
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case brand, model
        case shippingCost = "shipping_cost"
    }
}

// MARK: - Supabase Join Response (listing + seller profile)

struct MarketplaceListingResponse: Codable {
    let id: UUID
    let sellerId: UUID
    let title: String
    let description: String
    let price: Decimal
    let category: MarketplaceCategory
    let condition: ListingCondition
    let transactionType: MarketplaceTransactionType
    let status: ListingStatus
    let imageUrls: [String]
    let locationName: String?
    let locationLat: Double?
    let locationLng: Double?
    let brand: String?
    let model: String?
    let shippingCost: Decimal?
    let viewCount: Int
    let favoriteCount: Int
    let offerCount: Int
    let createdAt: Date
    let updatedAt: Date
    let expiresAt: Date?
    let profiles: HangerAuthorProfileOrArray?

    enum CodingKeys: String, CodingKey {
        case id
        case sellerId = "seller_id"
        case title, description, price, category, condition
        case transactionType = "transaction_type"
        case status
        case imageUrls = "image_urls"
        case locationName = "location_name"
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case brand, model
        case shippingCost = "shipping_cost"
        case viewCount = "view_count"
        case favoriteCount = "favorite_count"
        case offerCount = "offer_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case expiresAt = "expires_at"
        case profiles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sellerId = try container.decode(UUID.self, forKey: .sellerId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        price = try container.decode(Decimal.self, forKey: .price)
        category = try container.decode(MarketplaceCategory.self, forKey: .category)
        condition = try container.decode(ListingCondition.self, forKey: .condition)
        transactionType = try container.decode(MarketplaceTransactionType.self, forKey: .transactionType)
        status = try container.decode(ListingStatus.self, forKey: .status)
        imageUrls = try container.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        locationLat = try container.decodeIfPresent(Double.self, forKey: .locationLat)
        locationLng = try container.decodeIfPresent(Double.self, forKey: .locationLng)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        shippingCost = try container.decodeIfPresent(Decimal.self, forKey: .shippingCost)
        viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount) ?? 0
        favoriteCount = try container.decodeIfPresent(Int.self, forKey: .favoriteCount) ?? 0
        offerCount = try container.decodeIfPresent(Int.self, forKey: .offerCount) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        profiles = try container.decodeIfPresent(HangerAuthorProfileOrArray.self, forKey: .profiles)
    }

    var profileData: HangerAuthorProfile? {
        switch profiles {
        case .single(let profile): return profile
        case .array(let profiles): return profiles.first
        case .none: return nil
        }
    }

    func toListing() -> MarketplaceListing {
        MarketplaceListing(
            id: id, sellerId: sellerId, title: title, description: description,
            price: price, category: category, condition: condition,
            transactionType: transactionType, status: status, imageUrls: imageUrls,
            locationName: locationName, locationLat: locationLat, locationLng: locationLng,
            brand: brand, model: model, shippingCost: shippingCost,
            viewCount: viewCount, favoriteCount: favoriteCount, offerCount: offerCount,
            createdAt: createdAt, updatedAt: updatedAt, expiresAt: expiresAt
        )
    }
}

// MARK: - Listing with Seller (for display)

struct MarketplaceListingWithSeller: Identifiable {
    let id: UUID
    let listing: MarketplaceListing
    let sellerCallSign: String?
    let sellerProfilePictureUrl: String?
    let sellerFullName: String
    var isFavoritedByCurrentUser: Bool
}

// MARK: - Marketplace Favorite

struct MarketplaceFavorite: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let listingId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case listingId = "listing_id"
        case createdAt = "created_at"
    }
}

// MARK: - Marketplace Offer

struct MarketplaceOffer: Codable, Identifiable {
    let id: UUID
    let listingId: UUID
    let buyerId: UUID
    let amount: Decimal
    let message: String?
    let status: MarketplaceOfferStatus
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case buyerId = "buyer_id"
        case amount, message, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var formattedAmount: String {
        MarketplaceListing.currencyFormatter.string(from: amount as NSDecimalNumber) ?? "$\(amount)"
    }
}

// MARK: - Marketplace Offer Insert

struct MarketplaceOfferInsert: Codable {
    let listingId: UUID
    let buyerId: UUID
    let amount: Decimal
    let message: String?

    enum CodingKeys: String, CodingKey {
        case listingId = "listing_id"
        case buyerId = "buyer_id"
        case amount, message
    }
}

// MARK: - Offer with Buyer Profile (Supabase join)

struct MarketplaceOfferResponse: Codable, Identifiable {
    let id: UUID
    let listingId: UUID
    let buyerId: UUID
    let amount: Decimal
    let message: String?
    let status: MarketplaceOfferStatus
    let createdAt: Date
    let updatedAt: Date
    let profiles: HangerAuthorProfileOrArray?

    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case buyerId = "buyer_id"
        case amount, message, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case profiles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        listingId = try container.decode(UUID.self, forKey: .listingId)
        buyerId = try container.decode(UUID.self, forKey: .buyerId)
        amount = try container.decode(Decimal.self, forKey: .amount)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        status = try container.decode(MarketplaceOfferStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        profiles = try container.decodeIfPresent(HangerAuthorProfileOrArray.self, forKey: .profiles)
    }

    var profileData: HangerAuthorProfile? {
        switch profiles {
        case .single(let profile): return profile
        case .array(let profiles): return profiles.first
        case .none: return nil
        }
    }

    var formattedAmount: String {
        MarketplaceListing.currencyFormatter.string(from: amount as NSDecimalNumber) ?? "$\(amount)"
    }
}

// MARK: - Marketplace Transaction

struct MarketplaceTransaction: Codable, Identifiable {
    let id: UUID
    let listingId: UUID
    let buyerId: UUID
    let sellerId: UUID
    let offerId: UUID?
    let transactionType: MarketplaceTransactionType
    let status: MarketplaceTransactionStatus
    let amount: Decimal
    let platformFee: Decimal
    let sellerPayout: Decimal
    let paymentIntentId: String?
    let chargeId: String?
    let transferId: String?
    let trackingNumber: String?
    let trackingCarrier: String?
    let meetupLocationName: String?
    let meetupLocationLat: Double?
    let meetupLocationLng: Double?
    let meetupScheduledAt: Date?
    let buyerConfirmedAt: Date?
    let sellerConfirmedAt: Date?
    let shippedAt: Date?
    let deliveredAt: Date?
    let completedAt: Date?
    let cancelledAt: Date?
    let cancellationReason: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case buyerId = "buyer_id"
        case sellerId = "seller_id"
        case offerId = "offer_id"
        case transactionType = "transaction_type"
        case status, amount
        case platformFee = "platform_fee"
        case sellerPayout = "seller_payout"
        case paymentIntentId = "payment_intent_id"
        case chargeId = "charge_id"
        case transferId = "transfer_id"
        case trackingNumber = "tracking_number"
        case trackingCarrier = "tracking_carrier"
        case meetupLocationName = "meetup_location_name"
        case meetupLocationLat = "meetup_location_lat"
        case meetupLocationLng = "meetup_location_lng"
        case meetupScheduledAt = "meetup_scheduled_at"
        case buyerConfirmedAt = "buyer_confirmed_at"
        case sellerConfirmedAt = "seller_confirmed_at"
        case shippedAt = "shipped_at"
        case deliveredAt = "delivered_at"
        case completedAt = "completed_at"
        case cancelledAt = "cancelled_at"
        case cancellationReason = "cancellation_reason"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        listingId = try container.decode(UUID.self, forKey: .listingId)
        buyerId = try container.decode(UUID.self, forKey: .buyerId)
        sellerId = try container.decode(UUID.self, forKey: .sellerId)
        offerId = try container.decodeIfPresent(UUID.self, forKey: .offerId)
        transactionType = try container.decode(MarketplaceTransactionType.self, forKey: .transactionType)
        status = try container.decode(MarketplaceTransactionStatus.self, forKey: .status)
        amount = try container.decodeIfPresent(Decimal.self, forKey: .amount) ?? 0
        platformFee = try container.decodeIfPresent(Decimal.self, forKey: .platformFee) ?? 0
        sellerPayout = try container.decodeIfPresent(Decimal.self, forKey: .sellerPayout) ?? 0
        paymentIntentId = try container.decodeIfPresent(String.self, forKey: .paymentIntentId)
        chargeId = try container.decodeIfPresent(String.self, forKey: .chargeId)
        transferId = try container.decodeIfPresent(String.self, forKey: .transferId)
        trackingNumber = try container.decodeIfPresent(String.self, forKey: .trackingNumber)
        trackingCarrier = try container.decodeIfPresent(String.self, forKey: .trackingCarrier)
        meetupLocationName = try container.decodeIfPresent(String.self, forKey: .meetupLocationName)
        meetupLocationLat = try container.decodeIfPresent(Double.self, forKey: .meetupLocationLat)
        meetupLocationLng = try container.decodeIfPresent(Double.self, forKey: .meetupLocationLng)
        meetupScheduledAt = try container.decodeIfPresent(Date.self, forKey: .meetupScheduledAt)
        buyerConfirmedAt = try container.decodeIfPresent(Date.self, forKey: .buyerConfirmedAt)
        sellerConfirmedAt = try container.decodeIfPresent(Date.self, forKey: .sellerConfirmedAt)
        shippedAt = try container.decodeIfPresent(Date.self, forKey: .shippedAt)
        deliveredAt = try container.decodeIfPresent(Date.self, forKey: .deliveredAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        cancelledAt = try container.decodeIfPresent(Date.self, forKey: .cancelledAt)
        cancellationReason = try container.decodeIfPresent(String.self, forKey: .cancellationReason)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    init(id: UUID, listingId: UUID, buyerId: UUID, sellerId: UUID, offerId: UUID?,
         transactionType: MarketplaceTransactionType, status: MarketplaceTransactionStatus,
         amount: Decimal, platformFee: Decimal, sellerPayout: Decimal,
         paymentIntentId: String?, chargeId: String?, transferId: String?,
         trackingNumber: String?, trackingCarrier: String?,
         meetupLocationName: String?, meetupLocationLat: Double?, meetupLocationLng: Double?,
         meetupScheduledAt: Date?, buyerConfirmedAt: Date?, sellerConfirmedAt: Date?,
         shippedAt: Date?, deliveredAt: Date?, completedAt: Date?,
         cancelledAt: Date?, cancellationReason: String?,
         createdAt: Date, updatedAt: Date) {
        self.id = id
        self.listingId = listingId
        self.buyerId = buyerId
        self.sellerId = sellerId
        self.offerId = offerId
        self.transactionType = transactionType
        self.status = status
        self.amount = amount
        self.platformFee = platformFee
        self.sellerPayout = sellerPayout
        self.paymentIntentId = paymentIntentId
        self.chargeId = chargeId
        self.transferId = transferId
        self.trackingNumber = trackingNumber
        self.trackingCarrier = trackingCarrier
        self.meetupLocationName = meetupLocationName
        self.meetupLocationLat = meetupLocationLat
        self.meetupLocationLng = meetupLocationLng
        self.meetupScheduledAt = meetupScheduledAt
        self.buyerConfirmedAt = buyerConfirmedAt
        self.sellerConfirmedAt = sellerConfirmedAt
        self.shippedAt = shippedAt
        self.deliveredAt = deliveredAt
        self.completedAt = completedAt
        self.cancelledAt = cancelledAt
        self.cancellationReason = cancellationReason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var formattedAmount: String {
        MarketplaceListing.currencyFormatter.string(from: amount as NSDecimalNumber) ?? "$\(amount)"
    }
}

// MARK: - Transaction with Details (for display)

struct MarketplaceTransactionWithDetails: Identifiable {
    let id: UUID
    let transaction: MarketplaceTransaction
    let listingTitle: String
    let listingImageUrl: String?
    let partnerCallSign: String?
    let partnerProfilePictureUrl: String?
    let partnerFullName: String
    let isBuyer: Bool
}

// MARK: - Marketplace Review

struct MarketplaceReview: Codable, Identifiable {
    let id: UUID
    let transactionId: UUID
    let fromUserId: UUID
    let toUserId: UUID
    let rating: Int
    let comment: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case transactionId = "transaction_id"
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case rating, comment
        case createdAt = "created_at"
    }
}

// MARK: - Review with Profile (for display)

struct MarketplaceReviewWithProfile: Identifiable {
    let id: UUID
    let review: MarketplaceReview
    let reviewerCallSign: String?
    let reviewerProfilePictureUrl: String?
    let reviewerFullName: String
}

// MARK: - Marketplace Payment Response (from create-marketplace-payment edge function)

struct MarketplacePaymentResponse: Decodable {
    let clientSecret: String
    let paymentIntentId: String
    let customerId: String?
    let ephemeralKeySecret: String?
    let platformFee: Int?
    let sellerPayout: Int?

    enum CodingKeys: String, CodingKey {
        case clientSecret = "client_secret"
        case paymentIntentId = "payment_intent_id"
        case customerId = "customer_id"
        case ephemeralKeySecret = "ephemeral_key_secret"
        case platformFee = "platform_fee"
        case sellerPayout = "seller_payout"
    }
}
