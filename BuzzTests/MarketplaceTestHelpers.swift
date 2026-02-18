//
//  MarketplaceTestHelpers.swift
//  BuzzTests
//
//  Sample data factories and utilities for Marketplace tests.
//

import XCTest
import Foundation
@testable import Buzz

// MARK: - Marketplace Sample Data Factories

enum MarketplaceTestData {

    // MARK: - Listings

    static func sampleListing(
        id: UUID = UUID(),
        sellerId: UUID = UUID(),
        title: String = "DJI Mini 4 Pro",
        description: String = "Like new DJI Mini 4 Pro with Fly More Combo. Includes 3 batteries, carrying case, and ND filters.",
        price: Decimal = 599.99,
        category: MarketplaceCategory = .drones,
        condition: ListingCondition = .likeNew,
        transactionType: MarketplaceTransactionType = .both,
        status: ListingStatus = .active,
        imageUrls: [String] = ["https://example.com/drone1.jpg", "https://example.com/drone2.jpg"],
        locationName: String? = "San Francisco, CA",
        locationLat: Double? = 37.7749,
        locationLng: Double? = -122.4194,
        brand: String? = "DJI",
        model: String? = "Mini 4 Pro",
        shippingCost: Decimal? = 15.99,
        viewCount: Int = 42,
        favoriteCount: Int = 5,
        offerCount: Int = 2,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        expiresAt: Date? = nil
    ) -> MarketplaceListing {
        MarketplaceListing(
            id: id,
            sellerId: sellerId,
            title: title,
            description: description,
            price: price,
            category: category,
            condition: condition,
            transactionType: transactionType,
            status: status,
            imageUrls: imageUrls,
            locationName: locationName,
            locationLat: locationLat,
            locationLng: locationLng,
            brand: brand,
            model: model,
            shippingCost: shippingCost,
            viewCount: viewCount,
            favoriteCount: favoriteCount,
            offerCount: offerCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
            expiresAt: expiresAt
        )
    }

    // MARK: - Listing With Seller

    static func sampleListingWithSeller(
        id: UUID = UUID(),
        listing: MarketplaceListing? = nil,
        sellerCallSign: String? = "DronePilot",
        sellerProfilePictureUrl: String? = nil,
        sellerFullName: String = "John Seller",
        isFavoritedByCurrentUser: Bool = false
    ) -> MarketplaceListingWithSeller {
        let actualListing = listing ?? sampleListing(id: id)
        return MarketplaceListingWithSeller(
            id: id,
            listing: actualListing,
            sellerCallSign: sellerCallSign,
            sellerProfilePictureUrl: sellerProfilePictureUrl,
            sellerFullName: sellerFullName,
            isFavoritedByCurrentUser: isFavoritedByCurrentUser
        )
    }

    // MARK: - Offers

    static func sampleOffer(
        id: UUID = UUID(),
        listingId: UUID = UUID(),
        buyerId: UUID = UUID(),
        amount: Decimal = 299.99,
        message: String? = "Would you take $299.99?",
        status: MarketplaceOfferStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> MarketplaceOffer {
        MarketplaceOffer(
            id: id,
            listingId: listingId,
            buyerId: buyerId,
            amount: amount,
            message: message,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Offer Response (with buyer profile)

    static func sampleOfferResponseJSON(
        id: UUID = UUID(),
        listingId: UUID = UUID(),
        buyerId: UUID = UUID(),
        amount: Decimal = 299.99,
        message: String? = "Interested in this item",
        status: MarketplaceOfferStatus = .pending,
        buyerCallSign: String? = "BuyerPilot",
        buyerFirstName: String = "Jane",
        buyerLastName: String = "Buyer"
    ) -> [String: Any] {
        let isoDate = ISO8601DateFormatter().string(from: Date())
        var json: [String: Any] = [
            "id": id.uuidString,
            "listing_id": listingId.uuidString,
            "buyer_id": buyerId.uuidString,
            "amount": NSDecimalNumber(decimal: amount).doubleValue,
            "status": status.rawValue,
            "created_at": isoDate,
            "updated_at": isoDate,
            "profiles": [
                "id": buyerId.uuidString,
                "call_sign": buyerCallSign as Any,
                "profile_picture_url": NSNull(),
                "first_name": buyerFirstName,
                "last_name": buyerLastName
            ] as [String: Any]
        ]
        if let message {
            json["message"] = message
        }
        return json
    }

    // MARK: - Transactions

    static func sampleTransaction(
        id: UUID = UUID(),
        listingId: UUID = UUID(),
        buyerId: UUID = UUID(),
        sellerId: UUID = UUID(),
        offerId: UUID? = nil,
        transactionType: MarketplaceTransactionType = .ship,
        status: MarketplaceTransactionStatus = .pendingPayment,
        amount: Decimal = 349.99,
        platformFee: Decimal = 34.99,
        sellerPayout: Decimal = 315.00,
        paymentIntentId: String? = "pi_test_123",
        chargeId: String? = nil,
        transferId: String? = nil,
        trackingNumber: String? = nil,
        trackingCarrier: String? = nil,
        meetupLocationName: String? = nil,
        meetupLocationLat: Double? = nil,
        meetupLocationLng: Double? = nil,
        meetupScheduledAt: Date? = nil,
        buyerConfirmedAt: Date? = nil,
        sellerConfirmedAt: Date? = nil,
        shippedAt: Date? = nil,
        deliveredAt: Date? = nil,
        completedAt: Date? = nil,
        cancelledAt: Date? = nil,
        cancellationReason: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> MarketplaceTransaction {
        MarketplaceTransaction(
            id: id,
            listingId: listingId,
            buyerId: buyerId,
            sellerId: sellerId,
            offerId: offerId,
            transactionType: transactionType,
            status: status,
            amount: amount,
            platformFee: platformFee,
            sellerPayout: sellerPayout,
            paymentIntentId: paymentIntentId,
            chargeId: chargeId,
            transferId: transferId,
            trackingNumber: trackingNumber,
            trackingCarrier: trackingCarrier,
            meetupLocationName: meetupLocationName,
            meetupLocationLat: meetupLocationLat,
            meetupLocationLng: meetupLocationLng,
            meetupScheduledAt: meetupScheduledAt,
            buyerConfirmedAt: buyerConfirmedAt,
            sellerConfirmedAt: sellerConfirmedAt,
            shippedAt: shippedAt,
            deliveredAt: deliveredAt,
            completedAt: completedAt,
            cancelledAt: cancelledAt,
            cancellationReason: cancellationReason,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Reviews

    static func sampleReview(
        id: UUID = UUID(),
        transactionId: UUID = UUID(),
        fromUserId: UUID = UUID(),
        toUserId: UUID = UUID(),
        rating: Int = 5,
        comment: String? = "Great seller, item as described!",
        createdAt: Date = Date()
    ) -> MarketplaceReview {
        MarketplaceReview(
            id: id,
            transactionId: transactionId,
            fromUserId: fromUserId,
            toUserId: toUserId,
            rating: rating,
            comment: comment,
            createdAt: createdAt
        )
    }

    // MARK: - Listing Insert

    static func sampleListingInsert(
        sellerId: UUID = UUID(),
        title: String = "DJI Mavic 3 Classic",
        description: String = "Brand new in box, never flown.",
        price: Decimal = 1049.00,
        category: MarketplaceCategory = .drones,
        condition: ListingCondition = .new,
        transactionType: MarketplaceTransactionType = .ship,
        imageUrls: [String] = ["https://example.com/mavic3.jpg"],
        locationName: String? = "Austin, TX",
        locationLat: Double? = 30.2672,
        locationLng: Double? = -97.7431,
        brand: String? = "DJI",
        model: String? = "Mavic 3 Classic",
        shippingCost: Decimal? = 0
    ) -> MarketplaceListingInsert {
        MarketplaceListingInsert(
            sellerId: sellerId,
            title: title,
            description: description,
            price: price,
            category: category,
            condition: condition,
            transactionType: transactionType,
            imageUrls: imageUrls,
            locationName: locationName,
            locationLat: locationLat,
            locationLng: locationLng,
            brand: brand,
            model: model,
            shippingCost: shippingCost
        )
    }

    // MARK: - Listing Update

    static func sampleListingUpdate(
        title: String? = "Updated Title",
        description: String? = nil,
        price: Decimal? = nil,
        category: String? = nil,
        condition: String? = nil,
        transactionType: String? = nil,
        status: String? = nil,
        imageUrls: [String]? = nil,
        locationName: String? = nil,
        locationLat: Double? = nil,
        locationLng: Double? = nil,
        brand: String? = nil,
        model: String? = nil,
        shippingCost: Decimal? = nil
    ) -> MarketplaceListingUpdate {
        var update = MarketplaceListingUpdate()
        update.title = title
        update.description = description
        update.price = price
        update.category = category
        update.condition = condition
        update.transactionType = transactionType
        update.status = status
        update.imageUrls = imageUrls
        update.locationName = locationName
        update.locationLat = locationLat
        update.locationLng = locationLng
        update.brand = brand
        update.model = model
        update.shippingCost = shippingCost
        return update
    }
}

// MARK: - MarketplaceService DI Note
// MarketplaceService calls Supabase directly without a protocol-based backend.
// To unit-test service methods, a protocol abstraction would need to be added
// (similar to BookingBackend in TestHelpers.swift). For now, only model-level
// tests are possible without network mocking.
