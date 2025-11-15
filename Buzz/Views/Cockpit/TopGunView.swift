//
//  TopGunView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct TopGunView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var rankingService = RankingService()
    @StateObject private var topGunService = TopGunService()
    @State private var userStats: PilotStats?
    @State private var isLoading: Bool = true
    @State private var isTopGunMember: Bool = false
    @State private var showRequirementsDetail = false
    @State private var showBenefitsDetail = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                VStack(spacing: 12) {
                    // TopGun Badge/Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.red.opacity(0.8), .orange.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: .red.opacity(0.5), radius: 20)
                        
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }
                    .padding(.top)
                    
                    Text("TopGun")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Elite Drone Pilot Club")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if isTopGunMember {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("TopGun Member")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView()
                        .padding(.top, 50)
                } else {
                    // Selected TopGun Pilots Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Selected TopGun Pilots")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                            Text("\(topGunService.topGunPilots.count)")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        if topGunService.topGunPilots.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                Text("No pilots selected yet")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("Top performers will be selected through the championship rounds")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(Array(topGunService.topGunPilots.enumerated()), id: \.element.id) { index, pilot in
                                    TopGunPilotCard(
                                        rank: index + 1,
                                        pilot: pilot,
                                        isCurrentUser: pilot.id == authService.currentUser?.id
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // User Eligibility Status
                    if let stats = userStats {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Your Eligibility Status")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                EligibilityMetricRow(
                                    icon: "airplane.departure",
                                    title: "Current Rank",
                                    value: stats.tierName,
                                    isMet: stats.tier == 4,
                                    requirement: "Captain (500+ hours)"
                                )
                                
                                EligibilityMetricRow(
                                    icon: "clock.fill",
                                    title: "Flight Hours",
                                    value: String(format: "%.1f hours", stats.totalFlightHours),
                                    isMet: stats.totalFlightHours >= 500,
                                    requirement: "500+ hours"
                                )
                                
                                EligibilityMetricRow(
                                    icon: "checkmark.circle.fill",
                                    title: "Completed Flights",
                                    value: "\(stats.completedBookings)",
                                    isMet: true,
                                    requirement: "Tracked"
                                )
                                
                                EligibilityMetricRow(
                                    icon: "trophy.fill",
                                    title: "Championship Status",
                                    value: isTopGunMember ? "Selected" : "Not Selected",
                                    isMet: isTopGunMember,
                                    requirement: "Top 3 in Final Round"
                                )
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Requirements and Benefits Cards Row
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Learn More")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            // Requirements Card
                            Button(action: {
                                showRequirementsDetail = true
                            }) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Image(systemName: "list.bullet.rectangle")
                                        .font(.system(size: 32))
                                        .foregroundColor(.purple)
                                    
                                    Text("Requirements")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("View requirements to join TopGun")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer(minLength: 0)
                                    
                                    HStack {
                                        Text("View Details")
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(16)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Benefits Card
                            Button(action: {
                                showBenefitsDetail = true
                            }) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.yellow)
                                    
                                    Text("Benefits")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("View benefits of TopGun membership")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer(minLength: 0)
                                    
                                    HStack {
                                        Text("View Details")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(16)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("TopGun")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRequirementsDetail) {
            RequirementsDetailView()
        }
        .sheet(isPresented: $showBenefitsDetail) {
            BenefitsDetailView()
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }
    
    private func loadData() async {
        guard let currentUser = authService.currentUser else {
            isLoading = false
            return
        }
        
        // Load pilot stats
        try? await rankingService.getPilotStats(pilotId: currentUser.id)
        userStats = rankingService.pilotStats
        
        // Load TopGun pilots from backend
        try? await topGunService.fetchTopGunPilots()
        
        // Check if current user is a TopGun member
        if let userId = authService.currentUser?.id {
            isTopGunMember = await topGunService.isTopGunMember(pilotId: userId)
        }
        
        isLoading = false
    }
}

// MARK: - TopGun Pilot Model

struct TopGunPilot: Identifiable {
    let id: UUID
    let callsign: String
    let flightHours: Double
    let completedFlights: Int
    let rank: String
    let championshipScore: Int
}

// MARK: - TopGun Pilot Card

struct TopGunPilotCard: View {
    let rank: Int
    let pilot: TopGunPilot
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank Badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                if rank <= 3 {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(rankColor)
                        .font(.system(size: 24))
                } else {
                    Text("#\(rank)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(rankColor)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(pilot.callsign)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(isCurrentUser ? .blue : .primary)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                HStack(spacing: 16) {
                    Label("\(String(format: "%.1f", pilot.flightHours)) hrs", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(pilot.completedFlights) flights", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("Championship Score: \(pilot.championshipScore)")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            // TopGun Badge
            Image(systemName: "airplane.circle.fill")
                .font(.title2)
                .foregroundColor(.red)
        }
        .padding()
        .background(isCurrentUser ? Color.blue.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrentUser ? Color.blue.opacity(0.3) : Color(.separator).opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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

// MARK: - Requirement Card

struct RequirementCard: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.headline)
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Eligibility Metric Row

struct EligibilityMetricRow: View {
    let icon: String
    let title: String
    let value: String
    let isMet: Bool
    let requirement: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isMet ? .green : .orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(value)
                        .font(.headline)
                        .foregroundColor(isMet ? .green : .primary)
                    
                    Text("• \(requirement)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: isMet ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isMet ? .green : .orange)
        }
    }
}

// MARK: - Requirements Detail View

struct RequirementsDetailView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Requirements to Join TopGun")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    VStack(spacing: 12) {
                        RequirementDetailCard(
                            icon: "envelope.badge.fill",
                            title: "Invitation Only",
                            color: .purple
                        )
                        
                        RequirementDetailCard(
                            icon: "star.fill",
                            title: "Captain Rank Required",
                            color: .orange
                        )
                        
                        RequirementDetailCard(
                            icon: "chart.bar.fill",
                            title: "Comprehensive Evaluation",
                            color: .blue
                        )
                        
                        RequirementDetailCard(
                            icon: "gamecontroller.fill",
                            title: "Championship Performance",
                            color: .red
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Requirements")
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

// MARK: - Requirements Detail Card

struct RequirementDetailCard: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.headline)
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Benefits Detail View

struct BenefitsDetailView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Benefits of TopGun Membership")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        BenefitDetailCard(
                            icon: "dollarsign.circle.fill",
                            title: "Elite Compensation",
                            description: "Guaranteed minimum $100/hour for all TopGun assignments and events.",
                            color: .green
                        )
                        
                        BenefitDetailCard(
                            icon: "trophy.fill",
                            title: "Buzz Team Selection",
                            description: "Top 3 pilots are selected to compete for Buzz and receive full sponsorship support.",
                            color: .yellow
                        )
                        
                        BenefitDetailCard(
                            icon: "globe.americas.fill",
                            title: "High-Profile Events",
                            description: "Exclusive access to prestigious events like World Cup, Olympics, and major competitions.",
                            color: .blue
                        )
                        
                        BenefitDetailCard(
                            icon: "star.fill",
                            title: "Elite Status",
                            description: "Join the elite of the drone world - recognized as the top performers in the industry.",
                            color: .purple
                        )
                        
                        BenefitDetailCard(
                            icon: "airplane.circle.fill",
                            title: "Racing Opportunities",
                            description: "Compete in professional drone racing circuits representing Buzz on the world stage.",
                            color: .red
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Benefits")
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

// MARK: - Benefit Detail Card

struct BenefitDetailCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

