//
//  SubscriptionStatusView.swift
//  Buzz
//
//  Reusable component for displaying subscription status
//  Now checks both Apple StoreKit and Stripe backend subscriptions
//

import SwiftUI
import StoreKit

struct SubscriptionStatusView: View {
    let pilotId: UUID
    @StateObject private var storeKitManager = StoreKitManager()
    @ObservedObject private var entitlementManager = EntitlementManager.shared
    @State private var showManageSubscriptions = false
    @State private var isCheckingSubscription = true
    
    /// Check if user has active subscription from any source
    private var hasActiveSubscription: Bool {
        entitlementManager.hasAcademyPass
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if isCheckingSubscription {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Checking subscription...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if hasActiveSubscription {
                // Active subscription
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Academy Pass Active")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            // Show subscription source
                            Text("via \(entitlementManager.subscriptionSourceDisplayName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            // Show Apple subscription details if from Apple
                            if entitlementManager.subscriptionSource == .apple,
                               let subscription = storeKitManager.getActiveSubscription() {
                                Text(subscription.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    Button(action: {
                        showManageSubscriptions = true
                    }) {
                        Text("Manage Subscription")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Academy Pass Active, via \(entitlementManager.subscriptionSourceDisplayName)")
            } else {
                // No active subscription
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No Active Subscription")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Subscribe to unlock all content")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No active subscription. Subscribe to unlock all content.")
            }
        }
        .task {
            // Check ALL subscription sources (Apple + Stripe backend)
            isCheckingSubscription = true
            _ = await storeKitManager.checkAllSubscriptions(pilotId: pilotId)
            isCheckingSubscription = false
        }
        .sheet(isPresented: $showManageSubscriptions) {
            SubscriptionManagementView(subscriptionSource: entitlementManager.subscriptionSource ?? .stripe)
        }
    }
}

// MARK: - Subscription Management View

struct SubscriptionManagementView: View {
    let subscriptionSource: SubscriptionSource
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: subscriptionSource == .apple ? "applelogo" : "globe")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Manage Your Subscription")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if subscriptionSource == .apple {
                    Text("To manage your subscription, go to Settings → Apple ID → Subscriptions")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        // Open iOS Settings app to subscriptions
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Open App Store Subscriptions")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                } else if subscriptionSource == .stripe {
                    Text("Your subscription was purchased through our website. Manage it on the Buzz Academy website.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        // Open website to manage Stripe subscription
                        if let url = URL(string: "https://academy.buzzbuzzin.com/account") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Manage on Website")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                } else {
                    Text("No active subscription found.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Manage Subscriptions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct SubscriptionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SubscriptionStatusView(pilotId: UUID())
        }
        .padding()
    }
}

