//
//  BadgesView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct BadgesView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var badgeService = BadgeService()
    @State private var selectedProvider: Badge.CourseProvider? = nil
    
    private let allProviders: [Badge.CourseProvider] = [.buzz, .amazon, .tmobile, .other]
    
    var filteredBadges: [Badge] {
        if let provider = selectedProvider {
            return badgeService.badges.filter { $0.provider == provider }
        }
        return badgeService.badges
    }
    
    var buzzBadges: [Badge] {
        badgeService.badges.filter { $0.provider == .buzz }
    }
    
    var companyBadges: [Badge] {
        badgeService.badges.filter { $0.provider != .buzz }
    }
    
    var body: some View {
        List {
            // Filter by Provider
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ProviderFilterChip(
                            title: "All",
                            isSelected: selectedProvider == nil
                        ) {
                            selectedProvider = nil
                        }
                        
                        ForEach(allProviders, id: \.self) { provider in
                            ProviderFilterChip(
                                title: provider.rawValue,
                                isSelected: selectedProvider == provider,
                                color: provider.color
                            ) {
                                selectedProvider = provider
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Buzz Badges Section
            if selectedProvider == nil || selectedProvider == .buzz {
                Section {
                    if buzzBadges.isEmpty {
                        Text("No Buzz course badges yet")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(buzzBadges) { badge in
                            BadgeRow(badge: badge)
                        }
                    }
                } header: {
                    Text("Buzz Courses")
                }
            }
            
            // Company Badges Section
            if selectedProvider == nil || (selectedProvider != nil && selectedProvider != .buzz) {
                Section {
                    if companyBadges.isEmpty {
                        Text("No company course badges yet")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(companyBadges) { badge in
                            BadgeRow(badge: badge)
                        }
                    }
                } header: {
                    Text("Company Courses")
                }
            }
            
            // Empty State
            if filteredBadges.isEmpty {
                Section {
                    EmptyStateView(
                        icon: "seal.fill",
                        title: "No Badges Yet",
                        message: "Complete training courses to earn badges"
                    )
                }
            }
        }
        .navigationTitle("Badges")
        .navigationBarTitleDisplayMode(.large)
        .task {
            guard let currentUser = authService.currentUser else { return }
            try? await badgeService.fetchPilotBadges(pilotId: currentUser.id)
        }
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
                    Circle()
                        .fill(badge.provider.color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: badge.provider.icon)
                        .font(.system(size: 30))
                        .foregroundColor(badge.provider.color)
                    
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
                    Text(badge.courseTitle)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(badge.courseCategory)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: badge.provider.icon)
                            .font(.caption)
                            .foregroundColor(badge.provider.color)
                        Text(badge.provider.rawValue)
                            .font(.caption)
                            .foregroundColor(badge.provider.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(badge.provider.color.opacity(0.1))
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
                    .foregroundColor(badge.isExpired ? .red : badge.provider.color)
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

// MARK: - Provider Filter Chip

struct ProviderFilterChip: View {
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

