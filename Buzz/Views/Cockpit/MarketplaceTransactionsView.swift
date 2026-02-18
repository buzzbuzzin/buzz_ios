//
//  MarketplaceTransactionsView.swift
//  Buzz
//
//  Created for Marketplace feature
//

import SwiftUI
import Auth

struct MarketplaceTransactionsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var marketplaceService: MarketplaceService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: TransactionTab = .buying

    enum TransactionTab: String, CaseIterable {
        case buying = "Buying"
        case selling = "Selling"
    }

    private var filteredTransactions: [MarketplaceTransactionWithDetails] {
        switch selectedTab {
        case .buying:
            return marketplaceService.transactions.filter { $0.isBuyer }
        case .selling:
            return marketplaceService.transactions.filter { !$0.isBuyer }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(TransactionTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if marketplaceService.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if filteredTransactions.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "bag")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No \(selectedTab.rawValue.lowercased()) transactions")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredTransactions) { detail in
                        NavigationLink {
                            MarketplaceOrderView(transactionDetail: detail)
                                .environmentObject(authService)
                                .environmentObject(marketplaceService)
                        } label: {
                            transactionRow(detail)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Orders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            guard let userId = authService.currentUser?.id else { return }
            await marketplaceService.fetchTransactionsForUser(userId: userId)
        }
    }

    private func transactionRow(_ detail: MarketplaceTransactionWithDetails) -> some View {
        HStack(spacing: 12) {
            // Listing image
            if let imageUrl = detail.listingImageUrl,
               let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(.systemGray5)
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: "shippingbox")
                        .foregroundColor(.gray)
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(detail.listingTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(detail.isBuyer ? "from" : "to")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(detail.partnerCallSign ?? detail.partnerFullName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(detail.transaction.formattedAmount)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(detail.transaction.status.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(detail.transaction.status.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(detail.transaction.status.color.opacity(0.15))
                    .cornerRadius(4)

                Image(systemName: detail.transaction.transactionType == .ship ? "shippingbox" : "person.2")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
