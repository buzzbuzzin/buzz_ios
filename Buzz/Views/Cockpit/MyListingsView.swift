//
//  MyListingsView.swift
//  Buzz
//
//  Created for Marketplace feature
//

import SwiftUI
import Auth

struct MyListingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var marketplaceService: MarketplaceService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFilter: ListingFilter = .active
    @State private var showDeleteConfirmation = false
    @State private var listingToDelete: UUID?
    @State private var deleteErrorMessage: String?
    @State private var showDeleteError = false
    @State private var selectedListingDetail: MarketplaceListingWithSeller?

    enum ListingFilter: String, CaseIterable {
        case active = "Active"
        case sold = "Sold"
        case all = "All"
    }

    private var filteredListings: [MarketplaceListingWithSeller] {
        switch selectedFilter {
        case .active:
            return marketplaceService.myListings.filter { $0.listing.status == .active }
        case .sold:
            return marketplaceService.myListings.filter { $0.listing.status == .sold }
        case .all:
            return marketplaceService.myListings
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Segmented control
            Picker("Filter", selection: $selectedFilter) {
                ForEach(ListingFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if marketplaceService.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if filteredListings.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No \(selectedFilter.rawValue.lowercased()) listings")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredListings) { listing in
                        HStack(spacing: 12) {
                            // Thumbnail
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
                                    .lineLimit(1)

                                Text(listing.listing.formattedPrice)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)

                                HStack(spacing: 12) {
                                    Label("\(listing.listing.viewCount)", systemImage: "eye")
                                    Label("\(listing.listing.favoriteCount)", systemImage: "heart")
                                    Label("\(listing.listing.offerCount)", systemImage: "tag")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Status badge
                            Text(listing.listing.status.displayName)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(listing.listing.status.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(listing.listing.status.color.opacity(0.15))
                                .cornerRadius(6)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedListingDetail = listing
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                listingToDelete = listing.listing.id
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            if listing.listing.status == .active {
                                Button {
                                    Task {
                                        try? await marketplaceService.updateListing(
                                            listingId: listing.listing.id,
                                            updates: MarketplaceListingUpdate(status: "sold")
                                        )
                                        await refreshMyListings()
                                    }
                                } label: {
                                    Label("Sold", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("My Listings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
            }
        }
        .task { await refreshMyListings() }
        .alert("Delete Listing?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { listingToDelete = nil }
            Button("Delete", role: .destructive) {
                if let id = listingToDelete {
                    Task {
                        do {
                            try await marketplaceService.deleteListing(listingId: id)
                            await refreshMyListings()
                        } catch {
                            deleteErrorMessage = error.localizedDescription
                            showDeleteError = true
                        }
                    }
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Delete Failed", isPresented: $showDeleteError) {
            Button("OK") { deleteErrorMessage = nil }
        } message: {
            Text(deleteErrorMessage ?? "An error occurred.")
        }
        .sheet(item: $selectedListingDetail) { listing in
            NavigationView {
                ListingDetailView(listing: listing)
                    .environmentObject(authService)
                    .environmentObject(marketplaceService)
            }
        }
    }

    private func refreshMyListings() async {
        guard let userId = authService.currentUser?.id else { return }
        await marketplaceService.fetchMyListings(sellerId: userId)
    }
}
