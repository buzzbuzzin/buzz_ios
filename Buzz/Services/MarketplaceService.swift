//
//  MarketplaceService.swift
//  Buzz
//
//  Created for Marketplace feature
//

import Foundation
import Combine
import Supabase
import UIKit

@MainActor
class MarketplaceService: ObservableObject {
    @Published var listings: [MarketplaceListingWithSeller] = []
    @Published var myListings: [MarketplaceListingWithSeller] = []
    @Published var favoriteListings: [MarketplaceListingWithSeller] = []
    @Published var offers: [MarketplaceOfferResponse] = []
    @Published var transactions: [MarketplaceTransactionWithDetails] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseClient.shared.client

    // TODO: Platform fee computation should be server-side to prevent client tampering.
    // For now, keep client-side but the server should validate on transaction creation.
    static let platformFeePercentage: Decimal = 0.10 // 10%

    private func currentAuthUserId() async throws -> UUID {
        let session = try await supabase.auth.session
        return session.user.id
    }

    // MARK: - Fetch Listings

    func fetchListings(
        category: MarketplaceCategory? = nil,
        condition: ListingCondition? = nil,
        transactionType: MarketplaceTransactionType? = nil,
        minPrice: Decimal? = nil,
        maxPrice: Decimal? = nil,
        searchQuery: String? = nil,
        sortBy: MarketplaceSortOption = .newest,
        currentUserId: UUID
    ) async {
        isLoading = true
        errorMessage = nil

        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 300_000_000)
            listings = Self.demoListings
            isLoading = false
            return
        }

        do {
            var query = supabase
                .from("marketplace_listings")
                .select("*, profiles!marketplace_listings_seller_id_fkey(id, user_type, call_sign, profile_picture_url, first_name, last_name)")
                .eq("status", value: "active")

            if let category = category {
                query = query.eq("category", value: category.rawValue)
            }
            if let condition = condition {
                query = query.eq("condition", value: condition.rawValue)
            }
            if let transactionType = transactionType, transactionType != .both {
                query = query.or("transaction_type.eq.\(transactionType.rawValue),transaction_type.eq.both")
            }
            if let minPrice = minPrice {
                query = query.gte("price", value: Double(truncating: minPrice as NSDecimalNumber))
            }
            if let maxPrice = maxPrice {
                query = query.lte("price", value: Double(truncating: maxPrice as NSDecimalNumber))
            }
            if let searchQuery = searchQuery, !searchQuery.isEmpty {
                let sanitized = sanitizeSearchPattern(searchQuery)
                query = query.or("title.ilike.%\(sanitized)%,description.ilike.%\(sanitized)%,brand.ilike.%\(sanitized)%,model.ilike.%\(sanitized)%")
            }

            let orderColumn: String
            let orderAscending: Bool
            switch sortBy {
            case .newest:
                orderColumn = "created_at"
                orderAscending = false
            case .priceLowToHigh:
                orderColumn = "price"
                orderAscending = true
            case .priceHighToLow:
                orderColumn = "price"
                orderAscending = false
            }

            let response: [MarketplaceListingResponse] = try await query
                .order(orderColumn, ascending: orderAscending)
                .limit(50)
                .execute()
                .value

            let listingIds = response.map { $0.id }
            let favoriteIds = await fetchFavoriteIds(userId: currentUserId, listingIds: listingIds)

            listings = response.map { resp in
                mapResponseToListingWithSeller(resp, favoriteIds: favoriteIds)
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Fetch Listing Detail

    func fetchListingDetail(listingId: UUID, currentUserId: UUID) async -> MarketplaceListingWithSeller? {
        if DemoModeManager.shared.isDemoModeEnabled {
            return Self.demoListings.first
        }

        do {
            let response: MarketplaceListingResponse = try await supabase
                .from("marketplace_listings")
                .select("*, profiles!marketplace_listings_seller_id_fkey(id, user_type, call_sign, profile_picture_url, first_name, last_name)")
                .eq("id", value: listingId.uuidString)
                .single()
                .execute()
                .value

            let favoriteIds = await fetchFavoriteIds(userId: currentUserId, listingIds: [listingId])
            return mapResponseToListingWithSeller(response, favoriteIds: favoriteIds)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Create Listing

    func createListing(insert: MarketplaceListingInsert) async throws -> MarketplaceListing {
        if DemoModeManager.shared.isDemoModeEnabled {
            guard let demoListing = Self.demoListings.first else {
                throw NSError(domain: "MarketplaceService", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "No demo listings available"])
            }
            return demoListing.listing
        }

        let response: [MarketplaceListing] = try await supabase
            .from("marketplace_listings")
            .insert(insert)
            .select()
            .execute()
            .value

        guard let listing = response.first else {
            throw NSError(domain: "MarketplaceService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create listing"])
        }

        return listing
    }

    // MARK: - Update Listing

    func updateListing(listingId: UUID, updates: MarketplaceListingUpdate) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        try await supabase
            .from("marketplace_listings")
            .update(updates)
            .eq("id", value: listingId.uuidString)
            .execute()
    }

    // MARK: - Delete Listing

    func deleteListing(listingId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        try await supabase
            .from("marketplace_listings")
            .delete()
            .eq("id", value: listingId.uuidString)
            .execute()
    }

    // MARK: - Fetch My Listings

    func fetchMyListings(sellerId: UUID) async {
        isLoading = true
        errorMessage = nil

        if DemoModeManager.shared.isDemoModeEnabled {
            myListings = Self.demoListings
            isLoading = false
            return
        }

        do {
            let response: [MarketplaceListingResponse] = try await supabase
                .from("marketplace_listings")
                .select("*, profiles!marketplace_listings_seller_id_fkey(id, user_type, call_sign, profile_picture_url, first_name, last_name)")
                .eq("seller_id", value: sellerId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            myListings = response.map { resp in
                mapResponseToListingWithSeller(resp, favoriteIds: [])
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Favorites

    // NOTE: This check-then-act pattern is subject to races under concurrent calls.
    // A unique constraint on (user_id, listing_id) in the DB is needed for safety.
    func toggleFavorite(listingId: UUID, userId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        // Check if already favorited
        let existing: [MarketplaceFavorite] = try await supabase
            .from("marketplace_favorites")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("listing_id", value: listingId.uuidString)
            .execute()
            .value

        if existing.isEmpty {
            // Add favorite
            let insert = ["user_id": userId.uuidString, "listing_id": listingId.uuidString]
            try await supabase
                .from("marketplace_favorites")
                .insert(insert)
                .execute()
        } else {
            // Remove favorite
            try await supabase
                .from("marketplace_favorites")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("listing_id", value: listingId.uuidString)
                .execute()
        }

        // Update local state
        if let index = listings.firstIndex(where: { $0.listing.id == listingId }) {
            listings[index].isFavoritedByCurrentUser.toggle()
        }
        if let index = favoriteListings.firstIndex(where: { $0.listing.id == listingId }) {
            favoriteListings[index].isFavoritedByCurrentUser.toggle()
        }
    }

    func fetchFavorites(userId: UUID) async {
        if DemoModeManager.shared.isDemoModeEnabled {
            favoriteListings = []
            return
        }

        do {
            let favorites: [MarketplaceFavorite] = try await supabase
                .from("marketplace_favorites")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            let listingIds = favorites.map { $0.listingId }
            guard !listingIds.isEmpty else {
                favoriteListings = []
                return
            }

            let response: [MarketplaceListingResponse] = try await supabase
                .from("marketplace_listings")
                .select("*, profiles!marketplace_listings_seller_id_fkey(id, user_type, call_sign, profile_picture_url, first_name, last_name)")
                .in("id", values: listingIds.map { $0.uuidString })
                .execute()
                .value

            let favoriteIdSet = Set(listingIds)
            favoriteListings = response.map { resp in
                mapResponseToListingWithSeller(resp, favoriteIds: favoriteIdSet)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Offers

    func createOffer(listingId: UUID, buyerId: UUID, amount: Decimal, message: String?) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        let insert = MarketplaceOfferInsert(
            listingId: listingId, buyerId: buyerId, amount: amount, message: message
        )

        try await supabase
            .from("marketplace_offers")
            .insert(insert)
            .execute()

        // Send notification to seller
        if let listing = listings.first(where: { $0.listing.id == listingId }) {
            let buyerCallSign = await fetchCallSign(userId: buyerId)
            await NotificationManager.shared.notifyMarketplaceNewOffer(
                recipientUserId: listing.listing.sellerId,
                listingTitle: listing.listing.title,
                offerAmount: amount,
                buyerName: buyerCallSign ?? "A buyer",
                listingId: listingId
            )
        }
    }

    func acceptOffer(offerId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        // Verify current user is the listing seller
        guard let offer = offers.first(where: { $0.id == offerId }) else {
            throw NSError(domain: "MarketplaceService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Offer not found"])
        }

        // Fetch listing from DB instead of local cache for reliable auth check
        struct ListingAuthCheck: Decodable {
            let sellerId: UUID
            let title: String
            enum CodingKeys: String, CodingKey {
                case sellerId = "seller_id"
                case title
            }
        }
        let listingData: ListingAuthCheck = try await supabase
            .from("marketplace_listings")
            .select("seller_id, title")
            .eq("id", value: offer.listingId.uuidString)
            .single()
            .execute()
            .value

        let currentUserId = try await currentAuthUserId()
        guard listingData.sellerId == currentUserId else {
            throw NSError(domain: "MarketplaceService", code: 403,
                          userInfo: [NSLocalizedDescriptionKey: "Only the seller can accept offers"])
        }

        try await supabase
            .from("marketplace_offers")
            .update(["status": "accepted"])
            .eq("id", value: offerId.uuidString)
            .execute()

        // Send notification to buyer with actual listing title
        await NotificationManager.shared.notifyMarketplaceOfferAccepted(
            recipientUserId: offer.buyerId,
            listingTitle: listingData.title,
            listingId: offer.listingId,
            offerId: offerId
        )
    }

    func declineOffer(offerId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        // Verify current user is the listing seller
        guard let offer = offers.first(where: { $0.id == offerId }) else {
            throw NSError(domain: "MarketplaceService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Offer not found"])
        }

        // Fetch listing from DB instead of local cache for reliable auth check
        struct ListingAuthCheck: Decodable {
            let sellerId: UUID
            let title: String
            enum CodingKeys: String, CodingKey {
                case sellerId = "seller_id"
                case title
            }
        }
        let listingData: ListingAuthCheck = try await supabase
            .from("marketplace_listings")
            .select("seller_id, title")
            .eq("id", value: offer.listingId.uuidString)
            .single()
            .execute()
            .value

        let currentUserId = try await currentAuthUserId()
        guard listingData.sellerId == currentUserId else {
            throw NSError(domain: "MarketplaceService", code: 403,
                          userInfo: [NSLocalizedDescriptionKey: "Only the seller can decline offers"])
        }

        try await supabase
            .from("marketplace_offers")
            .update(["status": "declined"])
            .eq("id", value: offerId.uuidString)
            .execute()

        // Send notification to buyer with actual listing title
        await NotificationManager.shared.notifyMarketplaceOfferDeclined(
            recipientUserId: offer.buyerId,
            listingTitle: listingData.title,
            listingId: offer.listingId,
            offerId: offerId
        )
    }

    func withdrawOffer(offerId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        // Verify current user is the offer buyer
        guard let offer = offers.first(where: { $0.id == offerId }) else {
            throw NSError(domain: "MarketplaceService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Offer not found"])
        }
        let currentUserId = try await currentAuthUserId()
        guard offer.buyerId == currentUserId else {
            throw NSError(domain: "MarketplaceService", code: 403,
                          userInfo: [NSLocalizedDescriptionKey: "Only the buyer can withdraw their offer"])
        }

        try await supabase
            .from("marketplace_offers")
            .update(["status": "withdrawn"])
            .eq("id", value: offerId.uuidString)
            .execute()
    }

    func fetchOffersForListing(listingId: UUID) async {
        if DemoModeManager.shared.isDemoModeEnabled {
            offers = []
            return
        }

        do {
            offers = try await supabase
                .from("marketplace_offers")
                .select("*, profiles!marketplace_offers_buyer_id_fkey(id, user_type, call_sign, profile_picture_url, first_name, last_name)")
                .eq("listing_id", value: listingId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchMyOffers(buyerId: UUID) async {
        if DemoModeManager.shared.isDemoModeEnabled {
            offers = []
            return
        }

        do {
            offers = try await supabase
                .from("marketplace_offers")
                .select("*, profiles!marketplace_offers_buyer_id_fkey(id, user_type, call_sign, profile_picture_url, first_name, last_name)")
                .eq("buyer_id", value: buyerId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Transactions

    func createShipTransaction(
        listingId: UUID, buyerId: UUID, sellerId: UUID,
        offerId: UUID?, amount: Decimal
    ) async throws -> MarketplaceTransaction {
        if DemoModeManager.shared.isDemoModeEnabled {
            return Self.demoTransaction
        }

        // Prevent self-purchase
        guard buyerId != sellerId else {
            throw NSError(domain: "MarketplaceService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "You cannot purchase your own listing"])
        }

        // Verify listing is still active (DB-level constraint is the real guard against races)
        let listing: MarketplaceListing = try await supabase
            .from("marketplace_listings")
            .select()
            .eq("id", value: listingId.uuidString)
            .single()
            .execute()
            .value
        guard listing.status == .active else {
            throw NSError(domain: "MarketplaceService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "This listing is no longer available"])
        }

        let platformFee = (amount * Self.platformFeePercentage).rounded(scale: 2)
        let sellerPayout = amount - platformFee

        var insert: [String: String] = [
            "listing_id": listingId.uuidString,
            "buyer_id": buyerId.uuidString,
            "seller_id": sellerId.uuidString,
            "transaction_type": "ship",
            "status": "pending_payment",
            "amount": "\(amount)",
            "platform_fee": "\(platformFee)",
            "seller_payout": "\(sellerPayout)"
        ]
        if let offerId = offerId {
            insert["offer_id"] = offerId.uuidString
        }

        let response: [MarketplaceTransaction] = try await supabase
            .from("marketplace_transactions")
            .insert(insert)
            .select()
            .execute()
            .value

        guard let transaction = response.first else {
            throw NSError(domain: "MarketplaceService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create transaction"])
        }

        return transaction
    }

    func createMeetupTransaction(
        listingId: UUID, buyerId: UUID, sellerId: UUID,
        offerId: UUID?, amount: Decimal
    ) async throws -> MarketplaceTransaction {
        if DemoModeManager.shared.isDemoModeEnabled {
            return Self.demoTransaction
        }

        // Prevent self-purchase
        guard buyerId != sellerId else {
            throw NSError(domain: "MarketplaceService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "You cannot purchase your own listing"])
        }

        // Verify listing is still active (DB-level constraint is the real guard against races)
        let listing: MarketplaceListing = try await supabase
            .from("marketplace_listings")
            .select()
            .eq("id", value: listingId.uuidString)
            .single()
            .execute()
            .value
        guard listing.status == .active else {
            throw NSError(domain: "MarketplaceService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "This listing is no longer available"])
        }

        var insert: [String: String] = [
            "listing_id": listingId.uuidString,
            "buyer_id": buyerId.uuidString,
            "seller_id": sellerId.uuidString,
            "transaction_type": "meetup",
            "status": "meetup_scheduled",
            "amount": "\(amount)",
            "platform_fee": "0",
            "seller_payout": "\(amount)"
        ]
        if let offerId = offerId {
            insert["offer_id"] = offerId.uuidString
        }

        let response: [MarketplaceTransaction] = try await supabase
            .from("marketplace_transactions")
            .insert(insert)
            .select()
            .execute()
            .value

        guard let transaction = response.first else {
            throw NSError(domain: "MarketplaceService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create transaction"])
        }

        // Mark listing as reserved
        try? await updateListing(listingId: listingId, updates: MarketplaceListingUpdate(status: "reserved"))

        return transaction
    }

    func markAsShipped(transactionId: UUID, trackingNumber: String?, carrier: String?) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        // Verify current user is the seller
        let transaction: MarketplaceTransaction = try await supabase
            .from("marketplace_transactions")
            .select()
            .eq("id", value: transactionId.uuidString)
            .single()
            .execute()
            .value
        let currentUserId = try await currentAuthUserId()
        guard transaction.sellerId == currentUserId else {
            throw NSError(domain: "MarketplaceService", code: 403,
                          userInfo: [NSLocalizedDescriptionKey: "Only the seller can mark as shipped"])
        }

        var updates: [String: String] = [
            "status": "shipped",
            "shipped_at": ISO8601DateFormatter().string(from: Date())
        ]
        if let trackingNumber = trackingNumber { updates["tracking_number"] = trackingNumber }
        if let carrier = carrier { updates["tracking_carrier"] = carrier }

        try await supabase
            .from("marketplace_transactions")
            .update(updates)
            .eq("id", value: transactionId.uuidString)
            .execute()
    }

    func confirmReceipt(transactionId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        // Get transaction details first
        let transaction: MarketplaceTransaction = try await supabase
            .from("marketplace_transactions")
            .select()
            .eq("id", value: transactionId.uuidString)
            .single()
            .execute()
            .value

        // Verify current user is the buyer
        let currentUserId = try await currentAuthUserId()
        guard transaction.buyerId == currentUserId else {
            throw NSError(domain: "MarketplaceService", code: 403,
                          userInfo: [NSLocalizedDescriptionKey: "Only the buyer can confirm receipt"])
        }

        guard transaction.transactionType == .ship else {
            throw NSError(domain: "MarketplaceService", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Receipt confirmation is only available for shipped orders"])
        }

        guard transaction.status == .shipped || transaction.status == .delivered else {
            throw NSError(domain: "MarketplaceService", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "This order is not ready for delivery confirmation"])
        }

        let now = ISO8601DateFormatter().string(from: Date())

        try await supabase
            .from("marketplace_transactions")
            .update([
                "status": "delivered",
                "delivered_at": now,
                "buyer_confirmed_at": now
            ])
            .eq("id", value: transactionId.uuidString)
            .execute()
    }

    func releaseSellerPayout(transactionId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        let transaction: MarketplaceTransaction = try await supabase
            .from("marketplace_transactions")
            .select()
            .eq("id", value: transactionId.uuidString)
            .single()
            .execute()
            .value

        let currentUserId = try await currentAuthUserId()
        guard transaction.buyerId == currentUserId else {
            throw NSError(domain: "MarketplaceService", code: 403,
                          userInfo: [NSLocalizedDescriptionKey: "Only the buyer can release seller funds"])
        }

        guard transaction.transactionType == .ship else {
            throw NSError(domain: "MarketplaceService", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Payout release is only available for shipped orders"])
        }

        guard transaction.status == .delivered || transaction.status == .releasing else {
            throw NSError(domain: "MarketplaceService", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Confirm delivery before releasing seller funds"])
        }

        struct ReleasePayload: Encodable {
            let transaction_id: String
        }
        let payload = ReleasePayload(transaction_id: transactionId.uuidString)

        try await supabase.functions.invoke(
            "release-marketplace-funds",
            options: FunctionInvokeOptions(body: payload)
        )

        // Mark listing as sold
        try? await updateListing(listingId: transaction.listingId, updates: MarketplaceListingUpdate(status: "sold"))
    }

    func scheduleMeetup(
        transactionId: UUID, locationName: String,
        lat: Double, lng: Double, scheduledAt: Date
    ) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        // Verify current user is buyer or seller on this transaction
        let transaction: MarketplaceTransaction = try await supabase
            .from("marketplace_transactions")
            .select()
            .eq("id", value: transactionId.uuidString)
            .single()
            .execute()
            .value
        let currentUserId = try await currentAuthUserId()
        guard transaction.buyerId == currentUserId || transaction.sellerId == currentUserId else {
            throw NSError(domain: "MarketplaceService", code: 403,
                          userInfo: [NSLocalizedDescriptionKey: "Only the buyer or seller can schedule a meetup"])
        }

        try await supabase
            .from("marketplace_transactions")
            .update([
                "meetup_location_name": locationName,
                "meetup_location_lat": "\(lat)",
                "meetup_location_lng": "\(lng)",
                "meetup_scheduled_at": ISO8601DateFormatter().string(from: scheduledAt)
            ])
            .eq("id", value: transactionId.uuidString)
            .execute()
    }

    // NOTE: For production safety, this should use an atomic DB operation (RPC)
    // to prevent races where both parties confirm simultaneously.
    func confirmMeetupComplete(transactionId: UUID, byUserId: UUID) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        // Verify byUserId matches the current authenticated user
        let currentUserId = try await currentAuthUserId()
        guard byUserId == currentUserId else {
            throw NSError(domain: "MarketplaceService", code: 403,
                          userInfo: [NSLocalizedDescriptionKey: "User ID does not match authenticated user"])
        }

        // Get current transaction to check who already confirmed
        let transaction: MarketplaceTransaction = try await supabase
            .from("marketplace_transactions")
            .select()
            .eq("id", value: transactionId.uuidString)
            .single()
            .execute()
            .value

        let isBuyer = byUserId == transaction.buyerId
        let now = ISO8601DateFormatter().string(from: Date())

        var updates: [String: String] = [:]

        if isBuyer {
            updates["buyer_confirmed_at"] = now
            if transaction.sellerConfirmedAt != nil {
                updates["status"] = "meetup_completed"
                updates["completed_at"] = now
            }
        } else {
            updates["seller_confirmed_at"] = now
            if transaction.buyerConfirmedAt != nil {
                updates["status"] = "meetup_completed"
                updates["completed_at"] = now
            }
        }

        try await supabase
            .from("marketplace_transactions")
            .update(updates)
            .eq("id", value: transactionId.uuidString)
            .execute()

        // Re-fetch to verify the state update took effect
        let updatedTransaction: MarketplaceTransaction = try await supabase
            .from("marketplace_transactions")
            .select()
            .eq("id", value: transactionId.uuidString)
            .single()
            .execute()
            .value

        // If both confirmed, mark listing as sold
        if updatedTransaction.status == .meetupCompleted {
            try? await updateListing(listingId: transaction.listingId, updates: MarketplaceListingUpdate(status: "sold"))
        }
    }

    func fetchTransactionsForUser(userId: UUID) async {
        isLoading = true

        if DemoModeManager.shared.isDemoModeEnabled {
            transactions = []
            isLoading = false
            return
        }

        do {
            // Use or() filter instead of two separate queries
            let allTransactions: [MarketplaceTransaction] = try await supabase
                .from("marketplace_transactions")
                .select()
                .or("buyer_id.eq.\(userId.uuidString),seller_id.eq.\(userId.uuidString)")
                .order("created_at", ascending: false)
                .execute()
                .value

            // Batch-fetch all listing IDs and partner IDs
            let listingIds = Array(Set(allTransactions.map { $0.listingId }))
            let partnerIds = Array(Set(allTransactions.map { $0.buyerId == userId ? $0.sellerId : $0.buyerId }))

            // Batch fetch listings
            var listingsMap: [UUID: MarketplaceListing] = [:]
            if !listingIds.isEmpty {
                let fetchedListings: [MarketplaceListing] = try await supabase
                    .from("marketplace_listings")
                    .select()
                    .in("id", values: listingIds.map { $0.uuidString })
                    .execute()
                    .value
                for listing in fetchedListings {
                    listingsMap[listing.id] = listing
                }
            }

            // Batch fetch partner profiles
            var profilesMap: [UUID: HangerAuthorProfile] = [:]
            if !partnerIds.isEmpty {
                let fetchedProfiles: [HangerAuthorProfile] = try await supabase
                    .from("profiles")
                    .select("id, user_type, call_sign, profile_picture_url, first_name, last_name")
                    .in("id", values: partnerIds.map { $0.uuidString })
                    .execute()
                    .value
                for profile in fetchedProfiles {
                    profilesMap[profile.id] = profile
                }
            }

            transactions = allTransactions.map { tx in
                let isBuyer = tx.buyerId == userId
                let partnerId = isBuyer ? tx.sellerId : tx.buyerId
                let listing = listingsMap[tx.listingId]
                let partnerProfile = profilesMap[partnerId]

                return MarketplaceTransactionWithDetails(
                    id: tx.id,
                    transaction: tx,
                    listingTitle: listing?.title ?? "Unknown Item",
                    listingImageUrl: listing?.imageUrls.first,
                    partnerCallSign: partnerProfile?.callSign,
                    partnerProfilePictureUrl: partnerProfile?.profilePictureUrl,
                    partnerFullName: partnerProfile?.publicDisplayName ?? "User",
                    isBuyer: isBuyer
                )
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Reviews

    func submitReview(
        transactionId: UUID, fromUserId: UUID, toUserId: UUID,
        rating: Int, comment: String?
    ) async throws {
        if DemoModeManager.shared.isDemoModeEnabled { return }

        guard (1...5).contains(rating) else {
            throw NSError(domain: "MarketplaceService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Rating must be between 1 and 5"])
        }

        struct ReviewInsert: Encodable {
            let transaction_id: String
            let from_user_id: String
            let to_user_id: String
            let rating: Int
            let comment: String
        }
        let insert = ReviewInsert(
            transaction_id: transactionId.uuidString,
            from_user_id: fromUserId.uuidString,
            to_user_id: toUserId.uuidString,
            rating: rating,
            comment: comment ?? ""
        )

        try await supabase
            .from("marketplace_reviews")
            .insert(insert)
            .execute()

        let reviewerCallSign = await fetchCallSign(userId: fromUserId)
        await NotificationManager.shared.notifyMarketplaceReviewReceived(
            recipientUserId: toUserId,
            reviewerName: reviewerCallSign ?? "A user",
            rating: rating,
            transactionId: transactionId
        )
    }

    func fetchReviewsForUser(userId: UUID) async throws -> [MarketplaceReviewWithProfile] {
        if DemoModeManager.shared.isDemoModeEnabled { return [] }

        let reviews: [MarketplaceReview] = try await supabase
            .from("marketplace_reviews")
            .select()
            .eq("to_user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        var result: [MarketplaceReviewWithProfile] = []
        for review in reviews {
            let profile = await fetchProfile(userId: review.fromUserId)
            result.append(MarketplaceReviewWithProfile(
                id: review.id,
                review: review,
                reviewerCallSign: profile?.callSign,
                reviewerProfilePictureUrl: profile?.profilePictureUrl,
                reviewerFullName: profile?.publicDisplayName ?? "User"
            ))
        }

        return result
    }

    // MARK: - Marketplace Payment (via edge function)

    func createMarketplacePayment(transactionId: UUID) async throws -> MarketplacePaymentResponse {
        if DemoModeManager.shared.isDemoModeEnabled {
            return MarketplacePaymentResponse(
                clientSecret: "demo_secret", paymentIntentId: "demo_pi",
                customerId: "demo_cus", ephemeralKeySecret: "demo_ek",
                platformFee: 0, sellerPayout: 0
            )
        }

        struct Payload: Encodable {
            let transaction_id: String
        }
        let payload = Payload(transaction_id: transactionId.uuidString)

        let response: MarketplacePaymentResponse = try await supabase.functions
            .invoke("create-marketplace-payment", options: FunctionInvokeOptions(body: payload))

        return response
    }

    // MARK: - Check Review Status

    func hasUserReviewed(transactionId: UUID, userId: UUID) async -> Bool {
        if DemoModeManager.shared.isDemoModeEnabled { return false }

        do {
            struct ReviewCheck: Decodable { let id: UUID }
            let reviews: [ReviewCheck] = try await supabase
                .from("marketplace_reviews")
                .select("id")
                .eq("transaction_id", value: transactionId.uuidString)
                .eq("from_user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            return !reviews.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Image Upload

    func uploadListingImages(userId: UUID, images: [UIImage]) async throws -> [String] {
        if DemoModeManager.shared.isDemoModeEnabled { return [] }

        var urls: [String] = []

        for image in images.prefix(6) {
            guard let imageData = compressListingImage(image) else { continue }

            let fileName = "\(userId.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"

            let _ = try await supabase.storage
                .from("marketplace-images")
                .upload(
                    fileName,
                    data: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )

            let publicURL = try supabase.storage
                .from("marketplace-images")
                .getPublicURL(path: fileName)

            urls.append(publicURL.absoluteString)
        }

        return urls
    }

    // MARK: - Private Helpers

    private func compressListingImage(_ image: UIImage) -> Data? {
        let maxSize: CGFloat = 1200
        let size = image.size

        var newSize: CGSize
        if size.width > maxSize || size.height > maxSize {
            if size.width > size.height {
                newSize = CGSize(width: maxSize, height: (size.height / size.width) * maxSize)
            } else {
                newSize = CGSize(width: (size.width / size.height) * maxSize, height: maxSize)
            }
        } else {
            newSize = size
        }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resizedImage.jpegData(compressionQuality: 0.8)
    }

    private func sanitizeSearchPattern(_ query: String) -> String {
        query.replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_")
    }

    private func fetchFavoriteIds(userId: UUID, listingIds: [UUID]) async -> Set<UUID> {
        guard !listingIds.isEmpty else { return [] }

        do {
            let favorites: [MarketplaceFavorite] = try await supabase
                .from("marketplace_favorites")
                .select()
                .eq("user_id", value: userId.uuidString)
                .in("listing_id", values: listingIds.map { $0.uuidString })
                .execute()
                .value

            return Set(favorites.map { $0.listingId })
        } catch {
            return []
        }
    }

    private func mapResponseToListingWithSeller(
        _ resp: MarketplaceListingResponse,
        favoriteIds: Set<UUID>
    ) -> MarketplaceListingWithSeller {
        let profile = resp.profileData
        return MarketplaceListingWithSeller(
            id: resp.id,
            listing: resp.toListing(),
            sellerCallSign: profile?.callSign,
            sellerProfilePictureUrl: profile?.profilePictureUrl,
            sellerFullName: profile?.publicDisplayName ?? "Seller",
            isFavoritedByCurrentUser: favoriteIds.contains(resp.id)
        )
    }

    private func fetchCallSign(userId: UUID) async -> String? {
        let profile = await fetchProfile(userId: userId)
        return profile?.publicDisplayName
    }

    private func fetchProfile(userId: UUID) async -> HangerAuthorProfile? {
        do {
            let profile: HangerAuthorProfile = try await supabase
                .from("profiles")
                .select("id, user_type, call_sign, profile_picture_url, first_name, last_name")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            return profile
        } catch {
            return nil
        }
    }

    // MARK: - Demo Data

    static let demoListings: [MarketplaceListingWithSeller] = [
        MarketplaceListingWithSeller(
            id: UUID(),
            listing: MarketplaceListing(
                id: UUID(), sellerId: UUID(),
                title: "DJI Mini 4 Pro - Like New",
                description: "Barely used DJI Mini 4 Pro with Fly More Combo. Includes 3 batteries, carrying case, and all original accessories.",
                price: 649.99, category: .drones, condition: .likeNew,
                transactionType: .both, status: .active,
                imageUrls: [], brand: "DJI", model: "Mini 4 Pro",
                shippingCost: 15.00, viewCount: 42, favoriteCount: 8, offerCount: 3
            ),
            sellerCallSign: "SkyPilot",
            sellerProfilePictureUrl: nil,
            sellerFullName: "John Smith",
            isFavoritedByCurrentUser: false
        ),
        MarketplaceListingWithSeller(
            id: UUID(),
            listing: MarketplaceListing(
                id: UUID(), sellerId: UUID(),
                title: "FPV Goggles - DJI Goggles 2",
                description: "DJI Goggles 2 in excellent condition. Works with DJI O3 Air Unit and Avata series.",
                price: 349.00, category: .fpvGear, condition: .good,
                transactionType: .ship, status: .active,
                imageUrls: [], brand: "DJI", model: "Goggles 2",
                shippingCost: 12.00, viewCount: 28, favoriteCount: 5, offerCount: 1
            ),
            sellerCallSign: "DroneRacer",
            sellerProfilePictureUrl: nil,
            sellerFullName: "Jane Doe",
            isFavoritedByCurrentUser: true
        ),
        MarketplaceListingWithSeller(
            id: UUID(),
            listing: MarketplaceListing(
                id: UUID(), sellerId: UUID(),
                title: "4x Propellers for Mavic 3",
                description: "Brand new original DJI propellers for Mavic 3 series. Never opened.",
                price: 22.99, category: .propellers, condition: .new,
                transactionType: .ship, status: .active,
                imageUrls: [], brand: "DJI", model: "Mavic 3",
                shippingCost: 5.00, viewCount: 15, favoriteCount: 2, offerCount: 0
            ),
            sellerCallSign: "PropMaster",
            sellerProfilePictureUrl: nil,
            sellerFullName: "Bob Wilson",
            isFavoritedByCurrentUser: false
        )
    ]

    static let demoTransaction = MarketplaceTransaction(
        id: UUID(), listingId: UUID(), buyerId: UUID(), sellerId: UUID(),
        offerId: nil, transactionType: .ship, status: .pendingPayment,
        amount: 100, platformFee: 10, sellerPayout: 90,
        paymentIntentId: nil, chargeId: nil, transferId: nil,
        trackingNumber: nil, trackingCarrier: nil,
        meetupLocationName: nil, meetupLocationLat: nil, meetupLocationLng: nil,
        meetupScheduledAt: nil, buyerConfirmedAt: nil, sellerConfirmedAt: nil,
        shippedAt: nil, deliveredAt: nil, completedAt: nil,
        cancelledAt: nil, cancellationReason: nil,
        createdAt: Date(), updatedAt: Date()
    )
}

// MARK: - Decimal Rounding Helper

private extension Decimal {
    func rounded(scale: Int) -> Decimal {
        var result = Decimal()
        var mutableSelf = self
        NSDecimalRound(&result, &mutableSelf, scale, .bankers)
        return result
    }
}
