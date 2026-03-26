//
//  BalanceView.swift
//  Buzz
//
//  Created for pilot balance tracking
//

import SwiftUI
import Auth
import Supabase

struct BalanceView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    @StateObject private var stripeConnectService = StripeConnectService()
    @State private var balance: Decimal = 0
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showWithdrawAlert = false
    @State private var showWithdrawSuccess = false
    @State private var showZeroBalanceWarning = false
    @State private var isWithdrawing = false
    
    // Crew earnings (for automotive bookings)
    @State private var crewMemberships: [BookingCrewMember] = []
    
    // Month selector for summary
    @State private var selectedMonth: Date = Date()
    
    // Available months for selection (last 12 months)
    private var availableMonths: [Date] {
        let calendar = Calendar.current
        var months: [Date] = []
        for i in 0..<12 {
            if let month = calendar.date(byAdding: .month, value: -i, to: Date()) {
                months.append(calendar.startOfMonth(for: month))
            }
        }
        return months
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Balance Card Section
            VStack(spacing: 20) {
                Text("Current Balance")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(String(format: "$%.2f", NSDecimalNumber(decimal: balance).doubleValue))
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.green)
                
                Text("Available to withdraw")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Withdraw Button - Prominently placed
                CustomButton(
                    title: "Withdraw",
                    action: {
                        if balance <= 0 {
                            showZeroBalanceWarning = true
                        } else {
                            showWithdrawAlert = true
                        }
                    },
                    style: .primary,
                    isLoading: isWithdrawing,
                    isDisabled: isWithdrawing
                )
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(Color(.systemGroupedBackground))
            
            // List Section for Earnings
            List {
            // Automotive Crew Earnings (fixed payout based on rank)
            if !crewMemberships.isEmpty {
                Section("Automotive Crew Earnings") {
                    let postedCrewJobs = crewMemberships.filter { $0.isPosted }
                    let pendingCrewJobs = crewMemberships.filter { !$0.isPosted }
                    
                    if !postedCrewJobs.isEmpty {
                        ForEach(postedCrewJobs.prefix(5)) { membership in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "car.fill")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                        Text("Automotive Job")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Text(membership.rankName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if membership.role == .lead {
                                            Text("• Lead")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    
                                    Text(membership.joinedAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(String(format: "$%.0f", NSDecimalNumber(decimal: membership.payoutAmount).doubleValue))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                    
                                    Label("Posted", systemImage: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // Show pending crew jobs
                    if !pendingCrewJobs.isEmpty {
                        ForEach(pendingCrewJobs.prefix(3)) { membership in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "car.fill")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                        Text("Automotive Job")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    
                                    Text(membership.rankName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(String(format: "$%.0f", NSDecimalNumber(decimal: membership.payoutAmount).doubleValue))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.orange)
                                    
                                    Label("Pending", systemImage: "clock.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    if postedCrewJobs.isEmpty && pendingCrewJobs.isEmpty {
                        Text("No automotive crew earnings yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
                
            // Recent Earnings (non-automotive bookings)
            Section("Other Earnings") {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                } else {
                    // Show completed bookings with earnings (excluding automotive)
                    let completedBookings = bookingService.myBookings.filter { 
                        $0.status == .completed && $0.specialization != .automotive 
                    }
                    
                    if completedBookings.isEmpty {
                        Text("No other earnings yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(completedBookings.prefix(10)) { booking in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        if let spec = booking.specialization {
                                            Image(systemName: spec.icon)
                                                .foregroundColor(.purple)
                                                .font(.caption)
                                        }
                                        Text(booking.locationName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                    }
                                    
                                    Text(booking.createdAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(String(format: "$%.2f", NSDecimalNumber(decimal: booking.settledBasePayoutAmount).doubleValue))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                    
                                    if booking.settledTipAmount > 0, let tip = booking.tipAmount {
                                        Text(String(format: "+$%.2f tip", NSDecimalNumber(decimal: tip).doubleValue))
                                            .font(.caption)
                                            .foregroundColor(.pink)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            
            // Monthly Earnings Summary
            Section {
                // Month selector
                HStack {
                    Button(action: { goToPreviousMonth() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                            .padding(8)
                    }
                    .disabled(!canGoToPreviousMonth)
                    
                    Spacer()
                    
                    Text(monthYearString(for: selectedMonth))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: { goToNextMonth() }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(canGoToNextMonth ? .blue : .gray)
                            .padding(8)
                    }
                    .disabled(!canGoToNextMonth)
                }
                .padding(.vertical, 4)
                
                // Calculate earnings for selected month
                let monthlyAutomotiveEarnings = crewMemberships
                    .filter { isInSelectedMonth($0.joinedAt) && $0.isPosted }
                    .reduce(Decimal(0)) { total, membership in
                        total + membership.payoutAmount
                    }
                
                let monthlyOtherEarnings = bookingService.myBookings
                    .filter { $0.status == .completed && $0.specialization != .automotive && isInSelectedMonth($0.completedAt ?? $0.createdAt) }
                    .reduce(Decimal(0)) { total, booking in
                        total + booking.settledBasePayoutAmount + booking.settledTipAmount
                    }
                
                let monthlyTotalEarnings = monthlyAutomotiveEarnings + monthlyOtherEarnings
                
                // Monthly total
                HStack {
                    Text("Total Earnings")
                        .font(.title3)
                        .fontWeight(.bold)
                    Spacer()
                    Text(String(format: "$%.2f", NSDecimalNumber(decimal: monthlyTotalEarnings).doubleValue))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 8)
                
                // Breakdown
                if monthlyAutomotiveEarnings > 0 || monthlyOtherEarnings > 0 {
                    Divider()
                    
                    if monthlyAutomotiveEarnings > 0 {
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "car.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("Automotive")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(String(format: "$%.0f", NSDecimalNumber(decimal: monthlyAutomotiveEarnings).doubleValue))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if monthlyOtherEarnings > 0 {
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "briefcase.fill")
                                    .foregroundColor(.purple)
                                    .font(.caption)
                                Text("Other Jobs")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(String(format: "$%.2f", NSDecimalNumber(decimal: monthlyOtherEarnings).doubleValue))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if monthlyTotalEarnings == 0 {
                    Text("No earnings this month")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            } header: {
                Text("Monthly Summary")
            }
            }
        }
        .navigationTitle("Balance")
        .refreshable {
            await loadBalance()
        }
        .alert("Withdraw Balance", isPresented: $showWithdrawAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Withdraw") {
                withdrawBalance()
            }
        } message: {
            Text("Withdraw $\(String(format: "%.2f", NSDecimalNumber(decimal: balance).doubleValue)) to your connected payment account?")
        }
        .alert("Withdrawal Successful", isPresented: $showWithdrawSuccess) {
            Button("OK") {
                // Refresh balance after withdrawal
                Task {
                    await loadBalance()
                }
            }
        } message: {
            Text("Your withdrawal has been processed. Funds will be transferred to your connected account.")
        }
        .alert("Insufficient Balance", isPresented: $showZeroBalanceWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Balance is ineligible to withdraw because balance needs to be more than $0.00. Please complete bookings to earn money before withdrawing.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            // Initialize selectedMonth to start of current month
            selectedMonth = Calendar.current.startOfMonth(for: Date())
            await loadBalance()
        }
    }
    
    private func loadBalance() async {
        guard let currentUser = authService.currentUser else { return }
        
        isLoading = true
        
        do {
            // Load bookings to calculate earnings
            try await bookingService.fetchMyBookings(userId: currentUser.id, isPilot: true)
            
            // Load crew memberships for automotive earnings
            do {
                crewMemberships = try await bookingService.fetchPilotCrewMemberships(pilotId: currentUser.id)
            } catch {
                // Non-critical - continue without crew memberships
                print("Error loading crew memberships: \(error)")
                crewMemberships = []
            }
            
            // Get balance from Stripe account (not database)
            let balanceInfo = try await stripeConnectService.getPilotBalance(pilotId: currentUser.id)
            balance = balanceInfo.available
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func withdrawBalance() {
        guard let currentUser = authService.currentUser,
              balance > 0 else { return }
        
        isWithdrawing = true
        
        Task {
            do {
                // Check if pilot has Stripe connected account
                guard let stripeAccountId = authService.userProfile?.stripeAccountId,
                      !stripeAccountId.isEmpty else {
                    errorMessage = "Please set up your payment account in Profile settings before withdrawing."
                    showError = true
                    isWithdrawing = false
                    return
                }
                
                // Withdraw balance using StripeConnectService
                _ = try await stripeConnectService.withdrawBalance(pilotId: currentUser.id, amount: balance)
                
                // Refresh balance from Stripe after withdrawal
                await loadBalance()
                
                showWithdrawSuccess = true
                isWithdrawing = false
            } catch {
                isWithdrawing = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    // MARK: - Month Navigation Helpers
    
    private var canGoToPreviousMonth: Bool {
        let calendar = Calendar.current
        let selectedYear = calendar.component(.year, from: selectedMonth)
        let selectedMonthNum = calendar.component(.month, from: selectedMonth)
        
        guard let elevenMonthsAgo = calendar.date(byAdding: .month, value: -11, to: Date()) else { return false }
        let minYear = calendar.component(.year, from: elevenMonthsAgo)
        let minMonth = calendar.component(.month, from: elevenMonthsAgo)
        
        if selectedYear > minYear {
            return true
        } else if selectedYear == minYear && selectedMonthNum > minMonth {
            return true
        }
        return false
    }
    
    private var canGoToNextMonth: Bool {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let currentMonth = calendar.component(.month, from: Date())
        let selectedYear = calendar.component(.year, from: selectedMonth)
        let selectedMonthNum = calendar.component(.month, from: selectedMonth)
        
        // Can go forward if selected month is before current month
        if selectedYear < currentYear {
            return true
        } else if selectedYear == currentYear && selectedMonthNum < currentMonth {
            return true
        }
        return false
    }
    
    private func goToPreviousMonth() {
        let calendar = Calendar.current
        if let previousMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = calendar.startOfMonth(for: previousMonth)
        }
    }
    
    private func goToNextMonth() {
        let calendar = Calendar.current
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = calendar.startOfMonth(for: nextMonth)
        }
    }
    
    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func isInSelectedMonth(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let selectedComponents = calendar.dateComponents([.year, .month], from: selectedMonth)
        let dateComponents = calendar.dateComponents([.year, .month], from: date)
        return selectedComponents.year == dateComponents.year && selectedComponents.month == dateComponents.month
    }
}

// MARK: - Calendar Extension

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
    
    func endOfMonth(for date: Date) -> Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return self.date(byAdding: components, to: startOfMonth(for: date)) ?? date
    }
}
