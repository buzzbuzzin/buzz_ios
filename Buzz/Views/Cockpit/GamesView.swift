//
//  GamesView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct GamesView: View {
    @EnvironmentObject var authService: AuthService
    @State private var topPlayers: [GamePlayer] = []
    @State private var isLoading: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                VStack(spacing: 12) {
                    // Games Badge/Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.8), .purple.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: .blue.opacity(0.5), radius: 20)
                        
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }
                    .padding(.top)
                    
                    Text("Games")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Improve Your Flying Skills")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                // Coming Soon Notice
                VStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    Text("Launching March 2026")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("We're working on exciting flight games to help you improve your piloting skills. Stay tuned!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView()
                        .padding(.top, 50)
                } else {
                    // Featured High Score Game (Pinned at Top)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "pin.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text("Featured Game")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal)
                        
                        // Featured Game Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Championship Challenge")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    
                                    Text("Compete for the highest score and earn your place on the leaderboard!")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.yellow)
                            }
                            
                            Divider()
                            
                            // Top 5 Leaderboard
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Top 5 Players")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                if topPlayers.isEmpty {
                                    Text("No scores yet. Be the first to compete!")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 8)
                                } else {
                                    ForEach(Array(topPlayers.enumerated()), id: \.element.id) { index, player in
                                        GameLeaderboardRow(
                                            rank: index + 1,
                                            player: player,
                                            isCurrentUser: player.id == authService.currentUser?.id
                                        )
                                    }
                                }
                            }
                            
                            Button(action: {
                                // TODO: Launch game when available
                            }) {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                    Text("Play Now")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                            .disabled(true)
                            .opacity(0.6)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // Other Flight Games Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Skill Improvement Games")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            GameCard(
                                title: "Precision Landing",
                                description: "Master your landing skills with precision challenges",
                                icon: "target",
                                color: .green
                            )
                            
                            GameCard(
                                title: "Obstacle Course",
                                description: "Navigate through challenging obstacle courses",
                                icon: "figure.run",
                                color: .orange
                            )
                            
                            GameCard(
                                title: "Weather Challenge",
                                description: "Test your skills in various weather conditions",
                                icon: "cloud.rain.fill",
                                color: .cyan
                            )
                            
                            GameCard(
                                title: "Speed Trial",
                                description: "Race against time in speed challenges",
                                icon: "speedometer",
                                color: .red
                            )
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Games")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }
    
    private func loadData() async {
        // TODO: Load top players from backend when game is implemented
        // For now, simulate loading
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Demo data - will be replaced with actual game scores
        topPlayers = []
        
        isLoading = false
    }
}

// MARK: - Game Player Model

struct GamePlayer: Identifiable {
    let id: UUID
    let callsign: String
    let score: Int
}

// MARK: - Game Leaderboard Row

struct GameLeaderboardRow: View {
    let rank: Int
    let player: GamePlayer
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank Badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                if rank <= 3 {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(rankColor)
                        .font(.system(size: 16))
                } else {
                    Text("#\(rank)")
                        .font(.headline)
                        .foregroundColor(rankColor)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(player.callsign)
                        .font(.headline)
                        .foregroundColor(isCurrentUser ? .blue : .primary)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Text("Score: \(player.score)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
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

// MARK: - Game Card

struct GameCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

