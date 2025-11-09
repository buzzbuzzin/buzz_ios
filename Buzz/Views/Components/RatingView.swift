//
//  RatingView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI

struct RatingView: View {
    let userName: String
    let isPilotRatingCustomer: Bool
    let onRatingSubmitted: (Int, String?, Decimal?) -> Void
    let customTitle: String? // Optional custom title (e.g., "Booking is completed")
    let paymentAmount: Decimal? // Payment amount for calculating tip amounts (only for customers rating pilots)
    let userRating: Double? // Optional user rating to display (e.g., 4.99)
    
    @State private var selectedRating = 0
    @State private var comment = ""
    @State private var selectedTipPercentage: Int? = nil // 5, 10, or 15
    @State private var customTipAmount: Decimal? = nil // Custom tip amount entered by user
    @State private var showCustomTipSheet = false
    @Environment(\.dismiss) var dismiss
    
    // Predefined tip percentages
    private let tipPercentages: [Int] = [5, 10, 15]
    
    init(userName: String, isPilotRatingCustomer: Bool, onRatingSubmitted: @escaping (Int, String?, Decimal?) -> Void, customTitle: String? = nil, paymentAmount: Decimal? = nil, userRating: Double? = nil) {
        self.userName = userName
        self.isPilotRatingCustomer = isPilotRatingCustomer
        self.onRatingSubmitted = onRatingSubmitted
        self.customTitle = customTitle
        self.paymentAmount = paymentAmount
        self.userRating = userRating
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 12) {
                        // Title
                        Text(isPilotRatingCustomer ? "How was your booking with \(userName)?" : "How was your booking with \(userName)?")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // Tip Section (Only for customers rating pilots)
                    if !isPilotRatingCustomer, let paymentAmount = paymentAmount {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Add a tip for \(userName)")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Your booking was \(String(format: "$%.2f", NSDecimalNumber(decimal: paymentAmount).doubleValue))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            // Tip percentage buttons with calculated amounts
                            HStack(spacing: 12) {
                                ForEach(tipPercentages, id: \.self) { percentage in
                                    TipPercentageButton(
                                        percentage: percentage,
                                        paymentAmount: paymentAmount,
                                        isSelected: selectedTipPercentage == percentage,
                                        onTap: {
                                            if selectedTipPercentage == percentage {
                                                selectedTipPercentage = nil
                                            } else {
                                                selectedTipPercentage = percentage
                                                customTipAmount = nil
                                            }
                                        }
                                    )
                                }
                            }
                            
                            // Custom amount option
                            Button(action: {
                                showCustomTipSheet = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "pencil")
                                        .font(.subheadline)
                                    Text("Enter Custom Amount")
                                        .font(.subheadline)
                                    
                                    if let customTip = customTipAmount {
                                        Spacer()
                                        Text(String(format: "$%.2f", NSDecimalNumber(decimal: customTip).doubleValue))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundColor(.primary)
                            }
                            
                            Divider()
                        }
                        .padding(.horizontal)
                    }
                    
                    // Rating Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Rate your booking")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { rating in
                                Button(action: {
                                    selectedRating = rating
                                }) {
                                    Image(systemName: rating <= selectedRating ? "star.fill" : "star")
                                        .font(.system(size: 32))
                                        .foregroundColor(rating <= selectedRating ? .yellow : .gray)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        Divider()
                        
                        // Review text field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Review Details")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            TextField("Share your experience...", text: $comment, axis: .vertical)
                                .lineLimit(3...8)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        
                        Divider()
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                        .frame(height: 20)
                    
                    // Submit Button
                    Button(action: {
                        let tip: Decimal? = if let customTip = customTipAmount {
                            customTip
                        } else if let percentage = selectedTipPercentage, let paymentAmount = paymentAmount {
                            paymentAmount * Decimal(percentage) / 100
                        } else {
                            nil
                        }
                        onRatingSubmitted(selectedRating, comment.isEmpty ? nil : comment, tip)
                        dismiss()
                    }) {
                        Text("Submit")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(selectedRating == 0 ? Color.gray : Color.black)
                            .cornerRadius(12)
                    }
                    .disabled(selectedRating == 0)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(customTitle ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showCustomTipSheet) {
                CustomTipSheet(
                    paymentAmount: paymentAmount ?? 0,
                    onTipSelected: { tipAmount in
                        customTipAmount = tipAmount
                        selectedTipPercentage = nil
                        showCustomTipSheet = false
                    },
                    onCancel: {
                        showCustomTipSheet = false
                    }
                )
            }
        }
    }
}

// MARK: - Custom Tip Sheet

struct CustomTipSheet: View {
    let paymentAmount: Decimal
    let onTipSelected: (Decimal) -> Void
    let onCancel: () -> Void
    
    @State private var customTipAmount = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Enter Custom Amount")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Payment: \(String(format: "$%.2f", NSDecimalNumber(decimal: paymentAmount).doubleValue))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Tip amount input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tip Amount")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("$")
                            .font(.title2)
                            .foregroundColor(.primary)
                        
                        TextField("0.00", text: $customTipAmount)
                            .font(.title)
                            .keyboardType(.decimalPad)
                            .focused($isTextFieldFocused)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        if let tipValue = Double(customTipAmount), tipValue > 0 {
                            onTipSelected(Decimal(tipValue))
                        }
                    }) {
                        Text("DONE")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(customTipAmount.isEmpty || Double(customTipAmount) == nil || Double(customTipAmount)! <= 0 ? Color.gray : Color.black)
                            .cornerRadius(12)
                    }
                    .disabled(customTipAmount.isEmpty || Double(customTipAmount) == nil || Double(customTipAmount)! <= 0)
                    
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
}

// MARK: - Tip Percentage Button

struct TipPercentageButton: View {
    let percentage: Int
    let paymentAmount: Decimal
    let isSelected: Bool
    let onTap: () -> Void
    
    private var calculatedTip: Decimal {
        paymentAmount * Decimal(percentage) / 100
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(percentage)%")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(String(format: "$%.2f", NSDecimalNumber(decimal: calculatedTip).doubleValue))
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
            }
            .frame(minWidth: 80)
            .frame(height: 60)
            .background(isSelected ? Color.black : Color(.systemGray6))
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Star Rating Display Component

struct StarRatingView: View {
    let rating: Double
    let maxRating: Int = 5
    let starSize: CGFloat = 16
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: index <= Int(rating.rounded()) ? "star.fill" : (index <= Int(rating) ? "star.half.fill" : "star"))
                    .font(.system(size: starSize))
                    .foregroundColor(.yellow)
            }
            if rating > 0 {
                Text(String(format: "%.1f", rating))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

