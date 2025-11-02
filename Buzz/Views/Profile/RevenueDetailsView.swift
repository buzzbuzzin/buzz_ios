//
//  RevenueDetailsView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Charts
import Auth

struct MonthlyRevenue: Identifiable {
    let id = UUID()
    let month: Date
    let revenue: Decimal
    let bookingCount: Int
    
    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: month)
    }
    
    var shortMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: month)
    }
}

struct RevenueDetailsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var bookingService = BookingService()
    @State private var monthlyRevenues: [MonthlyRevenue] = []
    @State private var totalRevenue: Decimal = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        List {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                }
            } else if monthlyRevenues.isEmpty {
                Section {
                    EmptyStateView(
                        icon: "dollarsign.circle",
                        title: "No Revenue Yet",
                        message: "Complete bookings to see your revenue here"
                    )
                }
            } else {
                // Total Revenue Card
                Section {
                    VStack(spacing: 12) {
                        Text("Total Revenue")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(formatCurrency(totalRevenue))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.green)
                        
                        Text("\(monthlyRevenues.reduce(0) { $0 + $1.bookingCount }) completed bookings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                
                // Chart Section
                Section("Revenue Chart") {
                    Chart(monthlyRevenues) { data in
                        BarMark(
                            x: .value("Month", data.shortMonthName),
                            y: .value("Revenue", NSDecimalNumber(decimal: data.revenue).doubleValue)
                        )
                        .foregroundStyle(Color.green.gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 250)
                    .padding(.vertical, 8)
                }
                
                // Monthly Breakdown
                Section("Monthly Breakdown") {
                    ForEach(monthlyRevenues) { monthData in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(monthData.monthName)
                                    .font(.headline)
                                
                                Text("\(monthData.bookingCount) booking\(monthData.bookingCount == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(formatCurrency(monthData.revenue))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Revenue")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadRevenueData()
        }
    }
    
    private func loadRevenueData() async {
        guard let currentUser = authService.currentUser else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let completedBookings = try await bookingService.getPilotRevenue(pilotId: currentUser.id)
            
            // Group bookings by month
            let calendar = Calendar.current
            let groupedByMonth = Dictionary(grouping: completedBookings) { booking in
                let components = calendar.dateComponents([.year, .month], from: booking.createdAt)
                return calendar.date(from: components) ?? booking.createdAt
            }
            
            // Calculate monthly revenue
            var revenues: [MonthlyRevenue] = []
            var total: Decimal = 0
            
            for (month, bookings) in groupedByMonth {
                let monthRevenue = bookings.reduce(Decimal(0)) { sum, booking in
                    sum + booking.paymentAmount + (booking.tipAmount ?? 0)
                }
                total += monthRevenue
                
                revenues.append(MonthlyRevenue(
                    month: month,
                    revenue: monthRevenue,
                    bookingCount: bookings.count
                ))
            }
            
            // Sort by month (newest first)
            revenues.sort { $0.month > $1.month }
            
            monthlyRevenues = revenues
            totalRevenue = total
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            print("Error loading revenue data: \(error)")
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}

