//
//  CertificateHistoryView.swift
//  Buzz
//
//  Created by Claude on 3/11/26.
//

import SwiftUI

struct CertificateHistoryView: View {
    @ObservedObject var beaconService: BeaconService
    let userId: UUID
    let trainingType: BeaconTrainingType
    @Environment(\.dismiss) var dismiss
    @State private var history: [BeaconTrainingProgress] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if history.isEmpty {
                    Text("No certificates found")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(Array(history.enumerated()), id: \.element.id) { index, record in
                            CertificateHistoryRow(record: record, isLatest: index == 0)
                        }
                    }
                }
            }
            .navigationTitle("\(trainingType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadHistory()
            }
        }
    }

    private func loadHistory() async {
        do {
            history = try await beaconService.getTrainingHistory(userId: userId, trainingType: trainingType)
        } catch {
            errorMessage = "Failed to load certificate history. Please try again."
        }
        isLoading = false
    }
}

// MARK: - Certificate History Row

private struct CertificateHistoryRow: View {
    let record: BeaconTrainingProgress
    let isLatest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if isLatest {
                    Text("Current")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(4)
                }

                Spacer()

                statusLabel
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        "Uploaded: \(record.uploadedAt.formatted(date: .abbreviated, time: .omitted))",
                        systemImage: "arrow.up.doc"
                    )
                    .font(.subheadline)

                    if let expiresAt = record.expiresAt {
                        Label(
                            "Expires: \(expiresAt.formatted(date: .abbreviated, time: .omitted))",
                            systemImage: "calendar"
                        )
                        .font(.subheadline)
                        .foregroundColor(record.isExpired ? .red : .secondary)
                    } else {
                        Label("No expiration date", systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                if record.certificateUrl != "badge-based",
                   let url = URL(string: record.certificateUrl) {
                    Link(destination: url) {
                        Image(systemName: "doc.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusLabel: some View {
        Group {
            if record.isCurrent {
                Label("Active", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else if record.isExpired {
                Label("Expired", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Label("No Expiration", systemImage: "questionmark.circle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
}
