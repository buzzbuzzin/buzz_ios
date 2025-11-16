//
//  RacerView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct RacerView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isLoading: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                VStack(spacing: 12) {
                    // Racer Badge/Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.orange.opacity(0.8), .red.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: .orange.opacity(0.5), radius: 20)
                        
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }
                    .padding(.top)
                    
                    Text("Racer")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Drone Racing Championship")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView()
                        .padding(.top, 50)
                } else {
                    // Overview Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About Racer")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            InfoCard(
                                icon: "trophy.fill",
                                title: "Championship Series",
                                description: "Compete in exciting drone racing championships and showcase your piloting skills on the world stage.",
                                color: .yellow
                            )
                            
                            InfoCard(
                                icon: "dollarsign.circle.fill",
                                title: "Pilot Sponsorship",
                                description: "Buzz sponsors talented pilots, investing in our community rather than expensive marketing campaigns.",
                                color: .green
                            )
                            
                            InfoCard(
                                icon: "star.fill",
                                title: "Organic Growth",
                                description: "We believe doing something cool will get us noticed. Join the racing community and help grow the Buzz brand.",
                                color: .blue
                            )
                            
                            InfoCard(
                                icon: "calendar.badge.clock",
                                title: "Future Competitions",
                                description: "We're building the framework for future seasons. Sign up now to be notified when competitions open.",
                                color: .purple
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Sign Up Section
                    VStack(spacing: 16) {
                        VStack(spacing: 12) {
                            Image(systemName: "flag.checkered.2.crossed")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            
                            Text("Ready to Race?")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Sign up to be notified when racing competitions open. Showcase your skills and compete for sponsorship opportunities.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button(action: {
                                // TODO: Implement sign up functionality
                            }) {
                                HStack {
                                    Image(systemName: "bell.fill")
                                    Text("Notify Me When Competitions Open")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Racer")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }
    
    private func loadData() async {
        // Simulate loading
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        isLoading = false
    }
}

// MARK: - Info Card

struct InfoCard: View {
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

