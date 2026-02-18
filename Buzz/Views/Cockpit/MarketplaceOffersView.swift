//
//  MarketplaceOffersView.swift
//  Buzz
//
//  Created for Marketplace feature
//

import SwiftUI
import Auth

struct MarketplaceOffersView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var marketplaceService: MarketplaceService
    @Environment(\.dismiss) private var dismiss

    let listingId: UUID
    let isSeller: Bool

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var showAcceptConfirmation = false
    @State private var offerToAccept: MarketplaceOfferResponse?

    var body: some View {
        VStack {
            if isLoading {
                Spacer()
                ProgressView("Loading offers...")
                Spacer()
            } else if marketplaceService.offers.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "tag")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No offers yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(marketplaceService.offers) { offer in
                        offerRow(offer)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(isSeller ? "Offers Received" : "My Offers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            await refreshOffers()
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog("Accept Offer", isPresented: $showAcceptConfirmation, titleVisibility: .visible) {
            Button("Accept") {
                if let offer = offerToAccept {
                    Task {
                        do {
                            try await marketplaceService.acceptOffer(offerId: offer.id)
                            await refreshOffers()
                        } catch {
                            errorMessage = error.localizedDescription
                            showErrorAlert = true
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) { offerToAccept = nil }
        } message: {
            Text("Are you sure you want to accept this offer? Other pending offers will be declined.")
        }
    }

    private func offerRow(_ offer: MarketplaceOfferResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Buyer avatar
                if let urlString = offer.profileData?.profilePictureUrl,
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
                    Text(offer.profileData?.callSign ?? offer.profileData?.fullName ?? "Buyer")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(offer.formattedAmount)
                        .font(.headline)
                        .foregroundColor(.orange)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(offer.status.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(offer.status.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(offer.status.color.opacity(0.15))
                        .cornerRadius(6)

                    Text(hangerTimeAgo(offer.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if let message = offer.message, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 52)
            }

            // Action buttons for seller
            if isSeller && offer.status == .pending {
                HStack(spacing: 12) {
                    Spacer()

                    Button {
                        Task {
                            do {
                                try await marketplaceService.declineOffer(offerId: offer.id)
                                await refreshOffers()
                            } catch {
                                errorMessage = error.localizedDescription
                                showErrorAlert = true
                            }
                        }
                    } label: {
                        Text("Decline")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(8)
                    }

                    Button {
                        offerToAccept = offer
                        showAcceptConfirmation = true
                    } label: {
                        Text("Accept")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 4)
            }

            // Withdraw button for buyer
            if !isSeller && offer.status == .pending {
                HStack {
                    Spacer()
                    Button {
                        Task {
                            do {
                                try await marketplaceService.withdrawOffer(offerId: offer.id)
                                await refreshOffers()
                            } catch {
                                errorMessage = error.localizedDescription
                                showErrorAlert = true
                            }
                        }
                    } label: {
                        Text("Withdraw Offer")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func refreshOffers() async {
        isLoading = true
        if isSeller {
            await marketplaceService.fetchOffersForListing(listingId: listingId)
        } else if let userId = authService.currentUser?.id {
            await marketplaceService.fetchMyOffers(buyerId: userId)
        }
        isLoading = false
    }
}
