//
//  ListingDetailView.swift
//  Buzz
//
//  Created for Marketplace feature
//

import SwiftUI
import Auth

struct ListingDetailView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var marketplaceService: MarketplaceService

    let listing: MarketplaceListingWithSeller

    @State private var showMakeOffer = false
    @State private var showOffers = false
    @State private var showBuyConfirmation = false
    @State private var showMeetupLocation = false
    @State private var isProcessing = false
    @State private var isFavorited: Bool
    @State private var showDirectMessage = false
    @State private var sellerProfile: UserProfile?
    @State private var isLoadingSellerProfile = false
    @State private var showProfileLoadError = false

    init(listing: MarketplaceListingWithSeller) {
        self.listing = listing
        self._isFavorited = State(initialValue: listing.isFavoritedByCurrentUser)
    }

    private var isOwnListing: Bool {
        authService.currentUser?.id == listing.listing.sellerId
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Image carousel
                if listing.listing.imageUrls.isEmpty {
                    ZStack {
                        Color(.systemGray5)
                        Image(systemName: listing.listing.category.icon)
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    }
                    .frame(height: 300)
                } else {
                    HangerImageCarousel(
                        imageUrls: listing.listing.imageUrls,
                        height: 300
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    // Price and badges
                    HStack {
                        Text(listing.listing.formattedPrice)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)

                        Spacer()

                        // Favorite button
                        if !isOwnListing {
                            Button {
                                isFavorited.toggle()
                                Task {
                                    guard let userId = authService.currentUser?.id else { return }
                                    try? await marketplaceService.toggleFavorite(
                                        listingId: listing.listing.id,
                                        userId: userId
                                    )
                                }
                            } label: {
                                Image(systemName: isFavorited ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundColor(isFavorited ? .red : .secondary)
                            }
                        }
                    }

                    // Badges row
                    HStack(spacing: 8) {
                        badgeView(listing.listing.condition.displayName, color: listing.listing.condition.color)
                        badgeView(listing.listing.transactionType.displayName, icon: listing.listing.transactionType.icon)
                        badgeView(listing.listing.category.displayName, icon: listing.listing.category.icon)
                    }

                    // Title
                    Text(listing.listing.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    // Brand & Model
                    if listing.listing.brand != nil || listing.listing.model != nil {
                        HStack(spacing: 4) {
                            if let brand = listing.listing.brand {
                                Text(brand)
                                    .fontWeight(.medium)
                            }
                            if let model = listing.listing.model {
                                Text(model)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .font(.subheadline)
                    }

                    Divider()

                    // Description
                    Text("Description")
                        .font(.headline)
                    Text(listing.listing.description)
                        .font(.body)
                        .foregroundColor(.secondary)

                    // Shipping info
                    if listing.listing.transactionType != .meetup {
                        Divider()
                        HStack {
                            Image(systemName: "shippingbox.fill")
                                .foregroundColor(.orange)
                            if let shippingCost = listing.listing.shippingCost, shippingCost > 0 {
                                let formatter = NumberFormatter()
                                let _ = formatter.numberStyle = .currency
                                let _ = formatter.currencyCode = "USD"
                                Text("Shipping: \(formatter.string(from: shippingCost as NSDecimalNumber) ?? "$\(shippingCost)")")
                            } else {
                                Text("Shipping cost TBD")
                            }
                            Spacer()
                            Text("Buyer pays shipping")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                    }

                    // Location (for meetup)
                    if listing.listing.transactionType != .ship, let locationName = listing.listing.locationName {
                        Divider()
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.orange)
                            Text(locationName)
                            Spacer()
                        }
                        .font(.subheadline)
                    }

                    Divider()

                    // Seller info
                    HStack(spacing: 12) {
                            if let urlString = listing.sellerProfilePictureUrl,
                               let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Circle().fill(Color(.systemGray4))
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.gray)
                                    }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(listing.sellerCallSign ?? listing.sellerFullName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("Seller")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }

                    // Stats
                    HStack(spacing: 16) {
                        statView(icon: "eye", count: listing.listing.viewCount, label: "views")
                        statView(icon: "heart", count: listing.listing.favoriteCount, label: "saves")
                        statView(icon: "tag", count: listing.listing.offerCount, label: "offers")
                    }
                    .padding(.vertical, 4)

                    // Posted time
                    Text("Posted \(hangerTimeAgo(listing.listing.createdAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                Spacer().frame(height: 100)
            }
        }
        .overlay(alignment: .bottom) {
            if !isOwnListing {
                actionButtons
            } else {
                sellerActionButtons
            }
        }
        .navigationTitle(listing.listing.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMakeOffer) {
            NavigationView {
                MakeOfferView(listing: listing)
                    .environmentObject(authService)
                    .environmentObject(marketplaceService)
            }
        }
        .sheet(isPresented: $showOffers) {
            NavigationView {
                MarketplaceOffersView(listingId: listing.listing.id, isSeller: isOwnListing)
                    .environmentObject(authService)
                    .environmentObject(marketplaceService)
            }
        }
        .sheet(isPresented: $showMeetupLocation) {
            NavigationView {
                MeetupLocationView(onLocationSelected: { _, _, _ in
                    showMeetupLocation = false
                })
                .environmentObject(authService)
            }
        }
        .sheet(isPresented: $showDirectMessage) {
            if let profile = sellerProfile {
                DirectMessageView(
                    pilotId: listing.listing.sellerId,
                    pilotProfile: profile,
                    initialListing: listing
                )
                .environmentObject(authService)
            } else {
                VStack {
                    ProgressView()
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .alert("Error", isPresented: $showProfileLoadError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Could not load seller profile. Please try again.")
        }
        .alert("Buy Now", isPresented: $showBuyConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Proceed to Payment") {
                handleBuyNow()
            }
        } message: {
            let total = listing.listing.price + (listing.listing.shippingCost ?? 0)
            let fee = (total * MarketplaceService.platformFeePercentage)
            Text("Total: \(listing.listing.formattedPrice) + shipping\nPlatform fee (10%): \(formatPrice(fee))\nYou are responsible for shipping costs.")
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                // Message Seller
                Button {
                    guard authService.currentUser != nil else { return }
                    guard !isLoadingSellerProfile else { return }
                    isLoadingSellerProfile = true
                    Task {
                        defer { isLoadingSellerProfile = false }
                        do {
                            let profileService = ProfileService()
                            sellerProfile = try await profileService.getProfile(userId: listing.listing.sellerId)
                            showDirectMessage = true
                        } catch {
                            showProfileLoadError = true
                        }
                    }
                } label: {
                    VStack(spacing: 2) {
                        if isLoadingSellerProfile {
                            ProgressView()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "message.fill")
                                .font(.title3)
                        }
                        Text("Message")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.blue)
                    .frame(width: 50, height: 50)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(12)
                }
                .disabled(isLoadingSellerProfile)

                // Make Offer
                Button {
                    showMakeOffer = true
                } label: {
                    Text("Make Offer")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(12)
                }

                // Buy Now / Schedule Meetup
                if listing.listing.transactionType != .meetup {
                    Button {
                        showBuyConfirmation = true
                    } label: {
                        Text("Buy Now")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isProcessing ? Color.gray : Color.orange)
                            .cornerRadius(12)
                    }
                    .disabled(isProcessing)
                }

                if listing.listing.transactionType != .ship {
                    Button {
                        showMeetupLocation = true
                    } label: {
                        Text("Meetup")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private var sellerActionButtons: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button {
                    showOffers = true
                } label: {
                    HStack {
                        Image(systemName: "tag.fill")
                        Text("Offers (\(listing.listing.offerCount))")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(12)
                }

                Button {
                    guard !isProcessing else { return }
                    isProcessing = true
                    Task {
                        defer { isProcessing = false }
                        try? await marketplaceService.updateListing(
                            listingId: listing.listing.id,
                            updates: MarketplaceListingUpdate(status: "sold")
                        )
                    }
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView().tint(.white)
                        }
                        Text("Mark as Sold")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isProcessing ? Color.gray : Color.green)
                    .cornerRadius(12)
                }
                .disabled(isProcessing)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Helpers

    private func badgeView(_ text: String, color: Color = .secondary, icon: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .cornerRadius(6)
    }

    private func statView(icon: String, count: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(count) \(label)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }

    private func handleBuyNow() {
        guard let buyerId = authService.currentUser?.id, !isProcessing else { return }
        isProcessing = true
        Task {
            defer { isProcessing = false }
            do {
                let transaction = try await marketplaceService.createShipTransaction(
                    listingId: listing.listing.id,
                    buyerId: buyerId,
                    sellerId: listing.listing.sellerId,
                    offerId: nil,
                    amount: listing.listing.price
                )

                // Create payment intent via marketplace edge function
                // (this also stores payment_intent_id on the transaction row)
                let paymentResponse = try await marketplaceService.createMarketplacePayment(
                    transactionId: transaction.id
                )

                // Present payment sheet
                let paymentService = PaymentService()
                let result = try await paymentService.presentPaymentSheet(
                    paymentIntentClientSecret: paymentResponse.clientSecret,
                    customerId: paymentResponse.customerId,
                    customerEphemeralKeySecret: paymentResponse.ephemeralKeySecret
                )

                switch result {
                case .completed:
                    // Mark listing as reserved
                    try await marketplaceService.updateListing(
                        listingId: listing.listing.id,
                        updates: MarketplaceListingUpdate(status: "reserved")
                    )

                    await NotificationManager.shared.notifyMarketplaceItemPurchased(
                        recipientUserId: listing.listing.sellerId,
                        listingTitle: listing.listing.title,
                        buyerName: authService.userProfile?.callSign ?? "A buyer",
                        listingId: listing.listing.id,
                        transactionId: transaction.id
                    )
                case .cancelled:
                    break
                case .failed:
                    marketplaceService.errorMessage = "Payment failed. Please try again."
                }
            } catch {
                marketplaceService.errorMessage = error.localizedDescription
            }
        }
    }
}
