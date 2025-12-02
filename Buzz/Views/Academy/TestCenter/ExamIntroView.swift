//
//  ExamIntroView.swift
//  Buzz
//
//  Exam introduction view showing details, prerequisites, and price
//

import SwiftUI
import Auth

struct ExamIntroView: View {
    let examType: ExamType
    
    @EnvironmentObject var authService: AuthService
    @StateObject private var examService = ExamService()
    @State private var priceInfo: ExamPriceResponse?
    @State private var isLoadingPrice = true
    @State private var priceError: String?
    @State private var prerequisitesStatus: ExamPrerequisitesStatus?
    @State private var showSchedulingView = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Image/Icon
                ZStack {
                    LinearGradient(
                        colors: [examType.color.opacity(0.6), examType.color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 200)
                    
                    VStack(spacing: 12) {
                        Image(systemName: examType.icon)
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        
                        Text(examType.displayName)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 24) {
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About This Exam")
                            .font(.headline)
                        
                        Text(examType.fullDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Exam Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Exam Details")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ExamDetailRow(
                                icon: "clock",
                                label: "Duration",
                                value: "\(examType.durationMinutes) minutes"
                            )
                            
                            ExamDetailRow(
                                icon: examType.allowsOnline ? "video" : "mappin.and.ellipse",
                                label: "Format",
                                value: examType.allowsOnline ? "In-person or Online" : "In-person only"
                            )
                            
                            // Price Row
                            if isLoadingPrice {
                                HStack {
                                    Image(systemName: "dollarsign.circle")
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    Text("Price")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            } else if let price = priceInfo {
                                ExamDetailRow(
                                    icon: "dollarsign.circle",
                                    label: "Price",
                                    value: price.formattedPrice,
                                    valueColor: .green
                                )
                            } else if let error = priceError {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                        .frame(width: 24)
                                    Text("Price unavailable")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Prerequisites
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Prerequisites")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ForEach(Array(examType.prerequisites.enumerated()), id: \.offset) { index, prerequisite in
                                PrerequisiteDetailRow(
                                    number: index + 1,
                                    title: prerequisite,
                                    isCompleted: getPrerequisiteStatus(index: index)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // What to Expect Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What to Expect")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            WhatToExpectRow(text: "Confirm your appointment 24 hours before")
                            WhatToExpectRow(text: examType.allowsOnline ? "Join via Zoom or arrive at the location 10 minutes early" : "Arrive at the location 10 minutes early")
                            WhatToExpectRow(text: "Bring valid identification")
                            if examType == .flightReview {
                                WhatToExpectRow(text: "Bring your drone and necessary equipment")
                            }
                            WhatToExpectRow(text: "Results provided immediately after completion")
                        }
                        .padding(.horizontal)
                    }
                    
                    // Schedule Button
                    Button(action: {
                        showSchedulingView = true
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Schedule Exam")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            prerequisitesStatus?.isEligible == true
                            ? examType.color
                            : Color.gray
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(prerequisitesStatus?.isEligible != true || priceInfo == nil)
                    .padding(.horizontal)
                    
                    if prerequisitesStatus?.isEligible != true {
                        Text("Complete all prerequisites to schedule this exam")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle(examType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSchedulingView) {
            if let price = priceInfo {
                ExamSchedulingView(
                    examType: examType,
                    priceInfo: price,
                    onBookingComplete: {
                        showSchedulingView = false
                    }
                )
            }
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        guard let currentUser = authService.currentUser else { return }
        
        // Load prerequisites status
        do {
            prerequisitesStatus = try await examService.checkPrerequisites(pilotId: currentUser.id)
        } catch {
            print("Error checking prerequisites: \(error)")
        }
        
        // Load price
        isLoadingPrice = true
        do {
            priceInfo = try await examService.fetchExamPrice(examType: examType)
            priceError = nil
        } catch {
            priceError = error.localizedDescription
            print("Error fetching price: \(error)")
        }
        isLoadingPrice = false
    }
    
    private func getPrerequisiteStatus(index: Int) -> Bool {
        guard let status = prerequisitesStatus else { return false }
        switch index {
        case 0:
            return status.passedGroundSchoolTest
        case 1:
            return status.completedUnit4
        default:
            return false
        }
    }
}

// MARK: - Supporting Views

struct ExamDetailRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct PrerequisiteDetailRow: View {
    let number: Int
    let title: String
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 28, height: 28)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.caption.bold())
                } else {
                    Text("\(number)")
                        .foregroundColor(.gray)
                        .font(.caption.bold())
                }
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(isCompleted ? .primary : .secondary)
                .strikethrough(isCompleted)
            
            Spacer()
            
            if isCompleted {
                Text("Completed")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text("Required")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct WhatToExpectRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        ExamIntroView(examType: .flightReview)
            .environmentObject(AuthService())
    }
}

