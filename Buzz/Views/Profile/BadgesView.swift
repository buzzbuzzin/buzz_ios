//
//  BadgesView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

enum BadgeCategory: String, Hashable {
    case academy = "Academy"
    case affiliations = "Affiliations"
    case permits = "Permits"
}

struct BadgesView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var badgeService = BadgeService()
    @StateObject private var demoModeManager = DemoModeManager.shared
    @State private var selectedCategory: BadgeCategory? = nil
    
    var filteredBadges: [Badge] {
        guard let category = selectedCategory else {
            return badgeService.badges
        }
        
        switch category {
        case .academy:
            // Academy badges are course-based badges
            return badgeService.badges.filter { $0.badgeType == .course || $0.badgeType == nil }
        case .affiliations:
            // Affiliations badges are criteria-based badges (excluding permits)
            return badgeService.badges.filter { 
                if let badgeType = $0.badgeType {
                    return badgeType != .course && badgeType != .flightReviewer && badgeType != .rocaExaminer
                }
                return false
            }
        case .permits:
            // Permits badges
            return badgeService.badges.filter {
                $0.badgeType == .flightReviewer || $0.badgeType == .rocaExaminer
            }
        }
    }
    
    var filteredAvailableBadges: [AvailableBadge] {
        guard let category = selectedCategory else {
            return badgeService.availableBadges
        }
        
        switch category {
        case .academy:
            // Academy badges are course-based badges
            return badgeService.availableBadges.filter { $0.badgeType == .course || $0.badgeType == nil }
        case .affiliations:
            // Affiliations badges are criteria-based badges (excluding permits)
            return badgeService.availableBadges.filter { 
                if let badgeType = $0.badgeType {
                    return badgeType != .course && badgeType != .flightReviewer && badgeType != .rocaExaminer
                }
                return false
            }
        case .permits:
            // Permits badges
            return badgeService.availableBadges.filter {
                $0.badgeType == .flightReviewer || $0.badgeType == .rocaExaminer
            }
        }
    }
    
    var body: some View {
        ZStack {
        List {
                // Demo Mode Indicator
                if demoModeManager.isDemoModeEnabled {
                    Section {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Demo Mode: Showing sample badges")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
            // Filter by Category
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryFilterChip(
                            title: "All",
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                        }
                        
                        CategoryFilterChip(
                            title: BadgeCategory.academy.rawValue,
                            isSelected: selectedCategory == .academy,
                            color: .blue
                        ) {
                            selectedCategory = .academy
                        }
                        
                        CategoryFilterChip(
                            title: BadgeCategory.affiliations.rawValue,
                            isSelected: selectedCategory == .affiliations,
                            color: .purple
                        ) {
                            selectedCategory = .affiliations
                        }
                        
                        CategoryFilterChip(
                            title: BadgeCategory.permits.rawValue,
                            isSelected: selectedCategory == .permits,
                            color: .teal
                        ) {
                            selectedCategory = .permits
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // My Badges Section (All earned badges)
            Section {
                if filteredBadges.isEmpty {
                    Text("No badges earned yet")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(filteredBadges) { badge in
                        BadgeRow(badge: badge)
                    }
                }
            } header: {
                Text("My Badges")
            }
            
            // All Badges Section (Available badges that can be earned)
            Section {
                if filteredAvailableBadges.isEmpty {
                    Text("No additional badges available")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(filteredAvailableBadges) { availableBadge in
                        AvailableBadgeRow(
                            availableBadge: availableBadge,
                            authService: authService,
                            badgeService: badgeService
                        )
                    }
                }
            } header: {
                Text("All Badges")
            }
            
            // Empty State
            if filteredBadges.isEmpty && filteredAvailableBadges.isEmpty && !badgeService.isLoading {
                Section {
                    EmptyStateView(
                        icon: "seal.fill",
                        title: "No Badges Yet",
                        message: "Complete training courses or meet criteria to earn badges"
                    )
                }
            }
                
                // Error Message
                if let errorMessage = badgeService.errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Loading Overlay
            if badgeService.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
        .navigationTitle("Badges")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadBadges()
        }
        .onChange(of: demoModeManager.isDemoModeEnabled) { oldValue, newValue in
            Task {
                await loadBadges()
            }
        }
    }
    
    private func loadBadges() async {
            guard let currentUser = authService.currentUser else { return }
            async let badgesTask = badgeService.fetchPilotBadges(pilotId: currentUser.id)
            async let availableBadgesTask = badgeService.fetchAvailableBadges(pilotId: currentUser.id)
            
            try? await badgesTask
            try? await availableBadgesTask
    }
}

// MARK: - Badge Row

struct BadgeRow: View {
    let badge: Badge
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                // Badge Icon
                ZStack {
                    let badgeColor = badge.badgeType?.color ?? badge.provider.color
                    let badgeIcon = badge.badgeType?.icon ?? badge.provider.icon
                    let imageAssetName = badge.badgeType?.imageAssetName
                    
                    Circle()
                        .fill(badgeColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    if let imageAssetName = imageAssetName {
                        Image(imageAssetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: badgeIcon)
                            .font(.system(size: 30))
                            .foregroundColor(badgeColor)
                    }
                    
                    // Expiration indicator overlay
                    if badge.isExpired {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 20, y: -20)
                    } else if badge.isExpiringSoon {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "exclamationmark")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 20, y: -20)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(badge.displayTitle)
                        .font(.headline)
                        .lineLimit(2)
                    
                    HStack(spacing: 4) {
                        let providerText: String = {
                            if badge.badgeType == .course || badge.badgeType == nil {
                                return "Academy"
                            } else if badge.badgeType == .flightReviewer || badge.badgeType == .rocaExaminer {
                                return "Permits"
                            } else {
                                return "Affiliations"
                            }
                        }()
                        
                        Text(providerText)
                            .font(.caption)
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(4)
                        
                        if badge.isRecurrent {
                            Text("Recurrent")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("Earned \(badge.earnedAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: badge.isExpired ? "xmark.seal.fill" : "checkmark.seal.fill")
                    .foregroundColor(badge.isExpired ? .red : .blue)
                    .font(.system(size: 24))
            }
            .padding(.vertical, 4)
            
            // Expiration Warning Banner
            if badge.isExpiringSoon || badge.isExpired {
                HStack(spacing: 8) {
                    Image(systemName: badge.isExpired ? "exclamationmark.triangle.fill" : "clock.fill")
                        .foregroundColor(badge.isExpired ? .red : .orange)
                        .font(.caption)
                    
                    if badge.isExpired {
                        Text("This badge has expired. Complete the recurrent training course to renew it.")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if let daysLeft = badge.daysUntilExpiration {
                        Text("⚠️ This badge will expire in \(daysLeft) day\(daysLeft == 1 ? "" : "s"). Complete the recurrent training course to renew it.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background((badge.isExpired ? Color.red : Color.orange).opacity(0.1))
                .cornerRadius(8)
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Available Badge Row

struct AvailableBadgeRow: View {
    let availableBadge: AvailableBadge
    let authService: AuthService
    let badgeService: BadgeService
    
    @StateObject private var profileService = ProfileService()
    @State private var showVeteranVerificationSheet = false
    
    var isExMilitaryBadge: Bool {
        availableBadge.badgeType == .exMilitary
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                // Badge Icon (grayed out to indicate not earned)
                ZStack {
                    Circle()
                        .fill(availableBadge.providerColor.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    if let imageAssetName = availableBadge.imageAssetName {
                        Image(imageAssetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .opacity(0.5)
                    } else {
                        Image(systemName: availableBadge.providerIcon)
                            .font(.system(size: 30))
                            .foregroundColor(availableBadge.providerColor.opacity(0.5))
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(availableBadge.courseTitle)
                        .font(.headline)
                        .lineLimit(2)
                    
                    HStack(spacing: 4) {
                        let providerText: String = {
                            if availableBadge.badgeType == .course || availableBadge.badgeType == nil {
                                return "Academy"
                            } else if availableBadge.badgeType == .flightReviewer || availableBadge.badgeType == .rocaExaminer {
                                return "Permits"
                            } else {
                                return "Affiliations"
                            }
                        }()
                        
                        Text(providerText)
                            .font(.caption)
                            .foregroundColor(.black.opacity(0.5))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(4)
                        
                        if availableBadge.isRecurrent {
                            Text("Recurrent")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "seal")
                    .foregroundColor(availableBadge.providerColor.opacity(0.3))
                    .font(.system(size: 24))
            }
            .padding(.vertical, 4)
        }
        .padding(.vertical, 4)
        .opacity(0.7) // Slightly faded to indicate not earned
        .contentShape(Rectangle()) // Make entire area tappable
        .onTapGesture {
            if isExMilitaryBadge {
                showVeteranVerificationSheet = true
            }
        }
        .sheet(isPresented: $showVeteranVerificationSheet) {
            if let currentUser = authService.currentUser {
                VeteranVerificationView(
                    profileService: profileService,
                    badgeService: badgeService,
                    userId: currentUser.id
                )
            }
        }
    }
}

// MARK: - Category Filter Chip

struct CategoryFilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? color : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

