//
//  MarketplaceModelTests.swift
//  BuzzTests
//
//  Tests for Marketplace data models: MarketplaceListing, MarketplaceOffer,
//  MarketplaceTransaction, MarketplaceReview, enums, Codable conformance, etc.
//

import XCTest
@testable import Buzz

final class MarketplaceModelTests: XCTestCase {

    // MARK: - MarketplaceCategory Enum

    func testMarketplaceCategoryRawValues() {
        XCTAssertEqual(MarketplaceCategory.drones.rawValue, "drones")
        XCTAssertEqual(MarketplaceCategory.batteries.rawValue, "batteries")
        XCTAssertEqual(MarketplaceCategory.propellers.rawValue, "propellers")
        XCTAssertEqual(MarketplaceCategory.controllers.rawValue, "controllers")
        XCTAssertEqual(MarketplaceCategory.cameraGimbal.rawValue, "camera_gimbal")
        XCTAssertEqual(MarketplaceCategory.fpvGear.rawValue, "fpv_gear")
        XCTAssertEqual(MarketplaceCategory.casesBags.rawValue, "cases_bags")
        XCTAssertEqual(MarketplaceCategory.accessories.rawValue, "accessories")
        XCTAssertEqual(MarketplaceCategory.other.rawValue, "other")
    }

    func testMarketplaceCategoryAllCases() {
        XCTAssertEqual(MarketplaceCategory.allCases.count, 9)
    }

    func testMarketplaceCategoryDisplayNames() {
        XCTAssertEqual(MarketplaceCategory.drones.displayName, "Drones")
        XCTAssertEqual(MarketplaceCategory.cameraGimbal.displayName, "Camera & Gimbal")
        XCTAssertEqual(MarketplaceCategory.fpvGear.displayName, "FPV Gear")
        XCTAssertEqual(MarketplaceCategory.casesBags.displayName, "Cases & Bags")
    }

    func testMarketplaceCategoryIcons() {
        for category in MarketplaceCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty, "\(category) has empty icon")
        }
    }

    func testMarketplaceCategoryIdentifiable() {
        let category = MarketplaceCategory.drones
        XCTAssertEqual(category.id, "drones")
    }

    // MARK: - ListingCondition Enum

    func testListingConditionRawValues() {
        XCTAssertEqual(ListingCondition.new.rawValue, "new")
        XCTAssertEqual(ListingCondition.likeNew.rawValue, "like_new")
        XCTAssertEqual(ListingCondition.good.rawValue, "good")
        XCTAssertEqual(ListingCondition.fair.rawValue, "fair")
        XCTAssertEqual(ListingCondition.partsOnly.rawValue, "parts_only")
    }

    func testListingConditionAllCases() {
        XCTAssertEqual(ListingCondition.allCases.count, 5)
    }

    func testListingConditionDisplayNames() {
        XCTAssertEqual(ListingCondition.new.displayName, "New")
        XCTAssertEqual(ListingCondition.likeNew.displayName, "Like New")
        XCTAssertEqual(ListingCondition.partsOnly.displayName, "Parts Only")
    }

    func testListingConditionColors() {
        // Just verify colors don't crash and are distinct for key conditions
        XCTAssertNotNil(ListingCondition.new.color)
        XCTAssertNotNil(ListingCondition.partsOnly.color)
    }

    // MARK: - MarketplaceTransactionType Enum

    func testTransactionTypeRawValues() {
        XCTAssertEqual(MarketplaceTransactionType.ship.rawValue, "ship")
        XCTAssertEqual(MarketplaceTransactionType.meetup.rawValue, "meetup")
        XCTAssertEqual(MarketplaceTransactionType.both.rawValue, "both")
    }

    func testTransactionTypeAllCases() {
        XCTAssertEqual(MarketplaceTransactionType.allCases.count, 3)
    }

    func testTransactionTypeDisplayNames() {
        XCTAssertEqual(MarketplaceTransactionType.ship.displayName, "Ship")
        XCTAssertEqual(MarketplaceTransactionType.meetup.displayName, "Meetup")
        XCTAssertEqual(MarketplaceTransactionType.both.displayName, "Ship or Meetup")
    }

    func testTransactionTypeIcons() {
        for type in MarketplaceTransactionType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "\(type) has empty icon")
        }
    }

    // MARK: - ListingStatus Enum

    func testListingStatusRawValues() {
        XCTAssertEqual(ListingStatus.active.rawValue, "active")
        XCTAssertEqual(ListingStatus.sold.rawValue, "sold")
        XCTAssertEqual(ListingStatus.reserved.rawValue, "reserved")
        XCTAssertEqual(ListingStatus.expired.rawValue, "expired")
        XCTAssertEqual(ListingStatus.removed.rawValue, "removed")
    }

    func testListingStatusDisplayNames() {
        XCTAssertEqual(ListingStatus.active.displayName, "Active")
        XCTAssertEqual(ListingStatus.sold.displayName, "Sold")
        XCTAssertEqual(ListingStatus.reserved.displayName, "Reserved")
        XCTAssertEqual(ListingStatus.expired.displayName, "Expired")
        XCTAssertEqual(ListingStatus.removed.displayName, "Removed")
    }

    func testListingStatusColors() {
        XCTAssertNotNil(ListingStatus.active.color)
        XCTAssertNotNil(ListingStatus.sold.color)
        XCTAssertNotNil(ListingStatus.removed.color)
    }

    // MARK: - MarketplaceOfferStatus Enum

    func testOfferStatusRawValues() {
        XCTAssertEqual(MarketplaceOfferStatus.pending.rawValue, "pending")
        XCTAssertEqual(MarketplaceOfferStatus.accepted.rawValue, "accepted")
        XCTAssertEqual(MarketplaceOfferStatus.declined.rawValue, "declined")
        XCTAssertEqual(MarketplaceOfferStatus.withdrawn.rawValue, "withdrawn")
        XCTAssertEqual(MarketplaceOfferStatus.expired.rawValue, "expired")
    }

    func testOfferStatusDisplayNames() {
        XCTAssertEqual(MarketplaceOfferStatus.pending.displayName, "Pending")
        XCTAssertEqual(MarketplaceOfferStatus.accepted.displayName, "Accepted")
        XCTAssertEqual(MarketplaceOfferStatus.declined.displayName, "Declined")
        XCTAssertEqual(MarketplaceOfferStatus.withdrawn.displayName, "Withdrawn")
        XCTAssertEqual(MarketplaceOfferStatus.expired.displayName, "Expired")
    }

    func testOfferStatusColors() {
        XCTAssertNotNil(MarketplaceOfferStatus.pending.color)
        XCTAssertNotNil(MarketplaceOfferStatus.accepted.color)
        XCTAssertNotNil(MarketplaceOfferStatus.declined.color)
    }

    // MARK: - MarketplaceTransactionStatus Enum

    func testTransactionStatusRawValues() {
        XCTAssertEqual(MarketplaceTransactionStatus.pendingPayment.rawValue, "pending_payment")
        XCTAssertEqual(MarketplaceTransactionStatus.paid.rawValue, "paid")
        XCTAssertEqual(MarketplaceTransactionStatus.shipped.rawValue, "shipped")
        XCTAssertEqual(MarketplaceTransactionStatus.delivered.rawValue, "delivered")
        XCTAssertEqual(MarketplaceTransactionStatus.releasing.rawValue, "releasing")
        XCTAssertEqual(MarketplaceTransactionStatus.completed.rawValue, "completed")
        XCTAssertEqual(MarketplaceTransactionStatus.meetupScheduled.rawValue, "meetup_scheduled")
        XCTAssertEqual(MarketplaceTransactionStatus.meetupCompleted.rawValue, "meetup_completed")
        XCTAssertEqual(MarketplaceTransactionStatus.disputed.rawValue, "disputed")
        XCTAssertEqual(MarketplaceTransactionStatus.refunded.rawValue, "refunded")
        XCTAssertEqual(MarketplaceTransactionStatus.cancelled.rawValue, "cancelled")
    }

    func testTransactionStatusDisplayNames() {
        XCTAssertEqual(MarketplaceTransactionStatus.pendingPayment.displayName, "Pending Payment")
        XCTAssertEqual(MarketplaceTransactionStatus.releasing.displayName, "Releasing Payout")
        XCTAssertEqual(MarketplaceTransactionStatus.meetupScheduled.displayName, "Meetup Scheduled")
        XCTAssertEqual(MarketplaceTransactionStatus.meetupCompleted.displayName, "Meetup Complete")
    }

    func testTransactionStatusIcons() {
        let allStatuses: [MarketplaceTransactionStatus] = [
            .pendingPayment, .paid, .shipped, .delivered, .releasing, .completed,
            .meetupScheduled, .meetupCompleted, .disputed, .refunded, .cancelled
        ]
        for status in allStatuses {
            XCTAssertFalse(status.icon.isEmpty, "\(status) has empty icon")
        }
    }

    func testTransactionStatusColors() {
        let allStatuses: [MarketplaceTransactionStatus] = [
            .pendingPayment, .paid, .shipped, .delivered, .releasing, .completed,
            .meetupScheduled, .meetupCompleted, .disputed, .refunded, .cancelled
        ]
        for status in allStatuses {
            XCTAssertNotNil(status.color, "\(status) has nil color")
        }
    }

    // MARK: - MarketplaceSortOption Enum

    func testSortOptionRawValues() {
        XCTAssertEqual(MarketplaceSortOption.newest.rawValue, "newest")
        XCTAssertEqual(MarketplaceSortOption.priceLowToHigh.rawValue, "priceLowToHigh")
        XCTAssertEqual(MarketplaceSortOption.priceHighToLow.rawValue, "priceHighToLow")
    }

    func testSortOptionAllCases() {
        XCTAssertEqual(MarketplaceSortOption.allCases.count, 3)
    }

    func testSortOptionDisplayNames() {
        XCTAssertEqual(MarketplaceSortOption.newest.displayName, "Newest")
        XCTAssertEqual(MarketplaceSortOption.priceLowToHigh.displayName, "Price: Low to High")
        XCTAssertEqual(MarketplaceSortOption.priceHighToLow.displayName, "Price: High to Low")
    }

    // MARK: - MarketplaceListing

    func testListingCreation() {
        let listing = MarketplaceTestData.sampleListing(
            title: "DJI Air 3",
            price: 799.00,
            category: .drones,
            condition: .new
        )
        XCTAssertEqual(listing.title, "DJI Air 3")
        XCTAssertEqual(listing.price, 799.00)
        XCTAssertEqual(listing.category, .drones)
        XCTAssertEqual(listing.condition, .new)
        XCTAssertEqual(listing.status, .active)
    }

    func testListingAllProperties() {
        let id = UUID()
        let sellerId = UUID()
        let now = Date()
        let listing = MarketplaceTestData.sampleListing(
            id: id,
            sellerId: sellerId,
            title: "Test Drone",
            description: "A test drone",
            price: 100,
            category: .batteries,
            condition: .fair,
            transactionType: .meetup,
            status: .reserved,
            imageUrls: ["img1.jpg"],
            locationName: "NYC",
            locationLat: 40.7128,
            locationLng: -74.0060,
            brand: "Autel",
            model: "EVO II",
            shippingCost: 10.00,
            viewCount: 100,
            favoriteCount: 20,
            offerCount: 3,
            createdAt: now,
            updatedAt: now,
            expiresAt: now
        )
        XCTAssertEqual(listing.id, id)
        XCTAssertEqual(listing.sellerId, sellerId)
        XCTAssertEqual(listing.brand, "Autel")
        XCTAssertEqual(listing.model, "EVO II")
        XCTAssertEqual(listing.shippingCost, 10.00)
        XCTAssertEqual(listing.viewCount, 100)
        XCTAssertEqual(listing.favoriteCount, 20)
        XCTAssertEqual(listing.offerCount, 3)
        XCTAssertEqual(listing.locationName, "NYC")
        XCTAssertEqual(listing.locationLat, 40.7128)
        XCTAssertEqual(listing.locationLng, -74.0060)
        XCTAssertEqual(listing.expiresAt, now)
    }

    func testListingFormattedPrice() {
        let listing = MarketplaceTestData.sampleListing(price: 599.99)
        XCTAssertTrue(listing.formattedPrice.contains("599.99"))
    }

    func testListingFormattedPriceZero() {
        let listing = MarketplaceTestData.sampleListing(price: 0)
        XCTAssertTrue(listing.formattedPrice.contains("0.00"))
    }

    func testListingFormattedPriceOneCent() {
        let listing = MarketplaceTestData.sampleListing(price: 0.01)
        XCTAssertTrue(listing.formattedPrice.contains("0.01"))
    }

    func testListingFormattedPriceLargeAmount() {
        let listing = MarketplaceTestData.sampleListing(price: 99999.99)
        XCTAssertTrue(listing.formattedPrice.contains("99,999.99") || listing.formattedPrice.contains("99999.99"))
    }

    func testListingDefaultOptionalFields() {
        let listing = MarketplaceTestData.sampleListing(
            locationName: nil,
            locationLat: nil,
            locationLng: nil,
            brand: nil,
            model: nil,
            shippingCost: nil,
            expiresAt: nil
        )
        XCTAssertNil(listing.locationName)
        XCTAssertNil(listing.locationLat)
        XCTAssertNil(listing.locationLng)
        XCTAssertNil(listing.brand)
        XCTAssertNil(listing.model)
        XCTAssertNil(listing.shippingCost)
        XCTAssertNil(listing.expiresAt)
    }

    func testListingDefaultImageUrlsEmpty() {
        let listing = MarketplaceTestData.sampleListing(imageUrls: [])
        XCTAssertTrue(listing.imageUrls.isEmpty)
    }

    func testListingCodableRoundTrip() throws {
        let original = MarketplaceTestData.sampleListing(
            title: "Roundtrip Drone",
            price: 450.50,
            category: .fpvGear,
            condition: .good,
            imageUrls: ["https://example.com/fpv.jpg"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MarketplaceListing.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, "Roundtrip Drone")
        XCTAssertEqual(decoded.price, 450.50)
        XCTAssertEqual(decoded.category, .fpvGear)
        XCTAssertEqual(decoded.condition, .good)
        XCTAssertEqual(decoded.imageUrls, ["https://example.com/fpv.jpg"])
        XCTAssertEqual(decoded.sellerId, original.sellerId)
        XCTAssertEqual(decoded.transactionType, original.transactionType)
        XCTAssertEqual(decoded.status, original.status)
    }

    func testListingCodingKeysSnakeCase() throws {
        let id = UUID()
        let sellerId = UUID()
        let isoDate = ISO8601DateFormatter().string(from: Date())

        let json: [String: Any] = [
            "id": id.uuidString,
            "seller_id": sellerId.uuidString,
            "title": "Snake Case Test",
            "description": "Testing snake_case keys",
            "price": 199.99,
            "category": "drones",
            "condition": "like_new",
            "transaction_type": "both",
            "status": "active",
            "image_urls": ["img.jpg"],
            "location_name": "Denver, CO",
            "location_lat": 39.7392,
            "location_lng": -104.9903,
            "brand": "DJI",
            "model": "Mini 3",
            "shipping_cost": 9.99,
            "view_count": 10,
            "favorite_count": 2,
            "offer_count": 1,
            "created_at": isoDate,
            "updated_at": isoDate,
            "expires_at": isoDate
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let listing = try decoder.decode(MarketplaceListing.self, from: data)

        XCTAssertEqual(listing.id, id)
        XCTAssertEqual(listing.sellerId, sellerId)
        XCTAssertEqual(listing.title, "Snake Case Test")
        XCTAssertEqual(listing.category, .drones)
        XCTAssertEqual(listing.condition, .likeNew)
        XCTAssertEqual(listing.transactionType, .both)
        XCTAssertEqual(listing.locationName, "Denver, CO")
        XCTAssertEqual(listing.brand, "DJI")
        XCTAssertEqual(listing.viewCount, 10)
        XCTAssertNotNil(listing.expiresAt)
    }

    func testListingDecodingMissingOptionalFields() throws {
        let id = UUID()
        let sellerId = UUID()
        let isoDate = ISO8601DateFormatter().string(from: Date())

        let json: [String: Any] = [
            "id": id.uuidString,
            "seller_id": sellerId.uuidString,
            "title": "Minimal Listing",
            "description": "No optional fields",
            "price": 50,
            "category": "accessories",
            "condition": "fair",
            "transaction_type": "meetup",
            "status": "active",
            "created_at": isoDate,
            "updated_at": isoDate
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let listing = try decoder.decode(MarketplaceListing.self, from: data)

        XCTAssertEqual(listing.title, "Minimal Listing")
        XCTAssertTrue(listing.imageUrls.isEmpty, "imageUrls should default to empty when missing")
        XCTAssertNil(listing.locationName)
        XCTAssertNil(listing.brand)
        XCTAssertNil(listing.model)
        XCTAssertNil(listing.shippingCost)
        XCTAssertEqual(listing.viewCount, 0, "viewCount should default to 0 when missing")
        XCTAssertEqual(listing.favoriteCount, 0, "favoriteCount should default to 0 when missing")
        XCTAssertEqual(listing.offerCount, 0, "offerCount should default to 0 when missing")
        XCTAssertNil(listing.expiresAt)
    }

    func testListingEmptyTitleAndDescription() {
        let listing = MarketplaceTestData.sampleListing(title: "", description: "")
        XCTAssertEqual(listing.title, "")
        XCTAssertEqual(listing.description, "")
    }

    // MARK: - Currency Formatter

    func testCurrencyFormatterIsUSD() {
        let formatter = MarketplaceListing.currencyFormatter
        XCTAssertEqual(formatter.currencyCode, "USD")
        XCTAssertEqual(formatter.numberStyle, .currency)
    }

    func testCurrencyFormatterOutput() {
        let formatter = MarketplaceListing.currencyFormatter
        let result = formatter.string(from: NSDecimalNumber(decimal: 1234.56))
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("1,234.56") || result!.contains("1234.56"))
    }

    // MARK: - MarketplaceListingWithSeller

    func testListingWithSellerCreation() {
        let lws = MarketplaceTestData.sampleListingWithSeller(
            sellerCallSign: "TopGun",
            sellerFullName: "Pete Mitchell"
        )
        XCTAssertEqual(lws.sellerCallSign, "TopGun")
        XCTAssertEqual(lws.sellerFullName, "Pete Mitchell")
        XCTAssertFalse(lws.isFavoritedByCurrentUser)
    }

    func testListingWithSellerNilCallSign() {
        let lws = MarketplaceTestData.sampleListingWithSeller(
            sellerCallSign: nil,
            sellerFullName: "No Callsign"
        )
        XCTAssertNil(lws.sellerCallSign)
        XCTAssertEqual(lws.sellerFullName, "No Callsign")
    }

    func testListingWithSellerFavoriteToggle() {
        var lws = MarketplaceTestData.sampleListingWithSeller(isFavoritedByCurrentUser: false)
        XCTAssertFalse(lws.isFavoritedByCurrentUser)

        lws.isFavoritedByCurrentUser = true
        XCTAssertTrue(lws.isFavoritedByCurrentUser)
    }

    func testListingWithSellerUsesProvidedListing() {
        let listing = MarketplaceTestData.sampleListing(title: "Custom Listing", price: 123.45)
        let lws = MarketplaceTestData.sampleListingWithSeller(listing: listing)
        XCTAssertEqual(lws.listing.title, "Custom Listing")
        XCTAssertEqual(lws.listing.price, 123.45)
    }

    // MARK: - MarketplaceFavorite

    func testFavoriteCodingKeys() throws {
        let id = UUID()
        let userId = UUID()
        let listingId = UUID()
        let isoDate = ISO8601DateFormatter().string(from: Date())

        let json: [String: Any] = [
            "id": id.uuidString,
            "user_id": userId.uuidString,
            "listing_id": listingId.uuidString,
            "created_at": isoDate
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let favorite = try decoder.decode(MarketplaceFavorite.self, from: data)

        XCTAssertEqual(favorite.id, id)
        XCTAssertEqual(favorite.userId, userId)
        XCTAssertEqual(favorite.listingId, listingId)
    }

    func testFavoriteCodableRoundTrip() throws {
        let original = MarketplaceFavorite(
            id: UUID(), userId: UUID(), listingId: UUID(), createdAt: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MarketplaceFavorite.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.userId, original.userId)
        XCTAssertEqual(decoded.listingId, original.listingId)
    }

    // MARK: - MarketplaceOffer

    func testOfferCreation() {
        let offer = MarketplaceTestData.sampleOffer(
            amount: 250.00,
            message: "Best offer",
            status: .pending
        )
        XCTAssertEqual(offer.amount, 250.00)
        XCTAssertEqual(offer.message, "Best offer")
        XCTAssertEqual(offer.status, .pending)
    }

    func testOfferFormattedAmount() {
        let offer = MarketplaceTestData.sampleOffer(amount: 299.99)
        XCTAssertTrue(offer.formattedAmount.contains("299.99"))
    }

    func testOfferFormattedAmountZero() {
        let offer = MarketplaceTestData.sampleOffer(amount: 0)
        XCTAssertTrue(offer.formattedAmount.contains("0.00"))
    }

    func testOfferNilMessage() {
        let offer = MarketplaceTestData.sampleOffer(message: nil)
        XCTAssertNil(offer.message)
    }

    func testOfferAllStatuses() {
        let statuses: [MarketplaceOfferStatus] = [.pending, .accepted, .declined, .withdrawn, .expired]
        for status in statuses {
            let offer = MarketplaceTestData.sampleOffer(status: status)
            XCTAssertEqual(offer.status, status)
        }
    }

    func testOfferCodableRoundTrip() throws {
        let original = MarketplaceTestData.sampleOffer(
            amount: 175.50,
            message: "Encode test",
            status: .accepted
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MarketplaceOffer.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.listingId, original.listingId)
        XCTAssertEqual(decoded.buyerId, original.buyerId)
        XCTAssertEqual(decoded.amount, 175.50)
        XCTAssertEqual(decoded.message, "Encode test")
        XCTAssertEqual(decoded.status, .accepted)
    }

    func testOfferCodingKeysSnakeCase() throws {
        let id = UUID()
        let listingId = UUID()
        let buyerId = UUID()
        let isoDate = ISO8601DateFormatter().string(from: Date())

        let json: [String: Any] = [
            "id": id.uuidString,
            "listing_id": listingId.uuidString,
            "buyer_id": buyerId.uuidString,
            "amount": 200.00,
            "message": "Test",
            "status": "pending",
            "created_at": isoDate,
            "updated_at": isoDate
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let offer = try decoder.decode(MarketplaceOffer.self, from: data)

        XCTAssertEqual(offer.id, id)
        XCTAssertEqual(offer.listingId, listingId)
        XCTAssertEqual(offer.buyerId, buyerId)
        XCTAssertEqual(offer.status, .pending)
    }

    // MARK: - MarketplaceOfferInsert

    func testOfferInsertEncoding() throws {
        let insert = MarketplaceOfferInsert(
            listingId: UUID(),
            buyerId: UUID(),
            amount: 350.00,
            message: "I want this"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(insert)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(dict?["listing_id"])
        XCTAssertNotNil(dict?["buyer_id"])
        XCTAssertEqual(dict?["amount"] as? Double, 350.00)
        XCTAssertEqual(dict?["message"] as? String, "I want this")
    }

    func testOfferInsertNilMessage() throws {
        let insert = MarketplaceOfferInsert(
            listingId: UUID(),
            buyerId: UUID(),
            amount: 100,
            message: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(insert)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // message should be null or absent
        if let messageValue = dict?["message"] {
            XCTAssertTrue(messageValue is NSNull)
        }
    }

    // MARK: - MarketplaceOfferResponse

    func testOfferResponseDecoding() throws {
        let json = MarketplaceTestData.sampleOfferResponseJSON(
            amount: 250.00,
            status: .accepted,
            buyerCallSign: "TestBuyer",
            buyerFirstName: "Alice",
            buyerLastName: "Smith"
        )

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(MarketplaceOfferResponse.self, from: data)

        XCTAssertEqual(response.status, .accepted)
        XCTAssertNotNil(response.profileData)
        XCTAssertEqual(response.profileData?.callSign, "TestBuyer")
        XCTAssertEqual(response.profileData?.firstName, "Alice")
        XCTAssertEqual(response.profileData?.lastName, "Smith")
    }

    func testOfferResponseFormattedAmount() throws {
        let json = MarketplaceTestData.sampleOfferResponseJSON(amount: 500.00)

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(MarketplaceOfferResponse.self, from: data)

        XCTAssertTrue(response.formattedAmount.contains("500.00"))
    }

    func testOfferResponseNilProfile() throws {
        let isoDate = ISO8601DateFormatter().string(from: Date())
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "listing_id": UUID().uuidString,
            "buyer_id": UUID().uuidString,
            "amount": 100,
            "status": "pending",
            "created_at": isoDate,
            "updated_at": isoDate
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(MarketplaceOfferResponse.self, from: data)

        XCTAssertNil(response.profiles)
        XCTAssertNil(response.profileData)
    }

    // MARK: - MarketplaceTransaction

    func testTransactionCreation() {
        let tx = MarketplaceTestData.sampleTransaction(
            status: .paid,
            amount: 500.00,
            platformFee: 50.00,
            sellerPayout: 450.00
        )
        XCTAssertEqual(tx.status, .paid)
        XCTAssertEqual(tx.amount, 500.00)
        XCTAssertEqual(tx.platformFee, 50.00)
        XCTAssertEqual(tx.sellerPayout, 450.00)
    }

    func testTransactionFormattedAmount() {
        let tx = MarketplaceTestData.sampleTransaction(amount: 349.99)
        XCTAssertTrue(tx.formattedAmount.contains("349.99"))
    }

    func testTransactionFormattedAmountZero() {
        let tx = MarketplaceTestData.sampleTransaction(amount: 0)
        XCTAssertTrue(tx.formattedAmount.contains("0.00"))
    }

    func testTransactionAllProperties() {
        let id = UUID()
        let listingId = UUID()
        let buyerId = UUID()
        let sellerId = UUID()
        let offerId = UUID()
        let now = Date()

        let tx = MarketplaceTestData.sampleTransaction(
            id: id,
            listingId: listingId,
            buyerId: buyerId,
            sellerId: sellerId,
            offerId: offerId,
            transactionType: .meetup,
            status: .meetupScheduled,
            amount: 200,
            platformFee: 20,
            sellerPayout: 180,
            paymentIntentId: "pi_abc",
            chargeId: "ch_123",
            transferId: "tr_456",
            trackingNumber: "1Z999AA10123456784",
            trackingCarrier: "UPS",
            meetupLocationName: "Central Park",
            meetupLocationLat: 40.7829,
            meetupLocationLng: -73.9654,
            meetupScheduledAt: now,
            buyerConfirmedAt: now,
            sellerConfirmedAt: now,
            shippedAt: now,
            deliveredAt: now,
            completedAt: now,
            cancelledAt: nil,
            cancellationReason: nil,
            createdAt: now,
            updatedAt: now
        )

        XCTAssertEqual(tx.id, id)
        XCTAssertEqual(tx.offerId, offerId)
        XCTAssertEqual(tx.transactionType, .meetup)
        XCTAssertEqual(tx.paymentIntentId, "pi_abc")
        XCTAssertEqual(tx.chargeId, "ch_123")
        XCTAssertEqual(tx.transferId, "tr_456")
        XCTAssertEqual(tx.trackingNumber, "1Z999AA10123456784")
        XCTAssertEqual(tx.trackingCarrier, "UPS")
        XCTAssertEqual(tx.meetupLocationName, "Central Park")
        XCTAssertNotNil(tx.buyerConfirmedAt)
        XCTAssertNotNil(tx.sellerConfirmedAt)
        XCTAssertNotNil(tx.completedAt)
        XCTAssertNil(tx.cancelledAt)
    }

    func testTransactionAllStatuses() {
        let statuses: [MarketplaceTransactionStatus] = [
            .pendingPayment, .paid, .shipped, .delivered, .completed,
            .meetupScheduled, .meetupCompleted, .disputed, .refunded, .cancelled
        ]
        for status in statuses {
            let tx = MarketplaceTestData.sampleTransaction(status: status)
            XCTAssertEqual(tx.status, status)
        }
    }

    func testTransactionCodableRoundTrip() throws {
        let original = MarketplaceTestData.sampleTransaction(
            transactionType: .ship,
            status: .shipped,
            amount: 400,
            platformFee: 40,
            sellerPayout: 360,
            trackingNumber: "TRACK123",
            trackingCarrier: "FedEx"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MarketplaceTransaction.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.transactionType, .ship)
        XCTAssertEqual(decoded.status, .shipped)
        XCTAssertEqual(decoded.amount, 400)
        XCTAssertEqual(decoded.platformFee, 40)
        XCTAssertEqual(decoded.sellerPayout, 360)
        XCTAssertEqual(decoded.trackingNumber, "TRACK123")
        XCTAssertEqual(decoded.trackingCarrier, "FedEx")
    }

    func testTransactionDecodingNullFinancialFields() throws {
        let isoDate = ISO8601DateFormatter().string(from: Date())
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "listing_id": UUID().uuidString,
            "buyer_id": UUID().uuidString,
            "seller_id": UUID().uuidString,
            "transaction_type": "ship",
            "status": "pending_payment",
            "created_at": isoDate,
            "updated_at": isoDate
            // amount, platform_fee, seller_payout intentionally omitted
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let tx = try decoder.decode(MarketplaceTransaction.self, from: data)

        XCTAssertEqual(tx.amount, 0, "amount should default to 0 when missing")
        XCTAssertEqual(tx.platformFee, 0, "platformFee should default to 0 when missing")
        XCTAssertEqual(tx.sellerPayout, 0, "sellerPayout should default to 0 when missing")
    }

    func testTransactionDecodingWithExplicitNullFinancials() throws {
        let isoDate = ISO8601DateFormatter().string(from: Date())
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "listing_id": UUID().uuidString,
            "buyer_id": UUID().uuidString,
            "seller_id": UUID().uuidString,
            "transaction_type": "meetup",
            "status": "completed",
            "amount": NSNull(),
            "platform_fee": NSNull(),
            "seller_payout": NSNull(),
            "created_at": isoDate,
            "updated_at": isoDate
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let tx = try decoder.decode(MarketplaceTransaction.self, from: data)

        XCTAssertEqual(tx.amount, 0, "amount should default to 0 for null")
        XCTAssertEqual(tx.platformFee, 0, "platformFee should default to 0 for null")
        XCTAssertEqual(tx.sellerPayout, 0, "sellerPayout should default to 0 for null")
    }

    func testTransactionCodingKeysSnakeCase() throws {
        let isoDate = ISO8601DateFormatter().string(from: Date())
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "listing_id": UUID().uuidString,
            "buyer_id": UUID().uuidString,
            "seller_id": UUID().uuidString,
            "offer_id": UUID().uuidString,
            "transaction_type": "ship",
            "status": "shipped",
            "amount": 300,
            "platform_fee": 30,
            "seller_payout": 270,
            "payment_intent_id": "pi_test",
            "charge_id": "ch_test",
            "transfer_id": "tr_test",
            "tracking_number": "TRACK",
            "tracking_carrier": "USPS",
            "meetup_location_name": "Park",
            "meetup_location_lat": 40.0,
            "meetup_location_lng": -74.0,
            "meetup_scheduled_at": isoDate,
            "buyer_confirmed_at": isoDate,
            "seller_confirmed_at": isoDate,
            "shipped_at": isoDate,
            "delivered_at": isoDate,
            "completed_at": isoDate,
            "cancelled_at": isoDate,
            "cancellation_reason": "Changed mind",
            "created_at": isoDate,
            "updated_at": isoDate
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let tx = try decoder.decode(MarketplaceTransaction.self, from: data)

        XCTAssertNotNil(tx.offerId)
        XCTAssertEqual(tx.paymentIntentId, "pi_test")
        XCTAssertEqual(tx.chargeId, "ch_test")
        XCTAssertEqual(tx.transferId, "tr_test")
        XCTAssertEqual(tx.trackingNumber, "TRACK")
        XCTAssertEqual(tx.trackingCarrier, "USPS")
        XCTAssertEqual(tx.meetupLocationName, "Park")
        XCTAssertNotNil(tx.meetupScheduledAt)
        XCTAssertNotNil(tx.buyerConfirmedAt)
        XCTAssertNotNil(tx.sellerConfirmedAt)
        XCTAssertNotNil(tx.shippedAt)
        XCTAssertNotNil(tx.deliveredAt)
        XCTAssertNotNil(tx.completedAt)
        XCTAssertNotNil(tx.cancelledAt)
        XCTAssertEqual(tx.cancellationReason, "Changed mind")
    }

    // MARK: - MarketplaceTransactionWithDetails

    func testTransactionWithDetailsCreation() {
        let tx = MarketplaceTestData.sampleTransaction()
        let details = MarketplaceTransactionWithDetails(
            id: tx.id,
            transaction: tx,
            listingTitle: "DJI Mini 4 Pro",
            listingImageUrl: "https://example.com/img.jpg",
            partnerCallSign: "BuyerCS",
            partnerProfilePictureUrl: nil,
            partnerFullName: "Jane Buyer",
            isBuyer: false
        )
        XCTAssertEqual(details.listingTitle, "DJI Mini 4 Pro")
        XCTAssertEqual(details.partnerCallSign, "BuyerCS")
        XCTAssertFalse(details.isBuyer)
    }

    func testTransactionWithDetailsAsBuyer() {
        let tx = MarketplaceTestData.sampleTransaction()
        let details = MarketplaceTransactionWithDetails(
            id: tx.id,
            transaction: tx,
            listingTitle: "Test Item",
            listingImageUrl: nil,
            partnerCallSign: nil,
            partnerProfilePictureUrl: nil,
            partnerFullName: "Seller Name",
            isBuyer: true
        )
        XCTAssertTrue(details.isBuyer)
        XCTAssertNil(details.partnerCallSign)
        XCTAssertNil(details.listingImageUrl)
    }

    // MARK: - MarketplaceReview

    func testReviewCreation() {
        let review = MarketplaceTestData.sampleReview(
            rating: 4,
            comment: "Good transaction"
        )
        XCTAssertEqual(review.rating, 4)
        XCTAssertEqual(review.comment, "Good transaction")
    }

    func testReviewNilComment() {
        let review = MarketplaceTestData.sampleReview(comment: nil)
        XCTAssertNil(review.comment)
    }

    func testReviewRatingBounds() {
        let low = MarketplaceTestData.sampleReview(rating: 1)
        XCTAssertEqual(low.rating, 1)

        let high = MarketplaceTestData.sampleReview(rating: 5)
        XCTAssertEqual(high.rating, 5)

        let zero = MarketplaceTestData.sampleReview(rating: 0)
        XCTAssertEqual(zero.rating, 0)
    }

    func testReviewCodableRoundTrip() throws {
        let original = MarketplaceTestData.sampleReview(
            rating: 3,
            comment: "Codable test"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MarketplaceReview.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.transactionId, original.transactionId)
        XCTAssertEqual(decoded.fromUserId, original.fromUserId)
        XCTAssertEqual(decoded.toUserId, original.toUserId)
        XCTAssertEqual(decoded.rating, 3)
        XCTAssertEqual(decoded.comment, "Codable test")
    }

    func testReviewCodingKeys() throws {
        let isoDate = ISO8601DateFormatter().string(from: Date())
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "transaction_id": UUID().uuidString,
            "from_user_id": UUID().uuidString,
            "to_user_id": UUID().uuidString,
            "rating": 5,
            "comment": "Excellent!",
            "created_at": isoDate
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let review = try decoder.decode(MarketplaceReview.self, from: data)

        XCTAssertEqual(review.rating, 5)
        XCTAssertEqual(review.comment, "Excellent!")
    }

    // MARK: - MarketplaceReviewWithProfile

    func testReviewWithProfileCreation() {
        let review = MarketplaceTestData.sampleReview()
        let rwp = MarketplaceReviewWithProfile(
            id: review.id,
            review: review,
            reviewerCallSign: "ReviewerCS",
            reviewerProfilePictureUrl: nil,
            reviewerFullName: "Reviewer Name"
        )
        XCTAssertEqual(rwp.reviewerCallSign, "ReviewerCS")
        XCTAssertEqual(rwp.reviewerFullName, "Reviewer Name")
        XCTAssertNil(rwp.reviewerProfilePictureUrl)
    }

    // MARK: - MarketplaceListingInsert

    func testListingInsertEncoding() throws {
        let insert = MarketplaceTestData.sampleListingInsert(
            title: "New Listing",
            price: 799.99,
            category: .controllers,
            condition: .new
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(insert)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(dict?["title"] as? String, "New Listing")
        XCTAssertNotNil(dict?["seller_id"])
        XCTAssertNotNil(dict?["image_urls"])
        XCTAssertEqual(dict?["category"] as? String, "controllers")
        XCTAssertEqual(dict?["condition"] as? String, "new")
        XCTAssertEqual(dict?["transaction_type"] as? String, "ship")
    }

    func testListingInsertSnakeCaseKeys() throws {
        let insert = MarketplaceTestData.sampleListingInsert(
            locationName: "Test City",
            locationLat: 35.0,
            locationLng: -120.0,
            shippingCost: 5.99
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(insert)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(dict?["location_name"])
        XCTAssertNotNil(dict?["location_lat"])
        XCTAssertNotNil(dict?["location_lng"])
        XCTAssertNotNil(dict?["shipping_cost"])
        // Should NOT have camelCase keys
        XCTAssertNil(dict?["locationName"])
        XCTAssertNil(dict?["sellerId"])
        XCTAssertNil(dict?["transactionType"])
        XCTAssertNil(dict?["imageUrls"])
        XCTAssertNil(dict?["shippingCost"])
    }

    func testListingInsertAllFieldsPresent() throws {
        let insert = MarketplaceTestData.sampleListingInsert()

        let encoder = JSONEncoder()
        let data = try encoder.encode(insert)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        let requiredKeys = ["seller_id", "title", "description", "price",
                            "category", "condition", "transaction_type", "image_urls"]
        for key in requiredKeys {
            XCTAssertNotNil(dict?[key], "Missing required key: \(key)")
        }
    }

    // MARK: - MarketplaceListingUpdate

    func testListingUpdateOnlyIncludesSetFields() throws {
        let update = MarketplaceTestData.sampleListingUpdate(
            title: "New Title",
            price: 199.99
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(update)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(dict?["title"] as? String, "New Title")
        XCTAssertNotNil(dict?["price"])
        // Fields not set should be absent from encoded output
        XCTAssertNil(dict?["description"])
        XCTAssertNil(dict?["category"])
        XCTAssertNil(dict?["condition"])
        XCTAssertNil(dict?["status"])
        XCTAssertNil(dict?["image_urls"])
        XCTAssertNil(dict?["brand"])
        XCTAssertNil(dict?["model"])
    }

    func testListingUpdateEmptyEncoding() throws {
        var update = MarketplaceListingUpdate()
        update.title = nil // explicitly ensure no fields set

        let encoder = JSONEncoder()
        let data = try encoder.encode(update)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertTrue(dict?.isEmpty ?? true, "Empty update should encode to empty object")
    }

    func testListingUpdateAllFields() throws {
        var update = MarketplaceListingUpdate()
        update.title = "Full Update"
        update.description = "Updated description"
        update.price = 999.99
        update.category = "batteries"
        update.condition = "good"
        update.transactionType = "meetup"
        update.status = "sold"
        update.imageUrls = ["new_img.jpg"]
        update.locationName = "New City"
        update.locationLat = 40.0
        update.locationLng = -74.0
        update.brand = "NewBrand"
        update.model = "NewModel"
        update.shippingCost = 12.99

        let encoder = JSONEncoder()
        let data = try encoder.encode(update)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(dict?.count, 14, "All 14 fields should be present")
        XCTAssertEqual(dict?["title"] as? String, "Full Update")
        XCTAssertEqual(dict?["status"] as? String, "sold")
        XCTAssertEqual(dict?["transaction_type"] as? String, "meetup")
        XCTAssertEqual(dict?["location_name"] as? String, "New City")
    }

    func testListingUpdateSnakeCaseKeys() throws {
        var update = MarketplaceListingUpdate()
        update.transactionType = "ship"
        update.imageUrls = ["img.jpg"]
        update.locationName = "Test"
        update.locationLat = 35.0
        update.locationLng = -120.0
        update.shippingCost = 5.00

        let encoder = JSONEncoder()
        let data = try encoder.encode(update)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(dict?["transaction_type"])
        XCTAssertNotNil(dict?["image_urls"])
        XCTAssertNotNil(dict?["location_name"])
        XCTAssertNotNil(dict?["location_lat"])
        XCTAssertNotNil(dict?["location_lng"])
        XCTAssertNotNil(dict?["shipping_cost"])
        // Should NOT have camelCase keys
        XCTAssertNil(dict?["transactionType"])
        XCTAssertNil(dict?["imageUrls"])
        XCTAssertNil(dict?["locationName"])
        XCTAssertNil(dict?["shippingCost"])
    }

    // MARK: - MarketplacePaymentResponse

    func testPaymentResponseDecoding() throws {
        let json: [String: Any] = [
            "client_secret": "pi_test_secret_abc123",
            "payment_intent_id": "pi_test_123",
            "customer_id": "cus_test_456",
            "ephemeral_key_secret": "ek_test_789",
            "platform_fee": 1500,
            "seller_payout": 13500
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let response = try JSONDecoder().decode(MarketplacePaymentResponse.self, from: data)

        XCTAssertEqual(response.clientSecret, "pi_test_secret_abc123")
        XCTAssertEqual(response.paymentIntentId, "pi_test_123")
        XCTAssertEqual(response.customerId, "cus_test_456")
        XCTAssertEqual(response.ephemeralKeySecret, "ek_test_789")
        XCTAssertEqual(response.platformFee, 1500)
        XCTAssertEqual(response.sellerPayout, 13500)
    }

    func testPaymentResponseMinimalDecoding() throws {
        let json: [String: Any] = [
            "client_secret": "pi_secret",
            "payment_intent_id": "pi_id"
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let response = try JSONDecoder().decode(MarketplacePaymentResponse.self, from: data)

        XCTAssertEqual(response.clientSecret, "pi_secret")
        XCTAssertEqual(response.paymentIntentId, "pi_id")
        XCTAssertNil(response.customerId)
        XCTAssertNil(response.ephemeralKeySecret)
        XCTAssertNil(response.platformFee)
        XCTAssertNil(response.sellerPayout)
    }

    // MARK: - MarketplaceListingResponse (Supabase join)

    func testListingResponseDecodingWithProfile() throws {
        let id = UUID()
        let sellerId = UUID()
        let isoDate = ISO8601DateFormatter().string(from: Date())

        let json: [String: Any] = [
            "id": id.uuidString,
            "seller_id": sellerId.uuidString,
            "title": "Response Test",
            "description": "Testing listing response",
            "price": 350,
            "category": "drones",
            "condition": "good",
            "transaction_type": "ship",
            "status": "active",
            "image_urls": ["img.jpg"],
            "view_count": 5,
            "favorite_count": 1,
            "offer_count": 0,
            "created_at": isoDate,
            "updated_at": isoDate,
            "profiles": [
                "id": sellerId.uuidString,
                "call_sign": "SellerPilot",
                "profile_picture_url": NSNull(),
                "first_name": "John",
                "last_name": "Doe"
            ] as [String: Any]
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(MarketplaceListingResponse.self, from: data)

        XCTAssertEqual(response.id, id)
        XCTAssertEqual(response.title, "Response Test")
        XCTAssertNotNil(response.profileData)
        XCTAssertEqual(response.profileData?.callSign, "SellerPilot")
    }

    func testListingResponseToListing() throws {
        let id = UUID()
        let sellerId = UUID()
        let isoDate = ISO8601DateFormatter().string(from: Date())

        let json: [String: Any] = [
            "id": id.uuidString,
            "seller_id": sellerId.uuidString,
            "title": "Convert Test",
            "description": "Testing toListing",
            "price": 250,
            "category": "batteries",
            "condition": "new",
            "transaction_type": "both",
            "status": "active",
            "view_count": 10,
            "favorite_count": 3,
            "offer_count": 1,
            "created_at": isoDate,
            "updated_at": isoDate
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(MarketplaceListingResponse.self, from: data)
        let listing = response.toListing()

        XCTAssertEqual(listing.id, id)
        XCTAssertEqual(listing.sellerId, sellerId)
        XCTAssertEqual(listing.title, "Convert Test")
        XCTAssertEqual(listing.category, .batteries)
        XCTAssertEqual(listing.condition, .new)
        XCTAssertEqual(listing.viewCount, 10)
    }

    func testListingResponseNilProfile() throws {
        let isoDate = ISO8601DateFormatter().string(from: Date())
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "seller_id": UUID().uuidString,
            "title": "No Profile",
            "description": "No profile attached",
            "price": 100,
            "category": "other",
            "condition": "fair",
            "transaction_type": "meetup",
            "status": "active",
            "created_at": isoDate,
            "updated_at": isoDate
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(MarketplaceListingResponse.self, from: data)

        XCTAssertNil(response.profiles)
        XCTAssertNil(response.profileData)
    }

    func testListingResponseArrayProfile() throws {
        let sellerId = UUID()
        let isoDate = ISO8601DateFormatter().string(from: Date())

        let json: [String: Any] = [
            "id": UUID().uuidString,
            "seller_id": sellerId.uuidString,
            "title": "Array Profile",
            "description": "Testing array profile",
            "price": 100,
            "category": "drones",
            "condition": "new",
            "transaction_type": "ship",
            "status": "active",
            "created_at": isoDate,
            "updated_at": isoDate,
            "profiles": [[
                "id": sellerId.uuidString,
                "call_sign": "ArrayPilot",
                "profile_picture_url": NSNull(),
                "first_name": "Array",
                "last_name": "Test"
            ]]
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(MarketplaceListingResponse.self, from: data)

        XCTAssertNotNil(response.profileData)
        XCTAssertEqual(response.profileData?.callSign, "ArrayPilot")
    }

    // MARK: - Enum Codable Round-Trip

    func testCategoryCodableRoundTrip() throws {
        for category in MarketplaceCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(MarketplaceCategory.self, from: data)
            XCTAssertEqual(decoded, category)
        }
    }

    func testConditionCodableRoundTrip() throws {
        for condition in ListingCondition.allCases {
            let data = try JSONEncoder().encode(condition)
            let decoded = try JSONDecoder().decode(ListingCondition.self, from: data)
            XCTAssertEqual(decoded, condition)
        }
    }

    func testTransactionTypeCodableRoundTrip() throws {
        for type in MarketplaceTransactionType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(MarketplaceTransactionType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }
}
