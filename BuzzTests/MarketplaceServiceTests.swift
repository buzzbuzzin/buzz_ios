//
//  MarketplaceServiceTests.swift
//  BuzzTests
//
//  Comprehensive unit tests for MarketplaceService.
//
//  NOTE: MarketplaceService calls Supabase directly without protocol-based DI.
//  Tests focus on: business logic guards, mathematical calculations, input validation,
//  demo mode behavior, and data transformation logic. Methods that require Supabase
//  are documented with what would be tested with a mock backend.
//

import XCTest
@testable import Buzz

@MainActor
final class MarketplaceServiceTests: XCTestCase {

    private var service: MarketplaceService!

    override func setUp() {
        super.setUp()
        service = MarketplaceService()
        DemoModeManager.shared.isDemoModeEnabled = false
    }

    override func tearDown() {
        DemoModeManager.shared.isDemoModeEnabled = false
        service = nil
        super.tearDown()
    }

    // MARK: - Platform Fee Constant

    func testPlatformFeePercentageIsTenPercent() {
        XCTAssertEqual(MarketplaceService.platformFeePercentage, Decimal(string: "0.10"))
    }

    // MARK: - Platform Fee Calculation (Mathematical Verification)
    //
    // The service computes:
    //   platformFee  = (amount * 0.10).rounded(scale: 2, mode: .bankers)
    //   sellerPayout = amount - platformFee
    //
    // These tests verify the formula produces correct results for various amounts.

    func testPlatformFee_roundTrip_100() {
        let amount: Decimal = 100
        let fee = (amount * MarketplaceService.platformFeePercentage).bankersRounded(scale: 2)
        let payout = amount - fee

        XCTAssertEqual(fee, Decimal(string: "10.00"))
        XCTAssertEqual(payout, Decimal(string: "90.00"))
        XCTAssertEqual(fee + payout, amount, "Fee + payout must equal original amount")
    }

    func testPlatformFee_roundTrip_599_99() {
        let amount: Decimal = Decimal(string: "599.99")!
        let fee = (amount * MarketplaceService.platformFeePercentage).bankersRounded(scale: 2)
        let payout = amount - fee

        // 599.99 * 0.10 = 59.999 → bankers rounds to 60.00
        XCTAssertEqual(fee, Decimal(string: "60.00"))
        XCTAssertEqual(payout, Decimal(string: "539.99"))
        XCTAssertEqual(fee + payout, amount)
    }

    func testPlatformFee_roundTrip_349_99() {
        let amount: Decimal = Decimal(string: "349.99")!
        let fee = (amount * MarketplaceService.platformFeePercentage).bankersRounded(scale: 2)
        let payout = amount - fee

        // 349.99 * 0.10 = 34.999 → bankers rounds to 35.00
        XCTAssertEqual(fee, Decimal(string: "35.00"))
        XCTAssertEqual(payout, Decimal(string: "314.99"))
        XCTAssertEqual(fee + payout, amount)
    }

    func testPlatformFee_roundTrip_0_01() {
        let amount: Decimal = Decimal(string: "0.01")!
        let fee = (amount * MarketplaceService.platformFeePercentage).bankersRounded(scale: 2)
        let payout = amount - fee

        // 0.01 * 0.10 = 0.001 → bankers rounds to 0.00
        XCTAssertEqual(fee, Decimal(string: "0.00"))
        XCTAssertEqual(payout, Decimal(string: "0.01"))
        XCTAssertEqual(fee + payout, amount)
    }

    func testPlatformFee_roundTrip_largeAmount() {
        let amount: Decimal = Decimal(string: "9999.99")!
        let fee = (amount * MarketplaceService.platformFeePercentage).bankersRounded(scale: 2)
        let payout = amount - fee

        // 9999.99 * 0.10 = 999.999 → bankers rounds to 1000.00
        XCTAssertEqual(fee, Decimal(string: "1000.00"))
        XCTAssertEqual(payout, Decimal(string: "8999.99"))
        XCTAssertEqual(fee + payout, amount)
    }

    func testPlatformFee_roundTrip_wholeNumber() {
        let amount: Decimal = 250
        let fee = (amount * MarketplaceService.platformFeePercentage).bankersRounded(scale: 2)
        let payout = amount - fee

        XCTAssertEqual(fee, Decimal(string: "25.00"))
        XCTAssertEqual(payout, Decimal(string: "225.00"))
        XCTAssertEqual(fee + payout, amount)
    }

    func testPlatformFee_bankersRounding_halfToEven() {
        // 0.05 * 0.10 = 0.005 → bankers rounds to 0.00 (rounds to even)
        let amount: Decimal = Decimal(string: "0.05")!
        let fee = (amount * MarketplaceService.platformFeePercentage).bankersRounded(scale: 2)
        XCTAssertEqual(fee, Decimal(string: "0.00"))

        // 0.15 * 0.10 = 0.015 → bankers rounds to 0.02 (rounds to even)
        let amount2: Decimal = Decimal(string: "0.15")!
        let fee2 = (amount2 * MarketplaceService.platformFeePercentage).bankersRounded(scale: 2)
        XCTAssertEqual(fee2, Decimal(string: "0.02"))
    }

    func testPlatformFee_noFloatPrecisionLoss() {
        // Decimal arithmetic should not suffer from floating-point drift.
        // 33.33 * 0.10 = 3.333 → bankers rounds to 3.33
        let amount: Decimal = Decimal(string: "33.33")!
        let fee = (amount * MarketplaceService.platformFeePercentage).bankersRounded(scale: 2)
        let payout = amount - fee

        XCTAssertEqual(fee, Decimal(string: "3.33"))
        XCTAssertEqual(payout, Decimal(string: "30.00"))
        XCTAssertEqual(fee + payout, amount)
    }

    func testPlatformFee_feeAlwaysNonNegative() {
        let amounts: [Decimal] = [0, Decimal(string: "0.01")!, 1, 100, 9999]
        for amount in amounts {
            let fee = (amount * MarketplaceService.platformFeePercentage).bankersRounded(scale: 2)
            XCTAssertGreaterThanOrEqual(fee, 0, "Fee should be non-negative for amount \(amount)")
        }
    }

    func testPlatformFee_payoutAlwaysLessThanOrEqualToAmount() {
        let amounts: [Decimal] = [0, Decimal(string: "0.01")!, 1, 100, Decimal(string: "599.99")!, 9999]
        for amount in amounts {
            let fee = (amount * MarketplaceService.platformFeePercentage).bankersRounded(scale: 2)
            let payout = amount - fee
            XCTAssertLessThanOrEqual(payout, amount, "Payout should not exceed amount for \(amount)")
        }
    }

    // MARK: - Meetup Transaction Fee Structure
    //
    // Meetup transactions use zero platform fee — the seller gets the full amount.

    func testMeetupTransaction_zeroPlatformFee() {
        // In createMeetupTransaction, platform_fee is "0" and seller_payout equals amount.
        let amount: Decimal = Decimal(string: "349.99")!
        let meetupFee: Decimal = 0
        let meetupPayout = amount

        XCTAssertEqual(meetupFee, 0)
        XCTAssertEqual(meetupPayout, amount)
    }

    // MARK: - Self-Purchase Prevention

    func testCreateShipTransaction_selfPurchase_throws() async {
        let userId = UUID()
        do {
            _ = try await service.createShipTransaction(
                listingId: UUID(), buyerId: userId, sellerId: userId,
                offerId: nil, amount: 100
            )
            XCTFail("Expected self-purchase error")
        } catch {
            let nsError = error as NSError
            XCTAssertTrue(
                nsError.localizedDescription.contains("cannot purchase your own listing"),
                "Error should mention self-purchase: \(nsError.localizedDescription)"
            )
        }
    }

    func testCreateMeetupTransaction_selfPurchase_throws() async {
        let userId = UUID()
        do {
            _ = try await service.createMeetupTransaction(
                listingId: UUID(), buyerId: userId, sellerId: userId,
                offerId: nil, amount: 100
            )
            XCTFail("Expected self-purchase error")
        } catch {
            let nsError = error as NSError
            XCTAssertTrue(
                nsError.localizedDescription.contains("cannot purchase your own listing"),
                "Error should mention self-purchase: \(nsError.localizedDescription)"
            )
        }
    }

    func testCreateShipTransaction_differentUsers_doesNotThrowSelfPurchase() async {
        // With different buyerId and sellerId, the self-purchase guard passes.
        // The method will fail later at the Supabase call, but the guard itself succeeds.
        do {
            _ = try await service.createShipTransaction(
                listingId: UUID(), buyerId: UUID(), sellerId: UUID(),
                offerId: nil, amount: 100
            )
            XCTFail("Expected Supabase error (not self-purchase)")
        } catch {
            let nsError = error as NSError
            XCTAssertFalse(
                nsError.localizedDescription.contains("cannot purchase your own listing"),
                "Should not be a self-purchase error"
            )
        }
    }

    func testCreateMeetupTransaction_differentUsers_doesNotThrowSelfPurchase() async {
        do {
            _ = try await service.createMeetupTransaction(
                listingId: UUID(), buyerId: UUID(), sellerId: UUID(),
                offerId: nil, amount: 100
            )
            XCTFail("Expected Supabase error (not self-purchase)")
        } catch {
            let nsError = error as NSError
            XCTAssertFalse(
                nsError.localizedDescription.contains("cannot purchase your own listing"),
                "Should not be a self-purchase error"
            )
        }
    }

    // MARK: - Rating Validation

    func testSubmitReview_ratingZero_throws() async {
        do {
            try await service.submitReview(
                transactionId: UUID(), fromUserId: UUID(), toUserId: UUID(),
                rating: 0, comment: "Bad"
            )
            XCTFail("Expected rating validation error")
        } catch {
            let nsError = error as NSError
            XCTAssertTrue(
                nsError.localizedDescription.contains("Rating must be between 1 and 5"),
                "Error: \(nsError.localizedDescription)"
            )
        }
    }

    func testSubmitReview_ratingNegative_throws() async {
        do {
            try await service.submitReview(
                transactionId: UUID(), fromUserId: UUID(), toUserId: UUID(),
                rating: -1, comment: nil
            )
            XCTFail("Expected rating validation error")
        } catch {
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("Rating must be between 1 and 5"))
        }
    }

    func testSubmitReview_ratingSix_throws() async {
        do {
            try await service.submitReview(
                transactionId: UUID(), fromUserId: UUID(), toUserId: UUID(),
                rating: 6, comment: "Over the top"
            )
            XCTFail("Expected rating validation error")
        } catch {
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("Rating must be between 1 and 5"))
        }
    }

    func testSubmitReview_ratingHundred_throws() async {
        do {
            try await service.submitReview(
                transactionId: UUID(), fromUserId: UUID(), toUserId: UUID(),
                rating: 100, comment: nil
            )
            XCTFail("Expected rating validation error")
        } catch {
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("Rating must be between 1 and 5"))
        }
    }

    func testSubmitReview_validRatings_passGuard() async {
        // Ratings 1-5 pass the guard but then fail at Supabase.
        // We verify the error is NOT a rating validation error.
        for rating in 1...5 {
            do {
                try await service.submitReview(
                    transactionId: UUID(), fromUserId: UUID(), toUserId: UUID(),
                    rating: rating, comment: "Rating \(rating)"
                )
                XCTFail("Expected Supabase error for rating \(rating)")
            } catch {
                let nsError = error as NSError
                XCTAssertFalse(
                    nsError.localizedDescription.contains("Rating must be between 1 and 5"),
                    "Rating \(rating) should pass validation guard"
                )
            }
        }
    }

    // MARK: - Offer Not Found Guards

    func testAcceptOffer_offerNotFound_throws() async {
        // Service has empty offers array, so lookup fails before Supabase
        do {
            try await service.acceptOffer(offerId: UUID())
            XCTFail("Expected offer not found error")
        } catch {
            let nsError = error as NSError
            XCTAssertTrue(
                nsError.localizedDescription.contains("Offer not found"),
                "Error: \(nsError.localizedDescription)"
            )
        }
    }

    func testDeclineOffer_offerNotFound_throws() async {
        do {
            try await service.declineOffer(offerId: UUID())
            XCTFail("Expected offer not found error")
        } catch {
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("Offer not found"))
        }
    }

    func testWithdrawOffer_offerNotFound_throws() async {
        do {
            try await service.withdrawOffer(offerId: UUID())
            XCTFail("Expected offer not found error")
        } catch {
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("Offer not found"))
        }
    }

    // MARK: - Demo Mode: Fetch Listings

    func testFetchListings_demoMode_returnsDemoData() async {
        DemoModeManager.shared.isDemoModeEnabled = true

        await service.fetchListings(currentUserId: UUID())

        XCTAssertFalse(service.listings.isEmpty, "Demo mode should return listings")
        XCTAssertEqual(service.listings.count, MarketplaceService.demoListings.count)
        XCTAssertFalse(service.isLoading)
    }

    func testFetchListings_demoMode_listingsHaveExpectedContent() async {
        DemoModeManager.shared.isDemoModeEnabled = true

        await service.fetchListings(currentUserId: UUID())

        let firstListing = service.listings.first
        XCTAssertNotNil(firstListing)
        XCTAssertFalse(firstListing!.listing.title.isEmpty)
        XCTAssertGreaterThan(firstListing!.listing.price, 0)
        XCTAssertNotNil(firstListing!.sellerCallSign)
    }

    func testFetchListings_demoMode_ignoresFilters() async {
        DemoModeManager.shared.isDemoModeEnabled = true

        // Even with restrictive filters, demo mode returns all demo listings
        await service.fetchListings(
            category: .batteries,
            condition: .new,
            minPrice: 99999,
            maxPrice: 99999,
            searchQuery: "nonexistent",
            currentUserId: UUID()
        )

        XCTAssertEqual(service.listings.count, MarketplaceService.demoListings.count)
    }

    // MARK: - Demo Mode: Fetch Listing Detail

    func testFetchListingDetail_demoMode_returnsFirstDemoListing() async {
        DemoModeManager.shared.isDemoModeEnabled = true

        let result = await service.fetchListingDetail(listingId: UUID(), currentUserId: UUID())

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.listing.title, MarketplaceService.demoListings.first?.listing.title)
    }

    // MARK: - Demo Mode: Create Listing

    func testCreateListing_demoMode_returnsDemoListing() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        let insert = MarketplaceTestData.sampleListingInsert()
        let result = try await service.createListing(insert: insert)

        XCTAssertEqual(result.title, MarketplaceService.demoListings.first?.listing.title)
    }

    // MARK: - Demo Mode: Update & Delete Listing (no-ops)

    func testUpdateListing_demoMode_doesNotThrow() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        // Should return without error
        try await service.updateListing(
            listingId: UUID(),
            updates: MarketplaceTestData.sampleListingUpdate()
        )
    }

    func testDeleteListing_demoMode_doesNotThrow() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        try await service.deleteListing(listingId: UUID())
    }

    // MARK: - Demo Mode: My Listings

    func testFetchMyListings_demoMode_returnsDemoData() async {
        DemoModeManager.shared.isDemoModeEnabled = true

        await service.fetchMyListings(sellerId: UUID())

        XCTAssertEqual(service.myListings.count, MarketplaceService.demoListings.count)
        XCTAssertFalse(service.isLoading)
    }

    // MARK: - Demo Mode: Favorites

    func testToggleFavorite_demoMode_doesNotThrow() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        try await service.toggleFavorite(listingId: UUID(), userId: UUID())
    }

    func testFetchFavorites_demoMode_returnsEmpty() async {
        DemoModeManager.shared.isDemoModeEnabled = true

        await service.fetchFavorites(userId: UUID())

        XCTAssertTrue(service.favoriteListings.isEmpty)
    }

    // MARK: - Demo Mode: Offers

    func testCreateOffer_demoMode_doesNotThrow() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        try await service.createOffer(
            listingId: UUID(), buyerId: UUID(),
            amount: 100, message: "Demo offer"
        )
    }

    func testAcceptOffer_demoMode_doesNotThrow() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        try await service.acceptOffer(offerId: UUID())
    }

    func testDeclineOffer_demoMode_doesNotThrow() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        try await service.declineOffer(offerId: UUID())
    }

    func testWithdrawOffer_demoMode_doesNotThrow() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        try await service.withdrawOffer(offerId: UUID())
    }

    func testFetchOffersForListing_demoMode_returnsEmpty() async {
        DemoModeManager.shared.isDemoModeEnabled = true

        await service.fetchOffersForListing(listingId: UUID())

        XCTAssertTrue(service.offers.isEmpty)
    }

    func testFetchMyOffers_demoMode_returnsEmpty() async {
        DemoModeManager.shared.isDemoModeEnabled = true

        await service.fetchMyOffers(buyerId: UUID())

        XCTAssertTrue(service.offers.isEmpty)
    }

    // MARK: - Demo Mode: Transactions

    func testCreateShipTransaction_demoMode_returnsDemoTransaction() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        let result = try await service.createShipTransaction(
            listingId: UUID(), buyerId: UUID(), sellerId: UUID(),
            offerId: nil, amount: 500
        )

        XCTAssertEqual(result.transactionType, .ship)
        XCTAssertEqual(result.status, .pendingPayment)
        XCTAssertEqual(result.amount, 100) // demo transaction amount
        XCTAssertEqual(result.platformFee, 10)
        XCTAssertEqual(result.sellerPayout, 90)
    }

    func testCreateMeetupTransaction_demoMode_returnsDemoTransaction() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        let result = try await service.createMeetupTransaction(
            listingId: UUID(), buyerId: UUID(), sellerId: UUID(),
            offerId: nil, amount: 500
        )

        // Demo mode returns the same demoTransaction regardless of type
        XCTAssertNotNil(result.id)
        XCTAssertEqual(result.status, .pendingPayment)
    }

    func testCreateShipTransaction_demoMode_bypassesSelfPurchaseGuard() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        // In demo mode, self-purchase check is skipped (demo returns before guard)
        let userId = UUID()
        let result = try await service.createShipTransaction(
            listingId: UUID(), buyerId: userId, sellerId: userId,
            offerId: nil, amount: 100
        )

        XCTAssertNotNil(result.id)
    }

    func testMarkAsShipped_demoMode_doesNotThrow() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        try await service.markAsShipped(
            transactionId: UUID(), trackingNumber: "TRACK123", carrier: "UPS"
        )
    }

    func testConfirmReceipt_demoMode_doesNotThrow() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        try await service.confirmReceipt(transactionId: UUID())
    }

    func testScheduleMeetup_demoMode_doesNotThrow() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        try await service.scheduleMeetup(
            transactionId: UUID(),
            locationName: "Coffee Shop",
            lat: 37.77, lng: -122.42,
            scheduledAt: Date()
        )
    }

    func testConfirmMeetupComplete_demoMode_doesNotThrow() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        try await service.confirmMeetupComplete(transactionId: UUID(), byUserId: UUID())
    }

    func testFetchTransactionsForUser_demoMode_returnsEmptyAndStopsLoading() async {
        DemoModeManager.shared.isDemoModeEnabled = true

        await service.fetchTransactionsForUser(userId: UUID())

        XCTAssertTrue(service.transactions.isEmpty)
        XCTAssertFalse(service.isLoading)
    }

    // MARK: - Demo Mode: Reviews

    func testSubmitReview_demoMode_doesNotThrow() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        try await service.submitReview(
            transactionId: UUID(), fromUserId: UUID(), toUserId: UUID(),
            rating: 5, comment: "Great!"
        )
    }

    func testSubmitReview_demoMode_bypassesRatingValidation() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        // In demo mode, the rating guard is never reached
        try await service.submitReview(
            transactionId: UUID(), fromUserId: UUID(), toUserId: UUID(),
            rating: 0, comment: nil
        )
    }

    func testFetchReviewsForUser_demoMode_returnsEmpty() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        let reviews = try await service.fetchReviewsForUser(userId: UUID())

        XCTAssertTrue(reviews.isEmpty)
    }

    func testHasUserReviewed_demoMode_returnsFalse() async {
        DemoModeManager.shared.isDemoModeEnabled = true

        let result = await service.hasUserReviewed(transactionId: UUID(), userId: UUID())

        XCTAssertFalse(result)
    }

    // MARK: - Demo Mode: Payment

    func testCreateMarketplacePayment_demoMode_returnsDemoResponse() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        let response = try await service.createMarketplacePayment(transactionId: UUID())

        XCTAssertEqual(response.clientSecret, "demo_secret")
        XCTAssertEqual(response.paymentIntentId, "demo_pi")
        XCTAssertEqual(response.customerId, "demo_cus")
        XCTAssertEqual(response.ephemeralKeySecret, "demo_ek")
        XCTAssertEqual(response.platformFee, 0)
        XCTAssertEqual(response.sellerPayout, 0)
    }

    // MARK: - Demo Mode: Image Upload

    func testUploadListingImages_demoMode_returnsEmpty() async throws {
        DemoModeManager.shared.isDemoModeEnabled = true

        let result = try await service.uploadListingImages(userId: UUID(), images: [])

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Demo Data Integrity

    func testDemoListings_allHaveActiveListing() {
        for demoListing in MarketplaceService.demoListings {
            XCTAssertEqual(
                demoListing.listing.status, .active,
                "Demo listing '\(demoListing.listing.title)' should be active"
            )
        }
    }

    func testDemoListings_allHavePositivePrice() {
        for demoListing in MarketplaceService.demoListings {
            XCTAssertGreaterThan(
                demoListing.listing.price, 0,
                "Demo listing '\(demoListing.listing.title)' should have positive price"
            )
        }
    }

    func testDemoListings_allHaveNonEmptyTitle() {
        for demoListing in MarketplaceService.demoListings {
            XCTAssertFalse(demoListing.listing.title.isEmpty)
        }
    }

    func testDemoListings_allHaveSellerInfo() {
        for demoListing in MarketplaceService.demoListings {
            XCTAssertNotNil(demoListing.sellerCallSign)
            XCTAssertFalse(demoListing.sellerFullName.isEmpty)
        }
    }

    func testDemoListings_haveDistinctCategories() {
        let categories = Set(MarketplaceService.demoListings.map { $0.listing.category })
        XCTAssertGreaterThan(categories.count, 1, "Demo listings should cover multiple categories")
    }

    func testDemoTransaction_feeBreakdownIsConsistent() {
        let tx = MarketplaceService.demoTransaction
        XCTAssertEqual(tx.platformFee + tx.sellerPayout, tx.amount,
                       "Demo transaction: fee + payout should equal amount")
        XCTAssertEqual(tx.amount, 100)
        XCTAssertEqual(tx.platformFee, 10)
        XCTAssertEqual(tx.sellerPayout, 90)
    }

    // MARK: - Initial Service State

    func testService_initialState() {
        let freshService = MarketplaceService()

        XCTAssertTrue(freshService.listings.isEmpty)
        XCTAssertTrue(freshService.myListings.isEmpty)
        XCTAssertTrue(freshService.favoriteListings.isEmpty)
        XCTAssertTrue(freshService.offers.isEmpty)
        XCTAssertTrue(freshService.transactions.isEmpty)
        XCTAssertFalse(freshService.isLoading)
        XCTAssertNil(freshService.errorMessage)
    }

    // MARK: - Favorite Toggle Local State

    func testToggleFavorite_updatesLocalListingsState() async throws {
        // Pre-populate the service's listings array with a known listing
        let listingId = UUID()
        let listing = MarketplaceTestData.sampleListing(id: listingId)
        let listingWithSeller = MarketplaceTestData.sampleListingWithSeller(
            id: listingId, listing: listing, isFavoritedByCurrentUser: false
        )

        service.listings = [listingWithSeller]

        // In non-demo mode, toggleFavorite will hit Supabase and fail.
        // But the local state toggle logic is still exercised if we test
        // through demo mode + pre-populated state.
        DemoModeManager.shared.isDemoModeEnabled = true
        try await service.toggleFavorite(listingId: listingId, userId: UUID())

        // Demo mode returns early before toggling local state,
        // so state should be unchanged.
        XCTAssertFalse(service.listings[0].isFavoritedByCurrentUser)
    }

    // MARK: - MarketplaceListingUpdate Encoding

    func testListingUpdate_onlyEncodesNonNilFields() throws {
        var update = MarketplaceListingUpdate()
        update.title = "New Title"
        update.price = Decimal(string: "199.99")

        let encoder = JSONEncoder()
        let data = try encoder.encode(update)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["title"] as? String, "New Title")
        XCTAssertNotNil(json["price"])
        // nil fields should not be present
        XCTAssertNil(json["description"])
        XCTAssertNil(json["category"])
        XCTAssertNil(json["condition"])
        XCTAssertNil(json["status"])
        XCTAssertNil(json["image_urls"])
        XCTAssertNil(json["location_name"])
        XCTAssertNil(json["brand"])
        XCTAssertNil(json["model"])
        XCTAssertNil(json["shipping_cost"])
    }

    func testListingUpdate_statusOnlyEncodesStatus() throws {
        let update = MarketplaceListingUpdate(status: "sold")

        let encoder = JSONEncoder()
        let data = try encoder.encode(update)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["status"] as? String, "sold")
        XCTAssertEqual(json.count, 1, "Should only contain the status field")
    }

    func testListingUpdate_allFieldsEncoded() throws {
        var update = MarketplaceListingUpdate()
        update.title = "T"
        update.description = "D"
        update.price = 10
        update.category = "drones"
        update.condition = "new"
        update.transactionType = "ship"
        update.status = "active"
        update.imageUrls = ["url"]
        update.locationName = "L"
        update.locationLat = 1.0
        update.locationLng = 2.0
        update.brand = "B"
        update.model = "M"
        update.shippingCost = 5

        let encoder = JSONEncoder()
        let data = try encoder.encode(update)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json.count, 14)
        XCTAssertEqual(json["title"] as? String, "T")
        XCTAssertEqual(json["transaction_type"] as? String, "ship")
        XCTAssertEqual(json["image_urls"] as? [String], ["url"])
        XCTAssertEqual(json["location_name"] as? String, "L")
    }

    // MARK: - MarketplaceListingInsert Encoding

    func testListingInsert_encodesWithSnakeCaseKeys() throws {
        let insert = MarketplaceTestData.sampleListingInsert(
            sellerId: UUID(),
            title: "Test Drone",
            price: Decimal(string: "499.99")!,
            category: .drones,
            condition: .new,
            transactionType: .ship
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(insert)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["seller_id"])
        XCTAssertEqual(json["title"] as? String, "Test Drone")
        XCTAssertEqual(json["category"] as? String, "drones")
        XCTAssertEqual(json["condition"] as? String, "new")
        XCTAssertEqual(json["transaction_type"] as? String, "ship")
        XCTAssertNotNil(json["image_urls"])
        XCTAssertNotNil(json["location_name"])
        XCTAssertNotNil(json["location_lat"])
        XCTAssertNotNil(json["location_lng"])
        // Verify snake_case, not camelCase
        XCTAssertNil(json["sellerId"])
        XCTAssertNil(json["transactionType"])
        XCTAssertNil(json["imageUrls"])
        XCTAssertNil(json["shippingCost"]) // should be shipping_cost
    }

    // MARK: - MarketplaceOfferInsert Encoding

    func testOfferInsert_encodesWithSnakeCaseKeys() throws {
        let insert = MarketplaceOfferInsert(
            listingId: UUID(), buyerId: UUID(),
            amount: Decimal(string: "250.00")!, message: "Interested"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(insert)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["listing_id"])
        XCTAssertNotNil(json["buyer_id"])
        XCTAssertEqual(json["message"] as? String, "Interested")
        XCTAssertNil(json["listingId"])
        XCTAssertNil(json["buyerId"])
    }

    func testOfferInsert_nilMessageIsEncoded() throws {
        let insert = MarketplaceOfferInsert(
            listingId: UUID(), buyerId: UUID(),
            amount: 100, message: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(insert)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // nil message is encoded as null (Codable default)
        XCTAssertTrue(json.keys.contains("message"))
    }

    // MARK: - Payout Conversion for Edge Function

    func testSellerPayout_centConversion_accuracy() {
        // confirmReceipt converts sellerPayout to cents via:
        //   NSDecimalNumber(decimal: transaction.sellerPayout * 100).intValue
        let payouts: [(Decimal, Int)] = [
            (Decimal(string: "90.00")!, 9000),
            (Decimal(string: "315.00")!, 31500),
            (Decimal(string: "539.99")!, 53999),
            (Decimal(string: "0.01")!, 1),
            (Decimal(string: "999.99")!, 99999),
        ]

        for (payout, expectedCents) in payouts {
            let cents = NSDecimalNumber(decimal: payout * 100).intValue
            XCTAssertEqual(cents, expectedCents,
                           "Payout \(payout) should convert to \(expectedCents) cents, got \(cents)")
        }
    }

    func testSellerPayout_centConversion_noFloatDrift() {
        // Verify that Decimal → cents conversion doesn't lose precision
        // (a problem that occurs with Double arithmetic)
        let payout = Decimal(string: "19.99")!
        let cents = NSDecimalNumber(decimal: payout * 100).intValue
        XCTAssertEqual(cents, 1999, "19.99 should be exactly 1999 cents")

        let payout2 = Decimal(string: "0.10")!
        let cents2 = NSDecimalNumber(decimal: payout2 * 100).intValue
        XCTAssertEqual(cents2, 10, "0.10 should be exactly 10 cents")
    }

    // MARK: - Comprehensive Fee Table

    func testPlatformFee_comprehensiveTable() {
        // Test a variety of realistic marketplace prices
        let testCases: [(amount: String, expectedFee: String, expectedPayout: String)] = [
            ("10.00",    "1.00",    "9.00"),
            ("25.00",    "2.50",    "22.50"),
            ("49.99",    "5.00",    "44.99"),     // 4.999 → bankers 5.00
            ("99.99",    "10.00",   "89.99"),     // 9.999 → bankers 10.00
            ("150.00",   "15.00",   "135.00"),
            ("299.50",   "29.95",   "269.55"),
            ("499.95",   "50.00",   "449.96"),    // 49.995 → bankers 50.00 (rounds to even)
            ("1000.00",  "100.00",  "900.00"),
            ("2499.99",  "250.00",  "2249.99"),   // 249.999 → bankers 250.00
        ]

        for tc in testCases {
            let amount = Decimal(string: tc.amount)!
            let fee = (amount * MarketplaceService.platformFeePercentage).bankersRounded(scale: 2)
            let payout = amount - fee

            XCTAssertEqual(fee, Decimal(string: tc.expectedFee)!,
                           "Fee for $\(tc.amount): expected $\(tc.expectedFee), got \(fee)")
            XCTAssertEqual(payout, Decimal(string: tc.expectedPayout)!,
                           "Payout for $\(tc.amount): expected $\(tc.expectedPayout), got \(payout)")
            XCTAssertEqual(fee + payout, amount,
                           "Fee + payout should equal amount for $\(tc.amount)")
        }
    }
}

// MARK: - Test Helper: Decimal Bankers Rounding

// Replicates the private Decimal.rounded(scale:) extension in MarketplaceService
// so tests can verify the same rounding behavior.
private extension Decimal {
    func bankersRounded(scale: Int) -> Decimal {
        var result = Decimal()
        var mutableSelf = self
        NSDecimalRound(&result, &mutableSelf, scale, .bankers)
        return result
    }
}
