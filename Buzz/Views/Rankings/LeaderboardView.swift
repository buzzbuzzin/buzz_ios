//
//  LeaderboardView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI

struct LeaderboardView: View {
    @StateObject private var rankingService = RankingService()
    
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
                    ForEach(Array(rankingService.leaderboard.enumerated()), id: \.element.id) { index, stats in
                        LeaderboardRow(rank: index + 1, stats: stats)
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
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(stats.tierName)
                        .font(.headline)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                        Text("Tier \(stats.tier)")
                            .font(.subheadline)
                    }
                    .foregroundColor(tierColor)
                }
                
                HStack {
                    Label(
                        String(format: "%.1f hrs", stats.totalFlightHours),
                        systemImage: "clock.fill"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Label(
                        "\(stats.completedBookings) flights",
                        systemImage: "airplane.departure"
                    )
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
    
    private var tierColor: Color {
        switch stats.tier {
        case 0: return .gray
        case 1: return .brown
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .mint
        case 6: return .cyan
        case 7: return .blue
        case 8: return .indigo
        case 9: return .purple
        case 10: return .pink
        default: return .gray
        }
    }
}

