//
//  ConnectionsView.swift
//  Buzz
//
//  Created for the client referral/loyalty program
//

import SwiftUI
import Auth

struct ConnectionsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var referralService = ReferralService()
    
    @State private var isLoading = true
    @State private var showShareSheet = false
    @State private var showCopiedToast = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var navigateToHistory = false
    
    private var referralLink: String {
        if let code = referralService.referralCode {
            return "Join Buzz using my referral code: \(code) and get started with drone services! Download the app at https://getbuzz.app"
        }
        return ""
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                headerSection
                
                // Credits Section
                creditsSection
                
                // Referral Code Section
                referralCodeSection
                
                // How It Works Section
                howItWorksSection
                
                // Referral History Section
                if let stats = referralService.stats, !stats.referralHistory.isEmpty {
                    referralHistorySection(stats.referralHistory)
                }
            }
            .padding()
        }
        .navigationTitle("Connections")
        .navigationBarTitleDisplayMode(.large)
        .overlay(
            // Copied toast notification
            VStack {
                if showCopiedToast {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text("Code copied!")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(25)
                    .shadow(radius: 5)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .padding(.top, 10)
            .animation(.spring(), value: showCopiedToast)
        )
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [referralLink])
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Invite Friends & Earn")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Share your referral code with friends. When new pilots or customers sign up and verify their ID, you'll earn 1 credit ($25) for each referral to use towards a drone service or in our Buzz shop.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 10)
    }
    
    // MARK: - Credits Section
    
    private var creditsSection: some View {
        VStack(spacing: 16) {
            // Available Credits Card (Clickable)
            NavigationLink(destination: ReferralHistoryView()) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Available Credits")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("$\(formattedCredits)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    
                    VStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green.opacity(0.3))
                        
                        // Chevron indicator to show it's tappable
                        HStack(spacing: 2) {
                            Text("View History")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.green.opacity(0.1))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Stats Row
            if let stats = referralService.stats {
                HStack(spacing: 20) {
                    StatItem(
                        value: "\(stats.totalReferrals)",
                        label: "Total Referrals",
                        icon: "person.badge.plus"
                    )
                    
                    StatItem(
                        value: "\(stats.pendingReferrals)",
                        label: "Pending",
                        icon: "clock"
                    )
                    
                    StatItem(
                        value: "\(stats.completedReferrals)",
                        label: "Verified",
                        icon: "checkmark.seal.fill"
                    )
                }
            }
        }
    }
    
    private var formattedCredits: String {
        if let stats = referralService.stats {
            return String(format: "%.2f", stats.availableCredits)
        }
        return "0.00"
    }
    
    // MARK: - Referral Code Section
    
    private var referralCodeSection: some View {
        VStack(spacing: 16) {
            Text("Your Referral Code")
                .font(.headline)
            
            if isLoading {
                ProgressView()
                    .padding()
            } else if let code = referralService.referralCode {
                // Code Display
                HStack(spacing: 0) {
                    ForEach(Array(code.enumerated()), id: \.offset) { index, char in
                        Text(String(char))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(width: 36, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            )
                    }
                }
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: copyCode) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    
                    Button(action: { showShareSheet = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue)
                        )
                    }
                }
            } else {
                Text("Unable to generate code")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
    }
    
    // MARK: - How It Works Section
    
    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How It Works")
                .font(.headline)
            
            VStack(spacing: 12) {
                HowItWorksStep(
                    number: 1,
                    icon: "square.and.arrow.up",
                    title: "Share Your Code",
                    description: "Send your unique referral code to friends and family"
                )
                
                HowItWorksStep(
                    number: 2,
                    icon: "person.badge.plus",
                    title: "Friend Signs Up",
                    description: "They create a Buzz account using your code"
                )
                
                HowItWorksStep(
                    number: 3,
                    icon: "person.badge.shield.checkmark",
                    title: "ID Verification",
                    description: "They verify their identity with a government ID"
                )
                
                HowItWorksStep(
                    number: 4,
                    icon: "dollarsign.circle.fill",
                    title: "Earn $25 Credit",
                    description: "You receive $25 to use on future bookings!"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Referral History Section
    
    private func referralHistorySection(_ history: [ReferralHistoryItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Referral History")
                .font(.headline)
            
            ForEach(history) { item in
                ReferralHistoryRow(item: item)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
    }
    
    // MARK: - Actions
    
    private func loadData() async {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        
        do {
            // First try to get stats (which includes code if it exists)
            _ = try await referralService.getReferralStats(userId: userId)
            
            // If no code exists yet, generate one
            if referralService.referralCode == nil {
                _ = try await referralService.getOrGenerateReferralCode(userId: userId)
                // Reload stats after generating code
                _ = try await referralService.getReferralStats(userId: userId)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    private func copyCode() {
        guard let code = referralService.referralCode else { return }
        UIPasteboard.general.string = code
        
        showCopiedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedToast = false
        }
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HowItWorksStep: View {
    let number: Int
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Text("\(number)")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct ReferralHistoryRow: View {
    let item: ReferralHistoryItem
    
    private var statusColor: Color {
        switch item.status {
        case .pending: return .orange
        case .completed: return .green
        case .expired: return .gray
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: item.createdAtDate)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.refereeName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: item.status.icon)
                        .font(.caption)
                    Text(item.status.displayName)
                        .font(.caption)
                }
                .foregroundColor(statusColor)
                
                if item.status == .completed {
                    Text("+$\(String(format: "%.0f", item.creditAmount))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 8)
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

