//
//  LeaderboardView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI

struct LeaderboardView: View {
    @StateObject private var rankingService = RankingService()
    @State private var showTierInfo = false
    
    var body: some View {
        VStack {
            if rankingService.isLoading {
                LoadingView(message: "Loading leaderboard...")
            } else if rankingService.leaderboard.isEmpty {
                EmptyStateView(
                    icon: "chart.bar",
                    title: "No Rankings Yet",
                    message: "Be the first pilot to complete a booking and appear on the leaderboard!"
                )
            } else {
                List {
                    // Tier Information Section
                    Section {
                        Button(action: {
                            withAnimation {
                                showTierInfo.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Ranking System")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: showTierInfo ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if showTierInfo {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(0..<5) { tier in
                                    TierInfoRow(tier: tier)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    // Leaderboard Section
                    Section {
                        ForEach(Array(rankingService.leaderboard.enumerated()), id: \.element.id) { index, stats in
                            NavigationLink(destination: PublicProfileView(pilotId: stats.pilotId)) {
                                LeaderboardRow(rank: index + 1, stats: stats)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .refreshable {
                    await loadLeaderboard()
                }
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadLeaderboard()
        }
    }
    
    private func loadLeaderboard() async {
        try? await rankingService.fetchLeaderboard()
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let rank: Int
    let stats: PilotStats
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank Badge
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 40, height: 40)
                
                Text("#\(rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Stats
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stats.tierName)
                        .font(.headline)
                    
                    if let callsign = stats.callsign, !callsign.isEmpty {
                        Text("@\(callsign)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Flight hours and flights on the right
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text(String(format: "%.0f hours", stats.totalFlightHours))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    Text("\(stats.completedBookings) flights")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
}

// MARK: - Tier Info Row

struct TierInfoRow: View {
    let tier: Int
    
    private var tierInfo: (name: String, hours: String, color: Color) {
        switch tier {
        case 0:
            return ("Ensign", "0 - 24.9 hrs", .gray)
        case 1:
            return ("Sub Lieutenant", "25 - 74.9 hrs", .blue)
        case 2:
            return ("Lieutenant", "75 - 199.9 hrs", .green)
        case 3:
            return ("Commander", "200 - 499.9 hrs", .orange)
        case 4:
            return ("Captain", "500+ hrs", .purple)
        default:
            return ("Unknown", "", .gray)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Tier Badge
            ZStack {
                Circle()
                    .fill(tierInfo.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text("\(tier)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(tierInfo.color)
            }
            
            // Tier Name
            VStack(alignment: .leading, spacing: 4) {
                Text(tierInfo.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(tierInfo.hours)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

