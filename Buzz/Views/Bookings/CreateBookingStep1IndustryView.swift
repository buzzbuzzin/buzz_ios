//
//  CreateBookingStep1IndustryView.swift
//  Buzz
//
//  Created for Industry selection step in booking flow
//

import SwiftUI

struct CreateBookingStep1IndustryView: View {
    @Binding var selectedSpecialization: BookingSpecialization?
    
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
                                // Toggle selection: if already selected, deselect it
                                if selectedSpecialization == specialization {
                                    selectedSpecialization = nil
                                } else {
                                    selectedSpecialization = specialization
                                }
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
    }
}

