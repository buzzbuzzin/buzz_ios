//
//  ReferralHistoryView.swift
//  Buzz
//
//  Created for detailed credit transaction history
//

import SwiftUI
import Supabase

/// Represents a single credit transaction (either earned or used)
struct CreditTransaction: Identifiable {
    let id: UUID
    let type: CreditTransactionType
    let amount: Decimal
    let description: String
    let date: Date
    let status: CreditTransactionStatus
    
    enum CreditTransactionType {
        case earned   // Credits earned from referrals
        case used     // Credits used on bookings
        
        var icon: String {
            switch self {
            case .earned: return "plus.circle.fill"
            case .used: return "minus.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .earned: return .green
            case .used: return .orange
            }
        }
    }
    
    enum CreditTransactionStatus {
        case completed
        case pending
        
        var displayName: String {
            switch self {
            case .completed: return "Completed"
            case .pending: return "Pending"
            }
        }
    }
}

struct ReferralHistoryView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var referralService = ReferralService()
    
    @State private var isLoading = true
    @State private var transactions: [CreditTransaction] = []
    @State private var errorMessage: String?
    @State private var showError = false
    
    private let supabase = SupabaseClient.shared.client
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading history...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if transactions.isEmpty {
                emptyStateView
            } else {
                transactionListView
            }
        }
        .navigationTitle("Credit History")
        .navigationBarTitleDisplayMode(.large)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .task {
            await loadTransactions()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Credit History")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your credit transactions will appear here when you earn or use referral credits.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Transaction List
    
    private var transactionListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Summary Card
                summaryCard
                    .padding()
                
                // Transaction List
                LazyVStack(spacing: 0) {
                    ForEach(transactions) { transaction in
                        CreditTransactionRow(transaction: transaction)
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Balance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("$\(formattedBalance)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.green.opacity(0.3))
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .center, spacing: 2) {
                    Text("+$\(formattedTotalEarned)")
                        .font(.headline)
                        .foregroundColor(.green)
                    Text("Total Earned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                VStack(alignment: .center, spacing: 2) {
                    Text("-$\(formattedTotalUsed)")
                        .font(.headline)
                        .foregroundColor(.orange)
                    Text("Total Used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
    }
    
    // MARK: - Computed Properties
    
    private var formattedBalance: String {
        if let stats = referralService.stats {
            return String(format: "%.2f", stats.availableCredits)
        }
        return "0.00"
    }
    
    private var formattedTotalEarned: String {
        let total = transactions
            .filter { $0.type == .earned && $0.status == .completed }
            .reduce(Decimal(0)) { $0 + $1.amount }
        return String(format: "%.2f", NSDecimalNumber(decimal: total).doubleValue)
    }
    
    private var formattedTotalUsed: String {
        let total = transactions
            .filter { $0.type == .used }
            .reduce(Decimal(0)) { $0 + $1.amount }
        return String(format: "%.2f", NSDecimalNumber(decimal: total).doubleValue)
    }
    
    // MARK: - Data Loading
    
    private func loadTransactions() async {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        
        do {
            // First get referral stats
            _ = try await referralService.getReferralStats(userId: userId)
            
            var allTransactions: [CreditTransaction] = []
            
            // 1. Add transactions from referral history (credits earned)
            if let stats = referralService.stats {
                for item in stats.referralHistory {
                    // Convert string ID to UUID, or generate one if invalid
                    let transactionId = UUID(uuidString: item.id) ?? UUID()
                    let transaction = CreditTransaction(
                        id: transactionId,
                        type: .earned,
                        amount: Decimal(item.creditAmount),
                        description: "Referral: \(item.refereeName)",
                        date: item.createdAtDate,
                        status: item.status == .completed ? .completed : .pending
                    )
                    allTransactions.append(transaction)
                }
            }
            
            // 2. Fetch credits used from bookings
            let bookingsWithCredits = try await fetchBookingsWithCredits(userId: userId)
            allTransactions.append(contentsOf: bookingsWithCredits)
            
            // Sort by date (newest first)
            allTransactions.sort { $0.date > $1.date }
            
            await MainActor.run {
                transactions = allTransactions
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func fetchBookingsWithCredits(userId: UUID) async throws -> [CreditTransaction] {
        struct BookingCreditsInfo: Decodable {
            let id: String
            let credits_applied: Double?
            let created_at: String
            let specialization: String?
        }
        
        let response: [BookingCreditsInfo] = try await supabase
            .from("bookings")
            .select("id, credits_applied, created_at, specialization")
            .eq("customer_id", value: userId.uuidString)
            .gt("credits_applied", value: 0)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Fallback date formatter without fractional seconds
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        
        return response.compactMap { booking in
            guard let credits = booking.credits_applied, credits > 0 else { return nil }
            guard let bookingId = UUID(uuidString: booking.id) else { return nil }
            
            let date = dateFormatter.date(from: booking.created_at) 
                ?? fallbackFormatter.date(from: booking.created_at) 
                ?? Date()
            let specialization = booking.specialization?.capitalized ?? "Booking"
            
            return CreditTransaction(
                id: bookingId,
                type: .used,
                amount: Decimal(credits),
                description: "\(specialization) booking",
                date: date,
                status: .completed
            )
        }
    }
}

// MARK: - Credit Transaction Row

struct CreditTransactionRow: View {
    let transaction: CreditTransaction
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: transaction.date)
    }
    
    private var amountText: String {
        let amount = String(format: "%.2f", NSDecimalNumber(decimal: transaction.amount).doubleValue)
        switch transaction.type {
        case .earned:
            return "+$\(amount)"
        case .used:
            return "-$\(amount)"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(transaction.type.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: transaction.type.icon)
                    .font(.title3)
                    .foregroundColor(transaction.type.color)
            }
            
            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if transaction.status == .pending {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Pending")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Amount
            Text(amountText)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(transaction.type.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

#Preview {
    NavigationView {
        ReferralHistoryView()
    }
}
