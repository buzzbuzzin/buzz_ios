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
    
    @State private var selectedRating = 0
    @State private var comment = ""
    @State private var tipAmount = ""
    @State private var showTipField = false
    @Environment(\.dismiss) var dismiss
    
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
                        Toggle("Add a Tip", isOn: $showTipField)
                        
                        if showTipField {
                            HStack {
                                Text("$")
                                    .foregroundColor(.secondary)
                                TextField("Amount", text: $tipAmount)
                                    .keyboardType(.decimalPad)
                            }
                        }
                    } header: {
                        Text("Tip")
                    } footer: {
                        Text("Show your appreciation with a tip")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Rate & Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        let tip: Decimal? = if showTipField && !tipAmount.isEmpty, let tipValue = Double(tipAmount) {
                            Decimal(tipValue)
                        } else {
                            nil
                        }
                        onRatingSubmitted(selectedRating, comment.isEmpty ? nil : comment, tip)
                        dismiss()
                    }
                    .disabled(selectedRating == 0)
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

