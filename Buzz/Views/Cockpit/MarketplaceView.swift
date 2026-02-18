//
//  MarketplaceView.swift
//  Buzz
//
//  Created for Marketplace feature
//

import SwiftUI
import Auth

struct MarketplaceView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var marketplaceService = MarketplaceService()

    @State private var searchText = ""
    @State private var selectedCategory: MarketplaceCategory?
    @State private var sortOption: MarketplaceSortOption = .newest
    @State private var showCreateListing = false
    @State private var showMyListings = false
    @State private var showTransactions = false
    @State private var showFilters = false
    @State private var selectedListing: MarketplaceListingWithSeller?
    @State private var showListingDetail = false
    @State private var refreshTask: Task<Void, Never>?
    @State private var showErrorAlert = false

    // Filter state
    @State private var filterCondition: ListingCondition?
    @State private var filterTransactionType: MarketplaceTransactionType?
    @State private var filterMinPrice: Decimal?
    @State private var filterMaxPrice: Decimal?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search drone parts...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit { refreshListings() }
                    if !searchText.isEmpty {
                        Button { searchText = ""; refreshListings() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)

                // Category filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryPill(nil, label: "All")
                        ForEach(MarketplaceCategory.allCases) { category in
                            categoryPill(category, label: category.displayName)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                // Sort & Filter bar
                HStack {
                    Menu {
                        ForEach(MarketplaceSortOption.allCases) { option in
                            Button {
                                sortOption = option
                                refreshListings()
                            } label: {
                                HStack {
                                    Text(option.displayName)
                                    if sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(sortOption.displayName)
                        }
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }

                    Button {
                        showFilters = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease")
                            Text("Filters")
                            if hasActiveFilters {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }

                    Spacer()

                    Text("\(marketplaceService.listings.count) listings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Listings grid
                if marketplaceService.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if marketplaceService.listings.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(marketplaceService.listings) { listing in
                                MarketplaceListingCard(
                                    listing: listing,
                                    onFavoriteTap: {
                                        Task {
                                            guard let userId = authService.currentUser?.id else { return }
                                            try? await marketplaceService.toggleFavorite(
                                                listingId: listing.listing.id,
                                                userId: userId
                                            )
                                        }
                                    }
                                )
                                .onTapGesture {
                                    selectedListing = listing
                                    showListingDetail = true
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 80)
                    }
                    .refreshable { refreshListings() }
                }
            }

            // FAB - Create Listing
            Button {
                showCreateListing = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.orange)
                    .clipShape(Circle())
                    .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(20)
        }
        .navigationTitle("Marketplace")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showTransactions = true
                    } label: {
                        Image(systemName: "bag")
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("Orders")

                    Button {
                        showMyListings = true
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("My Listings")
                }
            }
        }
        .task {
            refreshListings()
        }
        .sheet(isPresented: $showCreateListing, onDismiss: {
            refreshListings()
        }) {
            NavigationView {
                CreateListingView()
                    .environmentObject(authService)
                    .environmentObject(marketplaceService)
            }
        }
        .sheet(isPresented: $showMyListings) {
            NavigationView {
                MyListingsView()
                    .environmentObject(authService)
                    .environmentObject(marketplaceService)
            }
        }
        .sheet(isPresented: $showTransactions) {
            NavigationView {
                MarketplaceTransactionsView()
                    .environmentObject(authService)
                    .environmentObject(marketplaceService)
            }
        }
        .sheet(isPresented: $showFilters) {
            NavigationView {
                MarketplaceSearchView(
                    selectedCondition: $filterCondition,
                    selectedTransactionType: $filterTransactionType,
                    minPrice: $filterMinPrice,
                    maxPrice: $filterMaxPrice,
                    onApply: { refreshListings() }
                )
            }
        }
        .navigationDestination(isPresented: $showListingDetail) {
            if let listing = selectedListing {
                ListingDetailView(listing: listing)
                    .environmentObject(authService)
                    .environmentObject(marketplaceService)
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { marketplaceService.errorMessage = nil }
        } message: {
            Text(marketplaceService.errorMessage ?? "")
        }
        .onChange(of: marketplaceService.errorMessage) { _, newValue in
            showErrorAlert = newValue != nil
        }
    }

    // MARK: - Components

    private func categoryPill(_ category: MarketplaceCategory?, label: String) -> some View {
        Button {
            selectedCategory = category
            refreshListings()
        } label: {
            HStack(spacing: 4) {
                if let category = category {
                    Image(systemName: category.icon)
                        .font(.system(size: 11))
                }
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(selectedCategory == category ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selectedCategory == category ? Color.orange : Color(.systemGray6))
            .cornerRadius(20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "storefront")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No Listings Found")
                .font(.headline)
                .foregroundColor(.primary)
            if hasActiveFilters || !searchText.isEmpty {
                Text("Try adjusting your filters or search terms.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Clear Filters") {
                    selectedCategory = nil
                    filterCondition = nil
                    filterTransactionType = nil
                    filterMinPrice = nil
                    filterMaxPrice = nil
                    searchText = ""
                    refreshListings()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            } else {
                Text("Be the first to list a drone part for sale!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Create Listing") {
                    showCreateListing = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            Spacer()
        }
        .padding()
    }

    private var hasActiveFilters: Bool {
        filterCondition != nil || filterTransactionType != nil ||
        filterMinPrice != nil || filterMaxPrice != nil
    }

    // MARK: - Data

    private func refreshListings() {
        guard let userId = authService.currentUser?.id else { return }
        refreshTask?.cancel()
        refreshTask = Task {
            await marketplaceService.fetchListings(
                category: selectedCategory,
                condition: filterCondition,
                transactionType: filterTransactionType,
                minPrice: filterMinPrice,
                maxPrice: filterMaxPrice,
                searchQuery: searchText.isEmpty ? nil : searchText,
                sortBy: sortOption,
                currentUserId: userId
            )
        }
    }
}
