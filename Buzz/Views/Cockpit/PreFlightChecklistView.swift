//
//  PreFlightChecklistView.swift
//  Buzz
//
//  Created by Xinyu Fang on 12/29/25.
//

import SwiftUI

struct PreFlightChecklistView: View {
    @ObservedObject var checklistService: ChecklistService
    let booking: Booking
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Section Title
                Text("Pre-Flight Checklist")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.top)
                
                if checklistService.isLoading {
                    ProgressView("Checking your status…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 12) {
                        // Flight Plan
                        Button(action: {
                            Task {
                                await checklistService.toggleFlightPlan()
                            }
                        }) {
                            ChecklistRow(
                                isComplete: checklistService.hasFlightPlan,
                                title: "Flight Plan",
                                subtitle: nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // FAA Waiver
                        Button(action: {
                            Task {
                                await checklistService.toggleFAAWaiver()
                            }
                        }) {
                            ChecklistRow(
                                isComplete: checklistService.hasFAAWaiver,
                                title: "FAA Waiver",
                                subtitle: nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                }
                
                if let error = checklistService.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Spacer(minLength: 20)
            }
        }
    }
}

// MARK: - Checklist Row

struct ChecklistRow: View {
    let isComplete: Bool
    let title: String
    let subtitle: String?
    var isLink: Bool = false
    var instructions: [String]?
    var linkURL: String?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isComplete ? .green : .secondary)
                .font(.system(size: 22, weight: .semibold))
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Instructions (if provided)
                if let instructions = instructions {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(instructions.enumerated()), id: \.offset) { _, instruction in
                            Text(instruction)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 4)
                }
                
                // Link URL (if provided)
                if let linkURL = linkURL {
                    Text(linkURL)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                
                // Subtitle (if provided and no instructions)
                if let subtitle = subtitle, instructions == nil {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(isLink ? .blue : .secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if isLink {
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

