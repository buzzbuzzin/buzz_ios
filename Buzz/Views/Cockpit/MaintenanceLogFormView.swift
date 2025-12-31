//
//  MaintenanceLogFormView.swift
//  Buzz
//
//  Created for electronic maintenance log form
//

import SwiftUI
import Auth

struct MaintenanceLogFormView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var maintenanceLogService = MaintenanceLogService()
    @Environment(\.dismiss) private var dismiss
    
    // Form fields
    @State private var aircraftNumber: String = ""
    @State private var date = Date()
    @State private var repairs: String = ""
    @State private var replacementParts: String = ""
    @State private var comments: String = ""
    
    // Initials (signature)
    @State private var initialsImage: UIImage?
    
    // UI State
    @State private var showSubmitConfirmation = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showPreviousLogs = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Maintenance Log Entry")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Document repairs, replacements, and maintenance activities for your UAS. All fields marked with * are required.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
                
                // Previous Logs Button
                Button(action: {
                    showPreviousLogs = true
                }) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("View Previous Maintenance Logs")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.indigo)
                    .padding()
                    .background(Color.indigo.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Aircraft Information Section
                MaintenanceFormSection(title: "Aircraft Information") {
                    VStack(spacing: 16) {
                        MaintenanceFormTextField(
                            title: "Aircraft # *",
                            text: $aircraftNumber,
                            placeholder: "e.g., N12345 or Serial Number"
                        )
                        
                        MaintenanceFormDatePicker(
                            title: "Date *",
                            date: $date
                        )
                    }
                }
                
                // Maintenance Details Section
                MaintenanceFormSection(title: "Maintenance Details") {
                    VStack(spacing: 16) {
                        MaintenanceFormTextEditor(
                            title: "Repairs *",
                            text: $repairs,
                            placeholder: "Describe the repairs performed on the aircraft"
                        )
                        
                        MaintenanceFormTextEditor(
                            title: "Replacement Parts",
                            text: $replacementParts,
                            placeholder: "List any parts that were replaced (optional)"
                        )
                        
                        MaintenanceFormTextEditor(
                            title: "Comments",
                            text: $comments,
                            placeholder: "Additional notes or observations (optional)"
                        )
                    }
                }
                
                // Initials Section
                MaintenanceFormSection(title: "Initials *") {
                    SignatureCanvasView(signatureImage: $initialsImage)
                }
                
                // Submit Button
                Button(action: {
                    showSubmitConfirmation = true
                }) {
                    HStack {
                        if maintenanceLogService.isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Submit Maintenance Log")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSubmit ? Color.indigo : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!canSubmit || maintenanceLogService.isSaving)
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
        .navigationTitle("Maintenance Log")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .confirmationDialog("Submit Maintenance Log", isPresented: $showSubmitConfirmation) {
            Button("Submit", role: .destructive) {
                Task {
                    await submitForm()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Once submitted, this maintenance log entry cannot be modified. Are you sure you want to submit?")
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your maintenance log has been submitted successfully.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showPreviousLogs) {
            NavigationView {
                MaintenanceLogHistoryView()
                    .environmentObject(authService)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var canSubmit: Bool {
        !aircraftNumber.isEmpty &&
        !repairs.isEmpty &&
        initialsImage != nil
    }
    
    // MARK: - Helper Methods
    
    private func submitForm() async {
        guard let pilotId = authService.currentUser?.id,
              let initials = initialsImage else {
            return
        }
        
        do {
            try await maintenanceLogService.submitMaintenanceLog(
                pilotId: pilotId,
                aircraftNumber: aircraftNumber,
                date: date,
                repairs: repairs,
                replacementParts: replacementParts.isEmpty ? nil : replacementParts,
                comments: comments.isEmpty ? nil : comments,
                initialsImage: initials
            )
            
            showSuccessAlert = true
        } catch {
            errorMessage = maintenanceLogService.errorMessage ?? error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func openPDF() {
        let pdfURL = URL(string: "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/SOP/UAS%20MAINTENANCE%20LOG.pdf")!
        UIApplication.shared.open(pdfURL)
    }
}

// MARK: - Previous Logs History View

struct MaintenanceLogHistoryView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var maintenanceLogService = MaintenanceLogService()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if maintenanceLogService.isLoading {
                ProgressView("Loading...")
            } else if maintenanceLogService.maintenanceLogs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Maintenance Logs")
                        .font(.headline)
                    Text("Your submitted maintenance logs will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(maintenanceLogService.maintenanceLogs) { log in
                            MaintenanceLogCard(log: log)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Maintenance History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .task {
            if let pilotId = authService.currentUser?.id {
                await maintenanceLogService.fetchMaintenanceLogs(pilotId: pilotId)
            }
        }
    }
}

private struct MaintenanceLogCard: View {
    let log: MaintenanceLog
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aircraft: \(log.aircraftNumber)")
                        .font(.headline)
                    Text("Sheet #\(log.sheetNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(log.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Repairs:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(log.repairs)
                    .font(.subheadline)
                    .lineLimit(3)
            }
            
            if let parts = log.replacementParts, !parts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Replacement Parts:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(parts)
                        .font(.subheadline)
                        .lineLimit(2)
                }
            }
            
            HStack {
                if let initialsData = Data(base64Encoded: log.initialsData),
                   let initialsImage = UIImage(data: initialsData) {
                    Image(uiImage: initialsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 30)
                        .background(Color(.systemBackground))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Image(systemName: "lock.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Form Components

private struct MaintenanceFormSection<Content: View>: View {
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

private struct MaintenanceFormTextField: View {
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

private struct MaintenanceFormTextEditor: View {
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
                    .frame(minHeight: 80)
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

private struct MaintenanceFormDatePicker: View {
    let title: String
    @Binding var date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            DatePicker("", selection: $date, displayedComponents: [.date])
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

