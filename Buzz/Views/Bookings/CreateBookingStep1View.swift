//
//  CreateBookingStep1View.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import MapKit

struct CreateBookingStep1View: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var locationName: String
    @Binding var selectedDate: Date
    @Binding var selectedSpecialization: BookingSpecialization?
    
    @State private var showLocationSearch = false
    
    let onNext: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Location Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Location")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // Address Text Field (Uber-style)
                    Button(action: {
                        showLocationSearch = true
                    }) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 20))
                            
                            Text(locationName.isEmpty ? "Enter address" : locationName)
                                .foregroundColor(locationName.isEmpty ? .secondary : .primary)
                                .font(.body)
                            
                            Spacer()
                            
                            if selectedLocation != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                }
                
                // Date Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("2. Select Date")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    DatePicker(
                        "Booking Date",
                        selection: $selectedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .padding(.horizontal)
                }
                
                // Specialization Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("3. Choose Specialization")
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
                                selectedSpecialization = specialization
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Next Button
                CustomButton(
                    title: "Next",
                    action: onNext,
                    isDisabled: selectedLocation == nil || selectedSpecialization == nil
                )
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.vertical)
        }
        .fullScreenCover(isPresented: $showLocationSearch) {
            LocationSearchView(
                selectedLocation: $selectedLocation,
                locationName: $locationName,
                isPresented: $showLocationSearch
            )
        }
    }
}

// MARK: - Specialization Card

struct SpecializationCard: View {
    let specialization: BookingSpecialization
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: specialization.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(specialization.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

