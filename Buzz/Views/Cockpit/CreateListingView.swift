//
//  CreateListingView.swift
//  Buzz
//
//  Created for Marketplace feature
//

import SwiftUI
import PhotosUI
import CoreLocation
import Auth

struct CreateListingView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var marketplaceService: MarketplaceService
    @Environment(\.dismiss) private var dismiss

    // Step tracking
    @State private var currentStep = 0
    private let totalSteps = 5

    // Form fields
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var title = ""
    @State private var description = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var category: MarketplaceCategory = .drones
    @State private var condition: ListingCondition = .good
    @State private var priceText = ""
    @State private var shippingCostText = ""
    @State private var transactionType: MarketplaceTransactionType = .both
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var locationName = ""

    @State private var showLocationSearch = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: Double(currentStep + 1), total: Double(totalSteps + 1))
                .tint(.orange)
                .padding(.horizontal)
                .padding(.top, 8)

            // Step indicator
            Text("Step \(currentStep + 1) of \(totalSteps + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)

            // Content
            TabView(selection: $currentStep) {
                photosStep.tag(0)
                detailsStep.tag(1)
                categoryStep.tag(2)
                pricingStep.tag(3)
                locationStep.tag(4)
                reviewStep.tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)

            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                    .foregroundColor(.secondary)
                }

                Spacer()

                if currentStep < totalSteps {
                    Button {
                        withAnimation { currentStep += 1 }
                    } label: {
                        Text("Next")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(canProceed ? Color.orange : Color.gray)
                            .cornerRadius(10)
                    }
                    .disabled(!canProceed)
                } else {
                    Button {
                        submitListing()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Post Listing")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(canSubmit ? Color.orange : Color.gray)
                        .cornerRadius(10)
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .padding()
        }
        .navigationTitle("Create Listing")
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
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Step 1: Photos

    private var photosStep: some View {
        VStack(spacing: 20) {
            Text("Add Photos")
                .font(.title2)
                .fontWeight(.bold)

            Text("Add up to 6 photos of your item")
                .foregroundColor(.secondary)

            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 6,
                matching: .images
            ) {
                if selectedImages.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("Tap to add photos")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedImages.indices, id: \.self) { index in
                                Image(uiImage: selectedImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            if selectedImages.count < 6 {
                                VStack {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                        .foregroundColor(.orange)
                                }
                                .frame(width: 120, height: 120)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            .onChange(of: selectedPhotos) { _, newItems in
                Task {
                    var loaded: [UIImage] = []
                    var failedCount = 0
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            loaded.append(image)
                        } else {
                            failedCount += 1
                        }
                    }
                    selectedImages = loaded
                    if failedCount > 0 {
                        errorMessage = "\(failedCount) photo(s) failed to load. Please try again."
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Step 2: Details

    private var detailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Item Details")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Title").font(.subheadline).fontWeight(.medium)
                    TextField("e.g., DJI Mini 4 Pro - Like New", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Description").font(.subheadline).fontWeight(.medium)
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .padding(4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Brand (Optional)").font(.subheadline).fontWeight(.medium)
                    TextField("e.g., DJI", text: $brand)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Model (Optional)").font(.subheadline).fontWeight(.medium)
                    TextField("e.g., Mini 4 Pro", text: $model)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()
        }
    }

    // MARK: - Step 3: Category & Condition

    private var categoryStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Category & Condition")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Category").font(.subheadline).fontWeight(.medium)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(MarketplaceCategory.allCases) { cat in
                            Button {
                                category = cat
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 14))
                                    Text(cat.displayName)
                                        .font(.system(size: 13))
                                }
                                .foregroundColor(category == cat ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(category == cat ? Color.orange : Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Condition").font(.subheadline).fontWeight(.medium)
                    ForEach(ListingCondition.allCases) { cond in
                        Button {
                            condition = cond
                        } label: {
                            HStack {
                                Circle()
                                    .fill(cond.color)
                                    .frame(width: 10, height: 10)
                                Text(cond.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if condition == cond {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding()
                            .background(condition == cond ? Color.orange.opacity(0.1) : Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Step 4: Pricing & Transaction Type

    private var pricingStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Pricing")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Price (USD)").font(.subheadline).fontWeight(.medium)
                    HStack {
                        Text("$")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $priceText)
                            .font(.title2)
                            .keyboardType(.decimalPad)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                    if let price = Decimal(string: priceText), price > 99999 {
                        Text("Maximum price is $99,999")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Transaction Type").font(.subheadline).fontWeight(.medium)
                    ForEach(MarketplaceTransactionType.allCases) { type in
                        Button {
                            transactionType = type
                        } label: {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(.orange)
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text(type.displayName)
                                        .foregroundColor(.primary)
                                        .fontWeight(.medium)
                                    Text(transactionTypeDescription(type))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if transactionType == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding()
                            .background(transactionType == type ? Color.orange.opacity(0.1) : Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }

                if transactionType != .meetup {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shipping Cost (Optional)").font(.subheadline).fontWeight(.medium)
                        HStack {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("0.00", text: $shippingCostText)
                                .keyboardType(.decimalPad)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                        Text("10% platform fee applies to online transactions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if transactionType == .meetup || transactionType == .both {
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.blue)
                        Text("For safety, we recommend meeting at a nearby police station")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }

    // MARK: - Step 5: Location

    private var locationStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Location")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            if transactionType == .ship {
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Shipping Only")
                        .font(.headline)
                    Text("No meetup location needed. You'll ship the item to the buyer.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                LocationSearchView(
                    selectedLocation: $selectedLocation,
                    locationName: $locationName,
                    isPresented: $showLocationSearch,
                    onLocationSelected: { _ in
                        withAnimation { currentStep = 5 }
                    }
                )
            }
        }
    }

    // MARK: - Step 6: Review

    private var reviewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Review Your Listing")
                    .font(.title2)
                    .fontWeight(.bold)

                // Photo preview
                if !selectedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedImages.indices, id: \.self) { index in
                                Image(uiImage: selectedImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }

                reviewRow("Title", value: title)
                reviewRow("Category", value: category.displayName)
                reviewRow("Condition", value: condition.displayName)
                reviewRow("Price", value: "$\(priceText)")
                reviewRow("Transaction", value: transactionType.displayName)

                if !brand.isEmpty { reviewRow("Brand", value: brand) }
                if !model.isEmpty { reviewRow("Model", value: model) }
                if !shippingCostText.isEmpty { reviewRow("Shipping", value: "$\(shippingCostText)") }
                if !locationName.isEmpty { reviewRow("Location", value: locationName) }

                if !description.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(description)
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func reviewRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func transactionTypeDescription(_ type: MarketplaceTransactionType) -> String {
        switch type {
        case .ship: return "Buyer pays online, you ship the item"
        case .meetup: return "Meet in person, cash payment"
        case .both: return "Buyer chooses shipping or meetup"
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0: return true // Photos optional
        case 1: return !title.isEmpty && !description.isEmpty
        case 2: return true // Category/condition have defaults
        case 3:
            let price = Decimal(string: priceText) ?? 0
            return !priceText.isEmpty && price > 0 && price <= 99999
        case 4: return transactionType == .ship || selectedLocation != nil || !locationName.isEmpty
        default: return true
        }
    }

    private var canSubmit: Bool {
        let price = Decimal(string: priceText) ?? 0
        return !title.isEmpty && !description.isEmpty &&
        !priceText.isEmpty && price > 0 && price <= 99999
    }

    private func submitListing() {
        guard let userId = authService.currentUser?.id,
              let price = Decimal(string: priceText) else { return }

        isSubmitting = true

        Task {
            do {
                // Upload images
                let imageUrls = try await marketplaceService.uploadListingImages(
                    userId: userId, images: selectedImages
                )

                // Create listing
                let insert = MarketplaceListingInsert(
                    sellerId: userId,
                    title: title,
                    description: description,
                    price: price,
                    category: category,
                    condition: condition,
                    transactionType: transactionType,
                    imageUrls: imageUrls,
                    locationName: locationName.isEmpty ? nil : locationName,
                    locationLat: selectedLocation?.latitude,
                    locationLng: selectedLocation?.longitude,
                    brand: brand.isEmpty ? nil : brand,
                    model: model.isEmpty ? nil : model,
                    shippingCost: Decimal(string: shippingCostText)
                )

                let _ = try await marketplaceService.createListing(insert: insert)
                isSubmitting = false
                dismiss()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
