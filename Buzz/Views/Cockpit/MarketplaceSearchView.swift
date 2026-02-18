//
//  MarketplaceSearchView.swift
//  Buzz
//
//  Created for Marketplace feature
//

import SwiftUI

struct MarketplaceSearchView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedCondition: ListingCondition?
    @Binding var selectedTransactionType: MarketplaceTransactionType?
    @Binding var minPrice: Decimal?
    @Binding var maxPrice: Decimal?

    var onApply: () -> Void

    @State private var minPriceText = ""
    @State private var maxPriceText = ""

    var body: some View {
        Form {
            Section("Condition") {
                ForEach(ListingCondition.allCases) { condition in
                    Button {
                        if selectedCondition == condition {
                            selectedCondition = nil
                        } else {
                            selectedCondition = condition
                        }
                    } label: {
                        HStack {
                            Circle()
                                .fill(condition.color)
                                .frame(width: 10, height: 10)
                            Text(condition.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedCondition == condition {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }

            Section("Transaction Type") {
                ForEach(MarketplaceTransactionType.allCases) { type in
                    Button {
                        if selectedTransactionType == type {
                            selectedTransactionType = nil
                        } else {
                            selectedTransactionType = type
                        }
                    } label: {
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text(type.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedTransactionType == type {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }

            Section("Price Range") {
                HStack {
                    Text("Min $")
                        .foregroundColor(.secondary)
                    TextField("0", text: $minPriceText)
                        .keyboardType(.decimalPad)
                }

                HStack {
                    Text("Max $")
                        .foregroundColor(.secondary)
                    TextField("Any", text: $maxPriceText)
                        .keyboardType(.decimalPad)
                }
            }

            Section {
                Button {
                    applyFilters()
                } label: {
                    Text("Apply Filters")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .cornerRadius(10)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Button {
                    clearFilters()
                } label: {
                    Text("Clear All Filters")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Filters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .onAppear {
            if let min = minPrice { minPriceText = "\(min)" }
            if let max = maxPrice { maxPriceText = "\(max)" }
        }
    }

    private func applyFilters() {
        minPrice = Decimal(string: minPriceText)
        maxPrice = Decimal(string: maxPriceText)
        onApply()
        dismiss()
    }

    private func clearFilters() {
        selectedCondition = nil
        selectedTransactionType = nil
        minPrice = nil
        maxPrice = nil
        minPriceText = ""
        maxPriceText = ""
        onApply()
        dismiss()
    }
}
