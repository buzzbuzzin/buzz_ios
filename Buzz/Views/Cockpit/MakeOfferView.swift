//
//  MakeOfferView.swift
//  Buzz
//
//  Created for Marketplace feature
//

import SwiftUI
import Auth

struct MakeOfferView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var marketplaceService: MarketplaceService
    @Environment(\.dismiss) private var dismiss

    let listing: MarketplaceListingWithSeller

    @State private var offerAmountText = ""
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var offerAmount: Decimal? {
        Decimal(string: offerAmountText)
    }

    private var percentOfAsking: String {
        guard let amount = offerAmount, listing.listing.price > 0 else { return "" }
        let percent = (amount / listing.listing.price) * 100
        let formatted = NSDecimalNumber(decimal: percent).intValue
        return "\(formatted)% of asking price"
    }

    var body: some View {
        VStack(spacing: 20) {
            // Listing summary
            HStack(spacing: 12) {
                if let firstUrl = listing.listing.imageUrls.first,
                   let url = URL(string: firstUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color(.systemGray5)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ZStack {
                        Color(.systemGray5)
                        Image(systemName: listing.listing.category.icon)
                            .foregroundColor(.gray)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.listing.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    Text("Asking: \(listing.listing.formattedPrice)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Offer amount
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Offer")
                    .font(.headline)

                HStack {
                    Text("$")
                        .font(.title)
                        .foregroundColor(.secondary)
                    TextField("0.00", text: $offerAmountText)
                        .font(.title)
                        .keyboardType(.decimalPad)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                if !percentOfAsking.isEmpty {
                    Text(percentOfAsking)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Message
            VStack(alignment: .leading, spacing: 8) {
                Text("Message (Optional)")
                    .font(.headline)

                TextEditor(text: $message)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }

            Spacer()

            // Submit button
            Button {
                submitOffer()
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    }
                    Text("Submit Offer")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(offerAmount != nil && offerAmount! > 0 ? Color.orange : Color.gray)
                .cornerRadius(12)
            }
            .disabled(offerAmount == nil || offerAmount! <= 0 || isSubmitting)
        }
        .padding()
        .navigationTitle("Make Offer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func submitOffer() {
        guard let userId = authService.currentUser?.id,
              let amount = offerAmount else { return }

        isSubmitting = true

        Task {
            do {
                try await marketplaceService.createOffer(
                    listingId: listing.listing.id,
                    buyerId: userId,
                    amount: amount,
                    message: message.isEmpty ? nil : message
                )
                isSubmitting = false
                dismiss()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
