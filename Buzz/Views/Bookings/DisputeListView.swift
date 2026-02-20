//
//  DisputeListView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/20/26.
//

import SwiftUI

struct DisputeListView: View {
    @StateObject private var bookingService = BookingService()

    var body: some View {
        NavigationStack {
            Group {
                if bookingService.isLoading {
                    LoadingView(message: "Loading disputes...")
                } else if bookingService.disputes.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.shield.fill",
                        title: "No Disputes",
                        message: "You haven't filed any disputes"
                    )
                } else {
                    List(bookingService.disputes) { dispute in
                        NavigationLink(destination: DisputeDetailView(dispute: dispute)) {
                            DisputeRowView(dispute: dispute)
                        }
                    }
                    .refreshable {
                        try? await bookingService.fetchMyDisputes()
                    }
                }
            }
            .navigationTitle("My Disputes")
        }
        .task {
            try? await bookingService.fetchMyDisputes()
        }
    }
}

// MARK: - Dispute Row View

struct DisputeRowView: View {
    let dispute: BookingDispute

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(displayReason)
                    .font(.headline)
                Spacer()
                DisputeStatusBadge(status: dispute.status)
            }

            if let description = dispute.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Text(dispute.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var displayReason: String {
        switch dispute.reason {
        case DisputeReason.incorrectCharge.rawValue: return "Incorrect Charge"
        case DisputeReason.serviceNotProvided.rawValue: return "Service Not Provided"
        case DisputeReason.qualityIssue.rawValue: return "Quality Issue"
        case DisputeReason.safetyConcern.rawValue: return "Safety Concern"
        case DisputeReason.other.rawValue: return "Other"
        default: return dispute.reason.capitalized
        }
    }
}

// MARK: - Dispute Status Badge

struct DisputeStatusBadge: View {
    let status: DisputeStatus

    var body: some View {
        Text(statusLabel)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }

    private var statusLabel: String {
        switch status {
        case .open: return "Open"
        case .underReview: return "Under Review"
        case .resolved: return "Resolved"
        case .dismissed: return "Dismissed"
        }
    }

    private var statusColor: Color {
        switch status {
        case .open: return .orange
        case .underReview: return .blue
        case .resolved: return .green
        case .dismissed: return .gray
        }
    }
}
