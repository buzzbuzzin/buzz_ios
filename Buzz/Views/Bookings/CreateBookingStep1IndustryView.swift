//
//  CreateBookingStep1IndustryView.swift
//  Buzz
//
//  Created for Industry selection step in booking flow
//

import SwiftUI

struct CreateBookingStep1IndustryView: View {
    @Binding var selectedSpecialization: BookingSpecialization?

    @State private var showIndustryWarning = false
    @ObservedObject private var configService = BookingConfigService.shared

    let onNext: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Industry Selection Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose Your Industry")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text("Select the type of drone service needed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(BookingSpecialization.allCases, id: \.self) { specialization in
                            SpecializationCard(
                                specialization: specialization,
                                isSelected: selectedSpecialization == specialization
                            ) {
                                handleSpecializationSelection(specialization)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Next Button
                CustomButton(
                    title: "Next",
                    action: onNext,
                    isDisabled: selectedSpecialization == nil
                )
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.vertical)
        }
        .alert("Coming Soon", isPresented: $showIndustryWarning) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(configService.config.comingSoonMessage)
        }
        .task { await configService.ensureConfigLoaded() }
    }
    
    private func handleSpecializationSelection(_ specialization: BookingSpecialization) {
        // Check if this is a supported industry
        if configService.config.isSpecializationEnabled(specialization, forEditing: false) {
            // Toggle selection: if already selected, deselect it
            if selectedSpecialization == specialization {
                selectedSpecialization = nil
            } else {
                selectedSpecialization = specialization
            }
        } else {
            // Show warning for unsupported industries
            showIndustryWarning = true
            // Don't select unsupported industries
        }
    }
}

