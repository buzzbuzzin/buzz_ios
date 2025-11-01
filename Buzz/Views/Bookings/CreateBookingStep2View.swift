//
//  CreateBookingStep2View.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI

struct CreateBookingStep2View: View {
    @Binding var description: String
    @Binding var paymentAmount: String
    @Binding var estimatedHours: String
    
    let onBack: () -> Void
    let onCreate: () -> Void
    let isLoading: Bool
    let isFormValid: Bool
    
    var body: some View {
        Form {
            Section("Booking Details") {
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...6)
                
                TextField("Payment Amount ($)", text: $paymentAmount)
                    .keyboardType(.decimalPad)
                
                TextField("Estimated Flight Hours", text: $estimatedHours)
                    .keyboardType(.decimalPad)
            }
            
            Section {
                HStack(spacing: 12) {
                    Button("Back") {
                        onBack()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                    
                    CustomButton(
                        title: "Create Booking",
                        action: onCreate,
                        isLoading: isLoading,
                        isDisabled: !isFormValid
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

