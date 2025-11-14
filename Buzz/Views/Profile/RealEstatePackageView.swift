//
//  RealEstatePackageView.swift
//  Buzz
//
//  Created for displaying customer subscription information for Real Estate
//

import SwiftUI
import Auth
import Foundation

struct RealEstatePackageView: View {
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
                        HStack(spacing: 0) {
                            ForEach(PackageTab.allCases, id: \.self) { tab in
                                Button(action: {
                                    selectedTab = tab
                                }) {
                                    Text(tab.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                                        .foregroundColor(selectedTab == tab ? .blue : .secondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                                        .cornerRadius(8)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        
                        // Content based on selected tab
                        ScrollView {
                            VStack(spacing: 24) {
                                switch selectedTab {
                                case .managePackage:
                                    ManageRealEstatePackageView(
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
                    RealEstateSubscriptionSelectionView(
                        subscriptionService: subscriptionService,
                        onSubscriptionCreated: {
                            Task {
                                await loadSubscription()
                            }
                        }
                    )
                }
            }
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
                RealEstateLearnMoreView()
            }
        }
        .onAppear {
            // Use onAppear instead of .task to prevent retriggering on state changes
            print("📱 Real Estate View appeared, hasLoadedOnce=\(hasLoadedOnce)")
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
            print("👋 Real Estate View disappearing, canceling tasks")
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

// MARK: - Manage Real Estate Package View

struct ManageRealEstatePackageView: View {
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
                    // Real Estate flight package
                    HStack {
                        Image(systemName: "airplane.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        Text("Real Estate flight package")
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

// MARK: - Real Estate Learn More View

struct RealEstateLearnMoreView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Real Estate Flight Package")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Showcase properties from stunning aerial perspectives. With 50 videos per month per drone, your listings stand out like never before. On average, members save over $2,000 per month compared to on-demand shoots.")
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
                                Text("🏠")
                                    .font(.title2)
                                Text("Dedicated drone & pilot access")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            Text("One drone team reserved exclusively for your real estate business.")
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
                                Text("Agent-exclusive analytics dashboard")
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

// MARK: - Real Estate Subscription Selection View

struct RealEstateSubscriptionSelectionView: View {
    @ObservedObject var subscriptionService: SubscriptionService
    @EnvironmentObject var authService: AuthService
    let onSubscriptionCreated: () -> Void
    
    @State private var showPlanSelection = false
    @State private var showMembershipDetails = false
    @State private var hasLoadedPlans = false // Prevent multiple loads
    
    // Real Estate product ID from Stripe
    private let realEstateProductId = "prod_TPbEVKDoBBsN08"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "house.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Buy a Buzz Real Estate Bundle")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("At Buzz, our pilots have a passion for creating inspiring content. Our advanced licensed drone pilots and camera operators are dedicated to capturing quality content for your real estate business. We film local—we're a global brand working locally on the ground to create an immersive video experience that showcases your properties and facilities.")
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
                    Text("$1,500 Business Video Bundle for Real Estate")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    Text("Video content is essential for attracting customers online. Your potential buyers are ready and eager to explore your properties through engaging video content. Post your videos online to reach more people and showcase your listings in the best light.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // Divider
                    Divider()
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    
                    // What's included header
                    Text("What's included:")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 24) {
                        // Feature 1
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.orange)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Product Placement & Close-Ups")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Professional close-up shots that highlight the unique features and details of your properties, showcasing every detail that makes your listings special.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Feature 2
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Steadicam Interior Footage")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Smooth, cinematic interior tours that give potential buyers an immersive experience of the property's layout and flow.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Feature 3
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.purple)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Exterior & Building Footage")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Stunning exterior shots that capture the property's curb appeal, architecture, and surrounding environment from ground level.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Feature 4
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "airplane")
                                .font(.system(size: 24))
                                .foregroundColor(.cyan)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Drone Aerial Footage")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Breathtaking aerial perspectives of your business and neighborhood. Available only for applicable businesses, these shots provide a unique bird's-eye view that sets your listings apart.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Feature 5 - Why Buzz
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.red)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Passionate Professionals, Local Focus")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("At Buzz, our pilots have a passion for creating inspiring content. We're a global brand working locally on the ground—whether you own a local coffee shop, boutique, or bakery, Buzz has got you covered. We create an immersive video experience to showcase your products and facility.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Bundle details link
                        Button(action: {
                            showMembershipDetails = true
                        }) {
                            Text("See bundle details and terms")
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
            print("🛒 RealEstateSubscriptionSelectionView appeared")
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
            RealEstateMembershipDetailsView()
        }
        .sheet(isPresented: $showPlanSelection) {
            PlanSelectionView(
                subscriptionService: subscriptionService,
                onSubscriptionCreated: onSubscriptionCreated,
                productId: realEstateProductId
            )
        }
    }
    
    private func loadPlans() async {
        // Prevent multiple simultaneous calls
        guard !subscriptionService.isLoading else {
            print("⚠️ Already loading plans, skipping")
            return
        }
        
        // Clear existing plans first to ensure we get Real Estate plans
        await MainActor.run {
            subscriptionService.availablePlans = []
        }
        
        print("🔍 Fetching subscription plans for Real Estate product: \(realEstateProductId)")
        let plans = await subscriptionService.fetchAvailablePlans(productId: realEstateProductId)
        print("📦 Fetched \(plans.count) plans for Real Estate")
        
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

// MARK: - Real Estate Membership Details View

struct RealEstateMembershipDetailsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showSlideshow = false
    
    private let slideshowURL = "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/presentations/real_estate_pkg.pdf"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Bundle Details & Terms")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Learn more about Buzz Real Estate bundle benefits and policies.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    // View Presentation Button
                    Button(action: {
                        showSlideshow = true
                    }) {
                        HStack {
                            Image(systemName: "play.rectangle.fill")
                                .font(.title3)
                            Text("View Bundle Presentation")
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
            .navigationTitle("Bundle Details & Terms")
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
                        Text("Please upload your presentation to Supabase Storage and update the URL in RealEstateMembershipDetailsView")
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

#Preview {
    RealEstatePackageView()
        .environmentObject(AuthService())
}

