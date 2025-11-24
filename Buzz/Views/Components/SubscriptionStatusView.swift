//
//  SubscriptionStatusView.swift
//  Buzz
//
//  Reusable component for displaying subscription status
//

import SwiftUI
import StoreKit

struct SubscriptionStatusView: View {
    @StateObject private var storeKitManager = StoreKitManager()
    @State private var showManageSubscriptions = false
    
    var body: some View {
        VStack(spacing: 16) {
            if storeKitManager.hasActiveSubscription {
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
                            
                            if let subscription = storeKitManager.getActiveSubscription() {
                                Text(subscription.displayName)
                                    .font(.subheadline)
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
            }
        }
        .task {
            await storeKitManager.updatePurchasedProducts()
        }
        .sheet(isPresented: $showManageSubscriptions) {
            SubscriptionManagementView()
        }
    }
}

// MARK: - Subscription Management View

struct SubscriptionManagementView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "gear")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Manage Your Subscription")
                    .font(.title2)
                    .fontWeight(.bold)
                
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
                    Text("Open Subscription Settings")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
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
            SubscriptionStatusView()
        }
        .padding()
    }
}

