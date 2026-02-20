//
//  DisputeDetailView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/20/26.
//

import SwiftUI

struct DisputeDetailView: View {
    let dispute: BookingDispute

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status Badge
                HStack {
                    Text("Status")
                        .font(.headline)
                    Spacer()
                    Text(statusLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusColor.opacity(0.2))
                        .foregroundColor(statusColor)
                        .cornerRadius(8)
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                // Reason
                VStack(alignment: .leading, spacing: 8) {
                    Label("Reason", systemImage: "questionmark.circle.fill")
                        .font(.headline)
                    Text(displayReason)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                // Description
                if let description = dispute.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Description", systemImage: "text.alignleft")
                            .font(.headline)
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)
                }

                // Resolution
                if let resolution = dispute.resolution, !resolution.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Resolution", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                        Text(resolution)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)
                }

                // Timeline
                VStack(alignment: .leading, spacing: 16) {
                    Label("Timeline", systemImage: "clock.fill")
                        .font(.headline)

                    // Created
                    TimelineRow(
                        icon: "circle.fill",
                        color: .blue,
                        title: "Dispute Filed",
                        date: dispute.createdAt,
                        isActive: true
                    )

                    // Under Review
                    TimelineRow(
                        icon: dispute.status == .underReview || dispute.status == .resolved || dispute.status == .dismissed ? "circle.fill" : "circle",
                        color: .blue,
                        title: "Under Review",
                        date: nil,
                        isActive: dispute.status == .underReview || dispute.status == .resolved || dispute.status == .dismissed
                    )

                    // Resolved / Dismissed
                    if dispute.status == .resolved {
                        TimelineRow(
                            icon: "checkmark.circle.fill",
                            color: .green,
                            title: "Resolved",
                            date: dispute.resolvedAt,
                            isActive: true
                        )
                    } else if dispute.status == .dismissed {
                        TimelineRow(
                            icon: "xmark.circle.fill",
                            color: .gray,
                            title: "Dismissed",
                            date: dispute.resolvedAt,
                            isActive: true
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Dispute Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusLabel: String {
        switch dispute.status {
        case .open: return "Open"
        case .underReview: return "Under Review"
        case .resolved: return "Resolved"
        case .dismissed: return "Dismissed"
        }
    }

    private var statusColor: Color {
        switch dispute.status {
        case .open: return .orange
        case .underReview: return .blue
        case .resolved: return .green
        case .dismissed: return .gray
        }
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

// MARK: - Timeline Row

struct TimelineRow: View {
    let icon: String
    let color: Color
    let title: String
    let date: Date?
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isActive ? color : .gray.opacity(0.4))
                .font(.system(size: 14))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isActive ? .primary : .secondary)

                if let date = date {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
