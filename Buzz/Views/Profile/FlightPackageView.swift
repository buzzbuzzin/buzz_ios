//
//  FlightPackageView.swift
//  Buzz
//
//  Created for displaying customer subscription information
//

import SwiftUI
import Auth
import Foundation

struct FlightPackageView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var subscriptionService = SubscriptionService()
    @State private var selectedTab: PackageTab = .managePackage
    @State private var currentPlan: String? = "Basic Plan" // Placeholder - will be fetched from backend
    @State private var showPauseAlert = false
    @State private var showEndMembershipAlert = false
    @State private var showLearnMore = false
    @State private var isLoadingSubscription = true
    @State private var hasActiveSubscription = false
    @State private var loadTask: Task<Void, Never>?
    @State private var hasLoadedOnce = false // Track if we've loaded at least once
    @State private var isLoadingInProgress = false // Prevent concurrent loads
    
    enum PackageTab: String, CaseIterable {
        case managePackage = "Manage Package"
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoadingSubscription {
                    VStack {
                        Spacer()
                        ProgressView()
                        Text("Loading subscription...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top)
                        Spacer()
                    }
                } else if hasActiveSubscription {
                    // Show management view if subscription exists
                    VStack(spacing: 0) {
                        // Tab selector (currently only one tab, but structure allows for expansion)
                        Picker("Package Tab", selection: $selectedTab) {
                            ForEach(PackageTab.allCases, id: \.self) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        
                        // Content based on selected tab
                        ScrollView {
                            VStack(spacing: 24) {
                                switch selectedTab {
                                case .managePackage:
                                    ManagePackageView(
                                        currentPlan: $currentPlan,
                                        showPauseAlert: $showPauseAlert,
                                        showEndMembershipAlert: $showEndMembershipAlert,
                                        showLearnMore: $showLearnMore,
                                        subscription: subscriptionService.currentSubscription
                                    )
                                }
                            }
                            .padding()
                            .padding(.top, 0)
                        }
                    }
                } else {
                    // Show subscription selection view if no subscription
                    SubscriptionSelectionView(
                        subscriptionService: subscriptionService,
                        onSubscriptionCreated: {
                            Task {
                                await loadSubscription()
                            }
                        }
                    )
                }
            }
//            .navigationTitle("Buzz Auto")
            .navigationBarTitleDisplayMode(.large)
            .alert("Pause Membership", isPresented: $showPauseAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Pause", role: .destructive) {
                    pauseMembership()
                }
            } message: {
                Text("Your membership will be paused. You can reactivate it anytime from this page.")
            }
            .alert("End Membership", isPresented: $showEndMembershipAlert) {
                Button("Cancel", role: .cancel) {}
                Button("End Membership", role: .destructive) {
                    endMembership()
                }
            } message: {
                Text("Are you sure you want to end your membership? This action cannot be undone.")
            }
            .sheet(isPresented: $showLearnMore) {
                LearnMoreView()
            }
        }
        .onAppear {
            // Use onAppear instead of .task to prevent retriggering on state changes
            print("📱 View appeared, hasLoadedOnce=\(hasLoadedOnce)")
            guard !hasLoadedOnce else {
                print("⏭️ Already loaded, skipping")
                return
            }
            hasLoadedOnce = true
            
            // Cancel any existing task
            loadTask?.cancel()
            loadTask = Task {
                await loadSubscription()
            }
        }
        .onDisappear {
            print("👋 View disappearing, canceling tasks")
            // Cancel task when view disappears
            loadTask?.cancel()
            isLoadingInProgress = false
            hasLoadedOnce = false // Reset so it can load again when view reappears
        }
    }
    
    private func loadSubscription() async {
        // Prevent concurrent or duplicate loads
        guard !isLoadingInProgress else {
            print("⚠️ Load already in progress, skipping")
            return
        }
        
        guard let currentUser = authService.currentUser else {
            isLoadingSubscription = false
            return
        }
        
        print("🔄 Starting subscription load...")
        isLoadingInProgress = true
        isLoadingSubscription = true
        
        do {
            if let subscription = try await subscriptionService.fetchCurrentSubscription(customerId: currentUser.id) {
                hasActiveSubscription = subscription.isActive
                if let plan = subscription.plan {
                    currentPlan = plan.name
                }
                print("✅ Subscription loaded: active=\(subscription.isActive)")
            } else {
                hasActiveSubscription = false
                print("ℹ️ No subscription found")
            }
        } catch {
            // Only log non-cancellation errors
            if let nsError = error as NSError?, nsError.code != NSURLErrorCancelled {
                print("❌ Error loading subscription: \(error)")
            }
            hasActiveSubscription = false
        }
        
        isLoadingSubscription = false
        isLoadingInProgress = false
        print("✅ Subscription load complete")
    }
    
    private func pauseMembership() {
        guard let subscription = subscriptionService.currentSubscription,
              let stripeSubscriptionId = subscription.stripeSubscriptionId else { return }
        
        Task {
            do {
                try await subscriptionService.pauseSubscription(subscriptionId: stripeSubscriptionId)
                await loadSubscription()
            } catch {
                print("Error pausing membership: \(error)")
            }
        }
    }
    
    private func endMembership() {
        guard let subscription = subscriptionService.currentSubscription,
              let stripeSubscriptionId = subscription.stripeSubscriptionId else { return }
        
        Task {
            do {
                try await subscriptionService.cancelSubscription(subscriptionId: stripeSubscriptionId)
                await loadSubscription()
            } catch {
                print("Error ending membership: \(error)")
            }
        }
    }
}

// MARK: - Manage Package View

struct ManagePackageView: View {
    @Binding var currentPlan: String?
    @Binding var showPauseAlert: Bool
    @Binding var showEndMembershipAlert: Bool
    @Binding var showLearnMore: Bool
    let subscription: Subscription?
    
    var body: some View {
        VStack(spacing: 24) {
            // 1. Your membership section
            VStack(alignment: .leading, spacing: 16) {
                Text("Your membership")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Automotive flight package
                    HStack {
                        Image(systemName: "airplane.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        Text("Automotive flight package")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Current plan
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current plan")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let plan = currentPlan {
                                Text(plan)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            } else {
                                Text("No active plan")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Learn more button
                    Button(action: {
                        showLearnMore = true
                    }) {
                        HStack {
                            Text("Learn more")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // 2. Payment details section
            VStack(alignment: .leading, spacing: 16) {
                Text("Payment details")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    // Payment method
                    NavigationLink(destination: PaymentMethodDetailView()) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(.blue)
                                .font(.body)
                            Text("Payment method")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Transactions
                    NavigationLink(destination: TransactionsView()) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundColor(.blue)
                                .font(.body)
                            Text("Transactions")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
            
            // 3. Management Membership section
            VStack(alignment: .leading, spacing: 16) {
                Text("Management Membership")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    // Pause membership
                    Button(action: {
                        showPauseAlert = true
                    }) {
                        HStack {
                            Image(systemName: "pause.circle.fill")
                                .foregroundColor(.orange)
                                .font(.body)
                            Text("Pause membership")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // End membership
                    Button(role: .destructive, action: {
                        showEndMembershipAlert = true
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.body)
                            Text("End membership")
                                .foregroundColor(.red)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}

// MARK: - Payment Method Detail View

struct PaymentMethodDetailView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var paymentService = PaymentService()
    @State private var paymentMethods: [SavedPaymentMethod] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if paymentMethods.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No Payment Method")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Add a payment method to manage your subscription.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(paymentMethods) { method in
                    PaymentMethodRow(paymentMethod: method)
                }
            }
        }
        .navigationTitle("Payment Method")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPaymentMethods()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Failed to load payment methods")
        }
    }
    
    private func loadPaymentMethods() async {
        guard let currentUser = authService.currentUser else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let methods = try await paymentService.fetchSavedPaymentMethods(customerId: currentUser.id)
            await MainActor.run {
                self.paymentMethods = methods
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                self.showError = true
            }
        }
    }
}

// MARK: - Transactions View

struct TransactionsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var transactions: [SubscriptionTransaction] = []
    @State private var isLoading = false
    
    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if transactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No Transactions")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Your subscription transactions will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(transactions) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }
        }
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadTransactions()
        }
    }
    
    private func loadTransactions() async {
        isLoading = true
        // TODO: Implement transaction loading from backend
        // For now, using placeholder data
        await MainActor.run {
            self.transactions = []
            self.isLoading = false
        }
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: SubscriptionTransaction
    
    var body: some View {
        HStack(spacing: 16) {
            // Transaction icon
            Image(systemName: transaction.type == .payment ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.title2)
                .foregroundColor(transaction.type == .payment ? .green : .red)
                .frame(width: 40)
            
            // Transaction details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount
            Text(transaction.amount)
                .font(.headline)
                .foregroundColor(transaction.type == .payment ? .green : .red)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Learn More View

struct LearnMoreView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Automotive Flight Package")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Turn every car into a commercial. With 50 videos per month per drone, your inventory shines like never before. On average, members save over $2,000 per month compared to on-demand shoots.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // What's included section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("What's included")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        // Feature 1
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("⚡")
                                    .font(.title2)
                                Text("Up to 50 cinematic videos per month")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            Text("Full editing and post-production included.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.leading, 32)
                        }
                        
                        // Feature 2
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("🚗")
                                    .font(.title2)
                                Text("Dedicated drone & pilot access")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            Text("One drone team reserved exclusively for your dealership.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.leading, 32)
                        }
                        
                        // Feature 3
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("🎥")
                                    .font(.title2)
                                Text("Priority scheduling")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            Text("Guaranteed next-day shoot availability.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.leading, 32)
                        }
                        
                        // Feature 4
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("💼")
                                    .font(.title2)
                                Text("Dealer-exclusive analytics dashboard")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            Text("Track engagement, turnaround time, and content ROI.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.leading, 32)
                        }
                        
                        // Feature 5
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("🌤️")
                                    .font(.title2)
                                Text("Weather & site-planning support")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            Text("We handle logistics, FAA checks, and filming permits.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.leading, 32)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Learn More")
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

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(text)
                .font(.subheadline)
        }
    }
}

struct PlanRow: View {
    let name: String
    let price: String
    let features: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.headline)
                Spacer()
                Text(price)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            ForEach(features, id: \.self) { feature in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(feature)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Subscription Transaction Model

struct SubscriptionTransaction: Identifiable {
    let id: UUID
    let description: String
    let amount: String
    let date: Date
    let type: TransactionType
    
    enum TransactionType {
        case payment
        case refund
    }
}

// MARK: - Subscription Selection View

struct SubscriptionSelectionView: View {
    @ObservedObject var subscriptionService: SubscriptionService
    @EnvironmentObject var authService: AuthService
    let onSubscriptionCreated: () -> Void
    
    @State private var showPlanSelection = false
    @State private var showMembershipDetails = false
    @State private var hasLoadedPlans = false // Prevent multiple loads
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "car.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Become a Buzz Auto member")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Turn every car into a commercial. With 50 videos per month per drone, your inventory shines like never before. On average, members save over $2,000 per month compared to on-demand shoots.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                // Divider
                Divider()
                    .padding(.horizontal)
                
                // What's included section
                VStack(alignment: .leading, spacing: 20) {
                    Text("What's included:")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 24) {
                        // Feature 1
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.orange)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Up to 50 videos per month per drone")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Full editing and post-production included.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("• 10 30-second high-resolution videos")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("• 10 enticising Facebook or Linkedin posts")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("• 10 creative 3x3 grid for Instagram")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("• 10 informative Instagram stories")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("• 10 Captivating Tiktoks")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Feature 2
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Dedicated drone & pilot access")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("One skilled and talented drone team reserved exclusively for your dealership, dedicating to to capturing quality content.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Feature 3
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.purple)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Priority scheduling")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Guaranteed next-day shoot availability.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Feature 4
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Online traffic boosting")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("90% of vehicle buyers do research online before purchasing.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Feature 5
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "cloud.sun.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.cyan)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Weather & site-planning support")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("We handle logistics, FAA checks, pilot licences, and drone registration permits.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Membership details link
                        Button(action: {
                            showMembershipDetails = true
                        }) {
                            Text("See membership details and terms")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .underline()
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
                
                Spacer()
                
                // Join now button
                Button(action: {
                    showPlanSelection = true
                }) {
                    Text("Join now")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // Load plans when view appears
            print("🛒 SubscriptionSelectionView appeared")
            guard !hasLoadedPlans else {
                print("⏭️ Plans already loaded")
                return
            }
            hasLoadedPlans = true
            Task {
                await loadPlans()
            }
        }
        .sheet(isPresented: $showMembershipDetails) {
            MembershipDetailsView()
        }
        .sheet(isPresented: $showPlanSelection) {
            PlanSelectionView(
                subscriptionService: subscriptionService,
                onSubscriptionCreated: onSubscriptionCreated
            )
        }
    }
    
    private func loadPlans() async {
        // Prevent multiple simultaneous calls
        guard !subscriptionService.isLoading else {
            print("⚠️ Already loading plans, skipping")
            return
        }
        
        // Don't reload if we already have plans
        if !subscriptionService.availablePlans.isEmpty {
            print("ℹ️ Plans already loaded (\(subscriptionService.availablePlans.count) plans)")
            return
        }
        
        print("🔍 Fetching subscription plans...")
        let plans = await subscriptionService.fetchAvailablePlans()
        print("📦 Fetched \(plans.count) plans")
        
        // If we got an error message but no plans, log it
        if plans.isEmpty {
            if let errorMsg = subscriptionService.errorMessage {
                print("❌ Error fetching plans: \(errorMsg)")
            } else {
                print("⚠️ No plans found and no error message")
            }
        } else {
            print("✅ Plans loaded successfully:")
            for (index, plan) in plans.enumerated() {
                print("   \(index + 1). \(plan.name) - \(plan.currency) \(plan.amount / 100)")
            }
        }
    }
}

// MARK: - Plan Selection View

struct PlanSelectionView: View {
    @ObservedObject var subscriptionService: SubscriptionService
    @EnvironmentObject var authService: AuthService
    let onSubscriptionCreated: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPlan: SubscriptionPlan?
    @State private var isProcessingPayment = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Plans
                    if subscriptionService.isLoading && subscriptionService.availablePlans.isEmpty {
                        ProgressView()
                            .padding()
                    } else if subscriptionService.availablePlans.isEmpty {
                        VStack(spacing: 12) {
                            Text("No plans available")
                                .foregroundColor(.secondary)
                            if let error = subscriptionService.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        .padding()
                    } else {
                        VStack(spacing: 16) {
                            ForEach(subscriptionService.availablePlans) { plan in
                                PlanSelectionCard(
                                    plan: plan,
                                    isSelected: selectedPlan?.id == plan.id,
                                    onSelect: {
                                        selectedPlan = plan
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Subscribe button
                    if let plan = selectedPlan {
                        Button(action: {
                            Task {
                                await subscribeToPlan(plan)
                            }
                        }) {
                            HStack {
                                if isProcessingPayment {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(isProcessingPayment ? "Processing..." : "Subscribe to \(plan.name)")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isProcessingPayment)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Choose Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func subscribeToPlan(_ plan: SubscriptionPlan) async {
        guard let currentUser = authService.currentUser else {
            errorMessage = "Please sign in to subscribe"
            showError = true
            return
        }
        
        isProcessingPayment = true
        
        do {
            // Create subscription
            let response = try await subscriptionService.createSubscription(
                customerId: currentUser.id,
                priceId: plan.priceId
            )
            
            // Present payment sheet
            let paymentResult = try await subscriptionService.presentSubscriptionPaymentSheet(
                clientSecret: response.clientSecret,
                customerId: response.customerId,
                customerEphemeralKeySecret: response.ephemeralKeySecret
            )
            
            switch paymentResult {
            case .completed:
                // Payment successful, refresh subscription
                _ = try await subscriptionService.fetchCurrentSubscription(customerId: currentUser.id)
                onSubscriptionCreated()
            case .cancelled:
                // User cancelled, do nothing
                break
            case .failed(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isProcessingPayment = false
    }
}

// MARK: - Membership Details View

struct MembershipDetailsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showSlideshow = false
    
    private let slideshowURL = "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/presentations/car_commercial_pkg.pdf"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Membership Details & Terms")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Learn more about Buzz Auto membership benefits and policies.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    // View Presentation Button
                    Button(action: {
                        showSlideshow = true
                    }) {
                        HStack {
                            Image(systemName: "play.rectangle.fill")
                                .font(.title3)
                            Text("View Membership Presentation")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Terms content
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Terms of Service")
                            .font(.headline)
                        Text("• Subscription terms\n• Cancellation policy\n• Refund policy\n• Usage guidelines")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Details & Terms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSlideshow) {
                if let url = URL(string: slideshowURL), slideshowURL != "YOUR_SUPABASE_STORAGE_URL_HERE" {
                    SafariView(url: url)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Presentation URL Not Configured")
                            .font(.headline)
                        Text("Please upload your presentation to Supabase Storage and update the URL in MembershipDetailsView")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Close") {
                            showSlideshow = false
                        }
                        .padding()
                    }
                }
            }
        }
    }
}

// MARK: - Safari View for displaying web content
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No update needed
    }
}

// MARK: - Plan Selection Card

struct PlanSelectionCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if let description = plan.description {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Price
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(plan.displayPrice)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("/\(plan.displayInterval)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Features
                if let features = plan.features {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(features, id: \.self) { feature in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text(feature)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                
                // Selection indicator
                HStack {
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isSelected ? .blue : .gray)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    FlightPackageView()
        .environmentObject(AuthService())
}

