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
            // Recent Earnings
            Section("Recent Earnings") {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                } else {
                    // Show completed bookings with earnings
                    let completedBookings = bookingService.myBookings.filter { $0.status == .completed }
                    
                    if completedBookings.isEmpty {
                        Text("No earnings yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(completedBookings.prefix(10)) { booking in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(booking.locationName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text(booking.createdAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(String(format: "$%.2f", NSDecimalNumber(decimal: booking.paymentAmount).doubleValue))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                    
                                    if let tip = booking.tipAmount, tip > 0 {
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
            
            // Total Earnings Info
            Section {
                let totalEarnings = bookingService.myBookings
                    .filter { $0.status == .completed }
                    .reduce(Decimal(0)) { total, booking in
                        total + booking.paymentAmount + (booking.tipAmount ?? 0)
                    }
                
                HStack {
                    Text("Total Earnings")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "$%.2f", NSDecimalNumber(decimal: totalEarnings).doubleValue))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Completed Bookings")
                        .font(.subheadline)
                    Spacer()
                    Text("\(bookingService.myBookings.filter { $0.status == .completed }.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            } header: {
                Text("Summary")
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
            await loadBalance()
        }
    }
    
    private func loadBalance() async {
        guard let currentUser = authService.currentUser else { return }
        
        isLoading = true
        
        do {
            // Load bookings to calculate earnings
            try await bookingService.fetchMyBookings(userId: currentUser.id, isPilot: true)
            
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
}

