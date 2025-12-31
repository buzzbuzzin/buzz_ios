//
//  IncidentLogFormView.swift
//  Buzz
//
//  Created for electronic incident log form
//

import SwiftUI
import Auth

struct IncidentLogFormView: View {
    let booking: Booking
    @EnvironmentObject var authService: AuthService
    @StateObject private var incidentLogService = IncidentLogService()
    @Environment(\.dismiss) private var dismiss
    
    // Form fields
    @State private var name: String = ""
    @State private var phoneNumber: String = ""
    @State private var dateOfIncident = Date()
    @State private var dateOfReport = Date()
    @State private var jobTitle: String = ""
    @State private var operationName: String = ""
    @State private var organization: String = ""
    @State private var pic: String = "" // Pilot in Command
    @State private var region: String = ""
    @State private var airspaceClass: String = ""
    @State private var reportedToPolice = false
    @State private var reportedToAtc = false
    @State private var locationOfIncident: String = ""
    @State private var descriptionOfIncident: String = ""
    @State private var nameOfWitness: String = ""
    
    // Signature
    @State private var signatureImage: UIImage?
    
    // UI State
    @State private var showSubmitConfirmation = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var existingLog: IncidentLog?
    @State private var isCheckingExisting = true
    
    var body: some View {
        Group {
            if isCheckingExisting {
                ProgressView("Loading...")
            } else if let existing = existingLog {
                // Show read-only view
                IncidentLogReadOnlyView(incidentLog: existing, booking: booking)
            } else {
                // Show editable form
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Incident Report")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Complete this form to document an incident. All fields marked with * are required.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Booking Info Card
                        BookingInfoCard(booking: booking)
                            .padding(.horizontal)
                        
                        // Basic Information Section
                        FormSection(title: "Basic Information") {
                            VStack(spacing: 16) {
                                FormTextField(
                                    title: "Name *",
                                    text: $name,
                                    placeholder: "Your full name"
                                )
                                
                                FormTextField(
                                    title: "Phone Number *",
                                    text: $phoneNumber,
                                    placeholder: "(555) 555-5555",
                                    keyboardType: .phonePad
                                )
                                
                                FormDatePicker(
                                    title: "Date of Incident *",
                                    date: $dateOfIncident
                                )
                                
                                FormDatePicker(
                                    title: "Date of Report *",
                                    date: $dateOfReport
                                )
                                
                                FormTextField(
                                    title: "Job Title",
                                    text: $jobTitle,
                                    placeholder: "Optional"
                                )
                                
                                FormTextField(
                                    title: "Operation Name",
                                    text: $operationName,
                                    placeholder: "Optional"
                                )
                            }
                        }
                        
                        // Additional Details Section
                        FormSection(title: "Additional Details") {
                            VStack(spacing: 16) {
                                FormTextField(
                                    title: "Organization",
                                    text: $organization,
                                    placeholder: "Optional"
                                )
                                
                                FormTextField(
                                    title: "PIC (Pilot in Command)",
                                    text: $pic,
                                    placeholder: "Optional"
                                )
                                
                                FormTextField(
                                    title: "Region",
                                    text: $region,
                                    placeholder: "Optional"
                                )
                                
                                FormTextField(
                                    title: "Airspace Class",
                                    text: $airspaceClass,
                                    placeholder: "e.g., Class B, C, D, E, G"
                                )
                                
                                FormToggle(
                                    title: "Reported to Police?",
                                    isOn: $reportedToPolice
                                )
                                
                                FormToggle(
                                    title: "Reported to ATC?",
                                    isOn: $reportedToAtc
                                )
                            }
                        }
                        
                        // Incident Details Section
                        FormSection(title: "Incident Details") {
                            VStack(spacing: 16) {
                                FormTextField(
                                    title: "Location of Incident *",
                                    text: $locationOfIncident,
                                    placeholder: "Describe where the incident occurred"
                                )
                                
                                FormTextEditor(
                                    title: "Description of Incident *",
                                    text: $descriptionOfIncident,
                                    placeholder: "Describe the incident in detail including injuries, actions, list RPA, objects and personnel involved"
                                )
                                
                                FormTextField(
                                    title: "Name of Witness",
                                    text: $nameOfWitness,
                                    placeholder: "Optional"
                                )
                            }
                        }
                        
                        // Signature Section
                        FormSection(title: "Signature *") {
                            SignatureCanvasView(signatureImage: $signatureImage)
                        }
                        
                        // Submit Button
                        Button(action: {
                            showSubmitConfirmation = true
                        }) {
                            HStack {
                                if incidentLogService.isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Submit Incident Log")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canSubmit ? Color.red : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!canSubmit || incidentLogService.isSaving)
                        .padding(.horizontal)
                        .padding(.bottom)
                        
                        // Download PDF Button
                        Button(action: openPDF) {
                            HStack {
                                Image(systemName: "arrow.down.doc")
                                Text("Download PDF Template")
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationTitle("Incident Log")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .task {
            await checkExistingLog()
            prefillUserInfo()
        }
        .confirmationDialog("Submit Incident Log", isPresented: $showSubmitConfirmation) {
            Button("Submit", role: .destructive) {
                Task {
                    await submitForm()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Once submitted, this incident log cannot be modified. Are you sure you want to submit?")
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your incident log has been submitted successfully.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Computed Properties
    
    private var canSubmit: Bool {
        !name.isEmpty &&
        !phoneNumber.isEmpty &&
        !locationOfIncident.isEmpty &&
        !descriptionOfIncident.isEmpty &&
        signatureImage != nil
    }
    
    // MARK: - Helper Methods
    
    private func checkExistingLog() async {
        guard let pilotId = authService.currentUser?.id else {
            isCheckingExisting = false
            return
        }
        
        existingLog = await incidentLogService.getIncidentLog(bookingId: booking.id, pilotId: pilotId)
        isCheckingExisting = false
    }
    
    private func prefillUserInfo() {
        if let userProfile = authService.userProfile {
            if let firstName = userProfile.firstName, let lastName = userProfile.lastName {
                name = "\(firstName) \(lastName)"
            }
            phoneNumber = userProfile.phone ?? ""
        }
        
        // Prefill booking-related info
        operationName = booking.locationName
        // Do not prefill location of incident - let user enter it manually
    }
    
    private func submitForm() async {
        guard let pilotId = authService.currentUser?.id,
              let signature = signatureImage else {
            return
        }
        
        do {
            try await incidentLogService.submitIncidentLog(
                bookingId: booking.id,
                pilotId: pilotId,
                name: name,
                phoneNumber: phoneNumber,
                dateOfIncident: dateOfIncident,
                dateOfReport: dateOfReport,
                jobTitle: jobTitle.isEmpty ? nil : jobTitle,
                operationName: operationName.isEmpty ? nil : operationName,
                organization: organization.isEmpty ? nil : organization,
                pic: pic.isEmpty ? nil : pic,
                region: region.isEmpty ? nil : region,
                airspaceClass: airspaceClass.isEmpty ? nil : airspaceClass,
                reportedToPolice: reportedToPolice,
                reportedToAtc: reportedToAtc,
                locationOfIncident: locationOfIncident,
                descriptionOfIncident: descriptionOfIncident,
                nameOfWitness: nameOfWitness.isEmpty ? nil : nameOfWitness,
                signatureImage: signature
            )
            
            showSuccessAlert = true
        } catch {
            errorMessage = incidentLogService.errorMessage ?? error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func openPDF() {
        let pdfURL = URL(string: "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/SOP/UAS%20INCIDENT%20LOG.pdf")!
        UIApplication.shared.open(pdfURL)
    }
}

// MARK: - Read Only View

private struct IncidentLogReadOnlyView: View {
    let incidentLog: IncidentLog
    let booking: Booking
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Banner
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.green)
                        Text("Incident Log Submitted")
                            .font(.headline)
                    }
                    
                    Text("This incident log has been submitted and locked. It cannot be modified.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top)
                
                // Booking Info
                BookingInfoCard(booking: booking)
                    .padding(.horizontal)
                
                // All fields in read-only mode
                ReadOnlySection(title: "Basic Information") {
                    ReadOnlyField(label: "Name", value: incidentLog.name)
                    ReadOnlyField(label: "Phone Number", value: incidentLog.phoneNumber)
                    ReadOnlyField(label: "Date of Incident", value: incidentLog.dateOfIncident.formatted(date: .abbreviated, time: .shortened))
                    ReadOnlyField(label: "Date of Report", value: incidentLog.dateOfReport.formatted(date: .abbreviated, time: .shortened))
                    if let jobTitle = incidentLog.jobTitle {
                        ReadOnlyField(label: "Job Title", value: jobTitle)
                    }
                    if let operationName = incidentLog.operationName {
                        ReadOnlyField(label: "Operation Name", value: operationName)
                    }
                }
                
                ReadOnlySection(title: "Additional Details") {
                    if let organization = incidentLog.organization {
                        ReadOnlyField(label: "Organization", value: organization)
                    }
                    if let pic = incidentLog.pic {
                        ReadOnlyField(label: "PIC", value: pic)
                    }
                    if let region = incidentLog.region {
                        ReadOnlyField(label: "Region", value: region)
                    }
                    if let airspaceClass = incidentLog.airspaceClass {
                        ReadOnlyField(label: "Airspace Class", value: airspaceClass)
                    }
                    ReadOnlyField(label: "Reported to Police", value: incidentLog.reportedToPolice ? "Yes" : "No")
                    ReadOnlyField(label: "Reported to ATC", value: incidentLog.reportedToAtc ? "Yes" : "No")
                }
                
                ReadOnlySection(title: "Incident Details") {
                    ReadOnlyField(label: "Location", value: incidentLog.locationOfIncident)
                    ReadOnlyField(label: "Description", value: incidentLog.descriptionOfIncident)
                    if let witness = incidentLog.nameOfWitness {
                        ReadOnlyField(label: "Witness", value: witness)
                    }
                }
                
                // Signature
                ReadOnlySection(title: "Signature") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let signatureData = Data(base64Encoded: incidentLog.signatureData),
                           let signatureImage = UIImage(data: signatureData) {
                            Image(uiImage: signatureImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                        }
                        
                        Text("Signed on: \(incidentLog.signatureDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Download PDF Button
                Button(action: {
                    let pdfURL = URL(string: "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/SOP/UAS%20INCIDENT%20LOG.pdf")!
                    UIApplication.shared.open(pdfURL)
                }) {
                    HStack {
                        Image(systemName: "arrow.down.doc")
                        Text("Download PDF Template")
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Form Components

private struct FormSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                content
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

private struct FormTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(keyboardType)
        }
    }
}

private struct FormTextEditor: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(Color(.placeholderText))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }
                
                TextEditor(text: $text)
                    .frame(minHeight: 120)
                    .padding(4)
                    .scrollContentBackground(.hidden)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
}

private struct FormDatePicker: View {
    let title: String
    @Binding var date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct FormToggle: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(title, isOn: $isOn)
            .font(.subheadline)
    }
}

private struct BookingInfoCard: View {
    let booking: Booking
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Related Booking")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(booking.locationName)
                    .font(.headline)
            }
            
            if let scheduledDate = booking.scheduledDate {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                    Text(scheduledDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Read Only Components

private struct ReadOnlySection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                content
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

private struct ReadOnlyField: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

