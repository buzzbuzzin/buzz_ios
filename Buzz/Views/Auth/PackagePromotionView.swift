//
//  PackagePromotionView.swift
//  Buzz
//
//  Created for displaying subscription promotion after customer sign up
//

import SwiftUI

// MARK: - Automotive Package Promotion View

struct AutomotivePackagePromotionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var subscriptionService = SubscriptionService()
    @State private var showMembershipDetails = false
    
    var body: some View {
        NavigationView {
            SubscriptionSelectionView(
                subscriptionService: subscriptionService,
                onSubscriptionCreated: {
                    // After subscription is created, dismiss the promotion view
                    dismiss()
                },
                onShowMembershipDetails: {
                    showMembershipDetails = true
                }
            )
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showMembershipDetails) {
            MembershipDetailsView()
                .interactiveDismissDisabled()
        }
    }
}

// MARK: - Real Estate Package Promotion View

struct RealEstatePackagePromotionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var subscriptionService = SubscriptionService()
    @State private var showMembershipDetails = false
    
    var body: some View {
        NavigationView {
            RealEstateSubscriptionSelectionView(
                subscriptionService: subscriptionService,
                onSubscriptionCreated: {
                    // After subscription is created, dismiss the promotion view
                    dismiss()
                },
                onShowMembershipDetails: {
                    showMembershipDetails = true
                }
            )
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showMembershipDetails) {
            RealEstateMembershipDetailsView()
                .interactiveDismissDisabled()
        }
    }
}
