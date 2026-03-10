//
//  MarketplaceReviewView.swift
//  Buzz
//
//  Created for Marketplace feature
//

import SwiftUI
import Auth

struct MarketplaceReviewView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var marketplaceService: MarketplaceService
    @Environment(\.dismiss) private var dismiss

    let transactionId: UUID
    let toUserId: UUID
    let partnerName: String
    var onReviewSubmitted: (() -> Void)? = nil

    @State private var rating: Int = 0
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Rate Your Experience")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("How was your transaction with \(partnerName)?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Star rating
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        rating = star
                    } label: {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 36))
                            .foregroundColor(star <= rating ? .orange : .gray)
                    }
                }
            }
            .padding(.vertical)

            if rating > 0 {
                Text(ratingLabel)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Comment
            VStack(alignment: .leading, spacing: 8) {
                Text("Comment (Optional)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextEditor(text: $comment)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }

            Spacer()

            // Submit
            Button {
                submitReview()
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    }
                    Text("Submit Review")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(rating > 0 ? Color.orange : Color.gray)
                .cornerRadius(12)
            }
            .disabled(rating == 0 || isSubmitting)
        }
        .padding()
        .navigationTitle("Leave Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var ratingLabel: String {
        switch rating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Great"
        case 5: return "Excellent"
        default: return ""
        }
    }

    private func submitReview() {
        guard let userId = authService.activeUserId else { return }

        isSubmitting = true

        Task {
            do {
                try await marketplaceService.submitReview(
                    transactionId: transactionId,
                    fromUserId: userId,
                    toUserId: toUserId,
                    rating: rating,
                    comment: comment.isEmpty ? nil : comment
                )
                isSubmitting = false
                onReviewSubmitted?()
                dismiss()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
