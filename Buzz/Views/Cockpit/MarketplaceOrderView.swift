//
//  MarketplaceOrderView.swift
//  Buzz
//
//  Created for Marketplace feature
//

import SwiftUI
import Auth
import UIKit

struct MarketplaceOrderView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var marketplaceService: MarketplaceService

    @State private var currentTransactionDetail: MarketplaceTransactionWithDetails
    @State private var trackingNumber = ""
    @State private var trackingCarrier = ""
    @State private var showShippingForm = false
    @State private var showReview = false
    @State private var showMeetupLocation = false
    @State private var showCopiedAlert = false
    @State private var isProcessing = false
    @State private var isShipping = false
    @State private var hasReviewed = false
    @State private var meetupDate = Date().addingTimeInterval(86400)
    @State private var errorMessage: String?
    @State private var showErrorAlert = false

    init(transactionDetail: MarketplaceTransactionWithDetails) {
        _currentTransactionDetail = State(initialValue: transactionDetail)
    }

    private var tx: MarketplaceTransaction { currentTransactionDetail.transaction }
    private var isBuyer: Bool { currentTransactionDetail.isBuyer }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status header
                statusHeader

                // Listing info
                listingCard

                // Partner info
                partnerCard

                // Transaction details
                transactionDetails

                // Shipping / Meetup details
                if tx.transactionType == .ship {
                    shippingSection
                } else {
                    meetupSection
                }

                // Action buttons
                actionSection

                Spacer().frame(height: 40)
            }
            .padding()
        }
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShippingForm) {
            shippingFormSheet
        }
        .sheet(isPresented: $showReview) {
            NavigationView {
                MarketplaceReviewView(
                    transactionId: tx.id,
                    toUserId: isBuyer ? tx.sellerId : tx.buyerId,
                    partnerName: currentTransactionDetail.partnerCallSign ?? currentTransactionDetail.partnerFullName,
                    onReviewSubmitted: {
                        hasReviewed = true
                        Task {
                            await refreshTransactionDetail()
                        }
                    }
                )
                .environmentObject(authService)
                .environmentObject(marketplaceService)
            }
        }
        .sheet(isPresented: $showMeetupLocation) {
            NavigationView {
                VStack(spacing: 0) {
                    MeetupLocationView { name, lat, lng in
                        Task {
                            do {
                                try await marketplaceService.scheduleMeetup(
                                    transactionId: tx.id,
                                    locationName: name, lat: lat, lng: lng,
                                    scheduledAt: meetupDate
                                )
                                await refreshTransactionDetail()
                                showMeetupLocation = false
                            } catch {
                                errorMessage = error.localizedDescription
                                showErrorAlert = true
                            }
                        }
                    }
                    .environmentObject(authService)

                    Divider()
                    DatePicker(
                        "Meetup Date & Time",
                        selection: $meetupDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .padding()
                    .background(Color(.secondarySystemBackground))
                }
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .alert("Copied", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Tracking number copied.")
        }
        .task {
            await refreshTransactionDetail()
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: tx.status.icon)
                .font(.system(size: 40))
                .foregroundColor(tx.status.color)

            Text(tx.status.displayName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(tx.status.color)

            // Progress steps for ship
            if tx.transactionType == .ship {
                HStack(spacing: 4) {
                    progressDot(active: true, label: "Paid")
                    progressLine(active: shipStep >= 1)
                    progressDot(active: shipStep >= 1, label: "Shipped")
                    progressLine(active: shipStep >= 2)
                    progressDot(active: shipStep >= 2, label: "Delivered")
                    progressLine(active: shipStep >= 3)
                    progressDot(active: shipStep >= 3, label: "Payout")
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(tx.status.color.opacity(0.1))
        .cornerRadius(12)
    }

    private var shipStep: Int {
        switch tx.status {
        case .paid: return 0
        case .shipped: return 1
        case .delivered: return 2
        case .releasing, .completed: return 3
        default: return 0
        }
    }

    // MARK: - Listing Card

    private var listingCard: some View {
        HStack(spacing: 12) {
            if let imageUrl = currentTransactionDetail.listingImageUrl,
               let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(.systemGray5)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(currentTransactionDetail.listingTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(tx.formattedAmount)
                    .font(.headline)
                    .foregroundColor(.orange)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Partner Card

    private var partnerCard: some View {
        HStack(spacing: 12) {
            if let urlString = currentTransactionDetail.partnerProfilePictureUrl,
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
                Text(isBuyer ? "Seller" : "Buyer")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(currentTransactionDetail.partnerCallSign ?? currentTransactionDetail.partnerFullName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Transaction Details

    private var transactionDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transaction Details")
                .font(.headline)

            detailRow("Amount", value: tx.formattedAmount)

            if tx.platformFee > 0 {
                let formatter = NumberFormatter()
                let _ = formatter.numberStyle = .currency
                detailRow("Platform Fee (10%)", value: formatter.string(from: tx.platformFee as NSDecimalNumber) ?? "")
                detailRow("Seller Receives", value: formatter.string(from: tx.sellerPayout as NSDecimalNumber) ?? "")
            }

            detailRow("Type", value: tx.transactionType == .ship ? "Ship" : "In-Person Meetup")
            detailRow("Created", value: formatDate(tx.createdAt))
            if tx.transactionType == .ship {
                detailRow("Buyer Protection", value: payoutProtectionStatus)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Shipping Section

    private var shippingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shipping Details")
                .font(.headline)

            if let tracking = tx.trackingNumber {
                HStack(alignment: .top) {
                    Text("Tracking")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(tracking)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack(spacing: 8) {
                            Button("Copy") {
                                UIPasteboard.general.string = tracking
                                showCopiedAlert = true
                            }
                            .font(.caption)

                            if let trackingURL {
                                Link("Track Package", destination: trackingURL)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            if let carrier = tx.trackingCarrier {
                detailRow("Carrier", value: carrier)
            }
            if let shippedAt = tx.shippedAt {
                detailRow("Shipped", value: formatDate(shippedAt))
            }
            if let deliveredAt = tx.deliveredAt {
                detailRow("Delivered", value: formatDate(deliveredAt))
            }
            if tx.status == .releasing {
                detailRow("Payout", value: "Release in progress")
            } else if tx.status == .completed {
                detailRow("Payout", value: "Released")
            }

            protectionBanner

            if tx.trackingNumber == nil && tx.status == .paid {
                HStack {
                    Image(systemName: "shippingbox")
                        .foregroundColor(.orange)
                    Text(isBuyer ? "Waiting for seller to ship..." : "Ready to ship!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Meetup Section

    private var meetupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meetup Details")
                .font(.headline)

            if let locationName = tx.meetupLocationName {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.blue)
                    Text(locationName)
                        .font(.subheadline)
                }
            }

            if let scheduledAt = tx.meetupScheduledAt {
                detailRow("Scheduled", value: formatDate(scheduledAt))
            }

            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.blue)
                Text("We recommend meeting at a nearby police station for safety")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Action Section

    private var actionSection: some View {
        VStack(spacing: 12) {
            // Seller: Mark as shipped
            if !isBuyer && tx.status == .paid {
                Button {
                    showShippingForm = true
                } label: {
                    Label("Mark as Shipped", systemImage: "shippingbox.fill")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange)
                        .cornerRadius(12)
                }
            }

            // Buyer: Confirm receipt
            if isBuyer && tx.status == .shipped {
                Button {
                    guard !isProcessing else { return }
                    isProcessing = true
                    Task {
                        defer { isProcessing = false }
                        do {
                            try await marketplaceService.confirmReceipt(transactionId: tx.id)
                            await refreshTransactionDetail()
                        } catch {
                            errorMessage = error.localizedDescription
                            showErrorAlert = true
                        }
                    }
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView().tint(.white)
                        }
                        Label("Mark as Delivered", systemImage: "checkmark.circle.fill")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isProcessing ? Color.gray : Color.green)
                    .cornerRadius(12)
                }
                .disabled(isProcessing)
            }

            if isBuyer && tx.status == .delivered {
                Button {
                    guard !isProcessing else { return }
                    isProcessing = true
                    Task {
                        defer { isProcessing = false }
                        do {
                            try await marketplaceService.releaseSellerPayout(transactionId: tx.id)
                            await refreshTransactionDetail()
                        } catch {
                            errorMessage = error.localizedDescription
                            showErrorAlert = true
                        }
                    }
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView().tint(.white)
                        }
                        Label("Release Seller Payout", systemImage: "banknote.fill")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isProcessing ? Color.gray : Color.orange)
                    .cornerRadius(12)
                }
                .disabled(isProcessing)
            }

            if !isBuyer && tx.status == .delivered {
                infoActionCard(
                    icon: "clock.badge.checkmark",
                    color: .orange,
                    text: "Buyer confirmed delivery. Payout stays on hold until the buyer releases funds."
                )
            }

            if tx.status == .releasing {
                infoActionCard(
                    icon: "hourglass",
                    color: .indigo,
                    text: "Buzz is releasing the seller payout now. This usually finishes automatically."
                )
            }

            // Meetup: Find safe location
            if tx.transactionType == .meetup && tx.meetupLocationName == nil {
                Button {
                    showMeetupLocation = true
                } label: {
                    Label("Find Safe Meetup Location", systemImage: "shield.checkered")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }

            // Meetup: Confirm complete
            if tx.transactionType == .meetup && tx.status == .meetupScheduled {
                let hasConfirmed = isBuyer ? tx.buyerConfirmedAt != nil : tx.sellerConfirmedAt != nil
                if !hasConfirmed {
                    Button {
                        guard let userId = authService.activeUserId, !isProcessing else { return }
                        isProcessing = true
                        Task {
                            defer { isProcessing = false }
                            do {
                                try await marketplaceService.confirmMeetupComplete(
                                    transactionId: tx.id, byUserId: userId
                                )
                                await refreshTransactionDetail()
                            } catch {
                                errorMessage = error.localizedDescription
                                showErrorAlert = true
                            }
                        }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView().tint(.white)
                            }
                            Label("Confirm Meetup Complete", systemImage: "checkmark.seal.fill")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isProcessing ? Color.gray : Color.green)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing)
                } else {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                        Text("Waiting for the other party to confirm...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }

            // Leave review (after completion)
            if (tx.status == .completed || tx.status == .meetupCompleted) && !hasReviewed {
                Button {
                    showReview = true
                } label: {
                    Label("Leave Review", systemImage: "star.fill")
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Shipping Form Sheet

    private var shippingFormSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Enter Shipping Details")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tracking Number (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("Enter tracking number", text: $trackingNumber)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Carrier (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("e.g., USPS, UPS, FedEx", text: $trackingCarrier)
                        .textFieldStyle(.roundedBorder)
                }

                Spacer()

                Button {
                    guard !isShipping else { return }
                    isShipping = true
                    Task {
                        defer { isShipping = false }
                        do {
                            try await marketplaceService.markAsShipped(
                                transactionId: tx.id,
                                trackingNumber: trackingNumber.isEmpty ? nil : trackingNumber,
                                carrier: trackingCarrier.isEmpty ? nil : trackingCarrier
                            )
                            await refreshTransactionDetail()
                            showShippingForm = false
                        } catch {
                            errorMessage = error.localizedDescription
                            showErrorAlert = true
                        }
                    }
                } label: {
                    HStack {
                        if isShipping {
                            ProgressView().tint(.white)
                        }
                        Text("Confirm Shipped")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isShipping ? Color.gray : Color.orange)
                    .cornerRadius(12)
                }
                .disabled(isShipping)
            }
            .padding()
            .navigationTitle("Shipping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showShippingForm = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var payoutProtectionStatus: String {
        switch tx.status {
        case .paid, .shipped:
            return "On hold"
        case .delivered:
            return "Awaiting release"
        case .releasing:
            return "Releasing"
        case .completed:
            return "Released"
        default:
            return "N/A"
        }
    }

    private var trackingURL: URL? {
        guard let tracking = tx.trackingNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
              !tracking.isEmpty else { return nil }

        let encodedTracking = tracking.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tracking
        let carrier = tx.trackingCarrier?.lowercased() ?? ""

        if carrier.contains("ups") {
            return URL(string: "https://www.ups.com/track?tracknum=\(encodedTracking)")
        }
        if carrier.contains("fedex") {
            return URL(string: "https://www.fedex.com/fedextrack/?trknbr=\(encodedTracking)")
        }
        if carrier.contains("usps") || carrier.contains("postal") {
            return URL(string: "https://tools.usps.com/go/TrackConfirmAction?tLabels=\(encodedTracking)")
        }
        if carrier.contains("dhl") {
            return URL(string: "https://www.dhl.com/us-en/home/tracking/tracking-express.html?submit=1&tracking-id=\(encodedTracking)")
        }

        return nil
    }

    private var protectionBanner: some View {
        Group {
            if let config = protectionBannerConfiguration {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: config.icon)
                        .foregroundColor(config.color)
                    Text(config.text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(config.color.opacity(0.10))
                .cornerRadius(10)
            }
        }
    }

    private var protectionBannerConfiguration: (text: String, icon: String, color: Color)? {
        switch tx.status {
        case .paid:
            return (
                isBuyer
                    ? "Funds are authorized. Seller payout stays on hold until the order is delivered and you release it."
                    : "Buyer payment is secured. Your payout will remain on hold until delivery is confirmed and released.",
                "lock.shield.fill",
                .blue
            )
        case .shipped:
            return (
                isBuyer
                    ? "Package is in transit. Mark it delivered first, then release payout once everything looks correct."
                    : "Package is in transit. Buyer protection remains active until delivery is confirmed.",
                "shippingbox.fill",
                .purple
            )
        case .delivered:
            return (
                isBuyer
                    ? "Delivery is confirmed. Review the item and release payout when you are satisfied."
                    : "Delivery is confirmed. Buyer still needs to release payout.",
                "checkmark.shield.fill",
                .orange
            )
        case .releasing:
            return ("Payout release is in progress.", "hourglass", .indigo)
        case .completed:
            return ("Transaction complete. Seller payout has been released.", "checkmark.seal.fill", .green)
        default:
            return nil
        }
    }

    private func infoActionCard(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(color.opacity(0.10))
        .cornerRadius(12)
    }

    private func progressDot(active: Bool, label: String) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(active ? Color.orange : Color(.systemGray4))
                .frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(active ? .primary : .secondary)
        }
    }

    private func progressLine(active: Bool) -> some View {
        Rectangle()
            .fill(active ? Color.orange : Color(.systemGray4))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
    }

    private func refreshTransactionDetail() async {
        guard let userId = authService.activeUserId else { return }

        await marketplaceService.fetchTransactionsForUser(userId: userId)
        if let updatedDetail = marketplaceService.transactions.first(where: { $0.id == tx.id }) {
            currentTransactionDetail = updatedDetail
        }

        if tx.status == .completed || tx.status == .meetupCompleted {
            hasReviewed = await marketplaceService.hasUserReviewed(
                transactionId: tx.id,
                userId: userId
            )
        } else {
            hasReviewed = false
        }
    }
}
