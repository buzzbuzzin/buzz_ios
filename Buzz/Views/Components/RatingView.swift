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
    
    @State private var selectedRating = 0
    @State private var comment = ""
    @State private var selectedTipAmount: Decimal? = nil
    @State private var customTipAmount = ""
    @State private var showCustomTipField = false
    @Environment(\.dismiss) var dismiss
    
    // Predefined tip amounts
    private let tipAmounts: [Decimal] = [1, 2, 5]
    
    init(userName: String, isPilotRatingCustomer: Bool, onRatingSubmitted: @escaping (Int, String?, Decimal?) -> Void, customTitle: String? = nil) {
        self.userName = userName
        self.isPilotRatingCustomer = isPilotRatingCustomer
        self.onRatingSubmitted = onRatingSubmitted
        self.customTitle = customTitle
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(spacing: 20) {
                        // User Icon
                        Image(systemName: isPilotRatingCustomer ? "person.fill" : "airplane.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .padding(.top)
                        
                        // Title
                        Text("Rate \(userName)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(isPilotRatingCustomer ? "How was your experience with this customer?" : "How was your experience with this pilot?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                // Star Rating
                Section("Rating") {
                    HStack {
                        Spacer()
                        ForEach(1...5, id: \.self) { rating in
                            Button(action: {
                                selectedRating = rating
                            }) {
                                Image(systemName: rating <= selectedRating ? "star.fill" : "star")
                                    .font(.system(size: 40))
                                    .foregroundColor(rating <= selectedRating ? .yellow : .gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                }
                
                // Comment Section
                Section("Your Review (Optional)") {
                    TextField("Share your experience...", text: $comment, axis: .vertical)
                        .lineLimit(3...8)
                }
                
                // Tip Section (Only for customers rating pilots)
                if !isPilotRatingCustomer {
                    Section {
                        Text("Add a tip for \(userName)")
                            .font(.headline)
                            .padding(.vertical, 4)
                        
                        // Predefined tip amount buttons
                        HStack(spacing: 12) {
                            ForEach(tipAmounts, id: \.self) { amount in
                                Button(action: {
                                    if selectedTipAmount == amount {
                                        selectedTipAmount = nil
                                        showCustomTipField = false
                                    } else {
                                        selectedTipAmount = amount
                                        showCustomTipField = false
                                        customTipAmount = ""
                                    }
                                }) {
                                    Text("$\(NSDecimalNumber(decimal: amount).intValue)")
                                        .font(.headline)
                                        .foregroundColor(selectedTipAmount == amount ? .white : .primary)
                                        .frame(width: 70, height: 70)
                                        .background(selectedTipAmount == amount ? Color.teal : Color(.systemGray6))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        
                        // Custom amount option
                        Button(action: {
                            showCustomTipField.toggle()
                            if showCustomTipField {
                                selectedTipAmount = nil
                            } else {
                                customTipAmount = ""
                            }
                        }) {
                            Text("Enter Custom Amount")
                                .font(.subheadline)
                                .foregroundColor(.teal)
                        }
                        .padding(.vertical, 4)
                        
                        // Custom tip amount field
                        if showCustomTipField {
                            HStack {
                                Text("$")
                                    .foregroundColor(.secondary)
                                TextField("Amount", text: $customTipAmount)
                                    .keyboardType(.decimalPad)
                            }
                            .padding(.top, 4)
                        }
                    } header: {
                        Text("Tip")
                    } footer: {
                        Text("Show your appreciation with a tip")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(customTitle ?? "Rate & Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("DONE") {
                        let tip: Decimal? = if showCustomTipField && !customTipAmount.isEmpty, let tipValue = Double(customTipAmount) {
                            Decimal(tipValue)
                        } else if let selectedTip = selectedTipAmount {
                            selectedTip
                        } else {
                            nil
                        }
                        onRatingSubmitted(selectedRating, comment.isEmpty ? nil : comment, tip)
                        dismiss()
                    }
                    .disabled(selectedRating == 0)
                    .fontWeight(.semibold)
                }
            }
        }
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

