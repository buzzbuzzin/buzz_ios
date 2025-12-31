//
//  FlightLogFormView.swift
//  Buzz
//
//  Created for electronic flight log form
//

import SwiftUI
import Auth

struct FlightLogFormView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var flightLogService = FlightLogService()
    @Environment(\.dismiss) private var dismiss
    
    // Form fields
    @State private var aircraftNumber: String = ""
    @State private var descriptionOfFlight: String = ""
    @State private var date = Date()
    @State private var timeOut = Date()
    @State private var timeIn = Date()
    @State private var comments: String = ""
    
    // Signature
    @State private var signatureImage: UIImage?
    
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
                    Text("Flight Log Entry")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Record flight details, duration, and operational data for your UAS. All fields marked with * are required.")
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
                        Text("View Previous Flight Logs")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.cyan)
                    .padding()
                    .background(Color.cyan.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Aircraft Information Section
                FlightFormSection(title: "Aircraft Information") {
                    VStack(spacing: 16) {
                        FlightFormTextField(
                            title: "Aircraft # *",
                            text: $aircraftNumber,
                            placeholder: "e.g., N12345 or Serial Number"
                        )
                    }
                }
                
                // Flight Details Section
                FlightFormSection(title: "Flight Details") {
                    VStack(spacing: 16) {
                        FlightFormTextEditor(
                            title: "Description of Flight *",
                            text: $descriptionOfFlight,
                            placeholder: "Describe the purpose and nature of the flight"
                        )
                        
                        FlightFormDatePicker(
                            title: "Date *",
                            date: $date
                        )
                        
                        FlightFormTimePicker(
                            title: "Time Out *",
                            time: $timeOut
                        )
                        
                        FlightFormTimePicker(
                            title: "Time In *",
                            time: $timeIn
                        )
                        
                        // Total Airtime Display
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Total Airtime")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(formattedTotalAirtime)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(totalAirtimeMinutes >= 0 ? .primary : .red)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        FlightFormTextEditor(
                            title: "Comments",
                            text: $comments,
                            placeholder: "Additional notes or observations (optional)"
                        )
                    }
                }
                
                // Signature Section
                FlightFormSection(title: "Pilot Signature *") {
                    SignatureCanvasView(signatureImage: $signatureImage)
                }
                
                // Submit Button
                Button(action: {
                    showSubmitConfirmation = true
                }) {
                    HStack {
                        if flightLogService.isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Submit Flight Log")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSubmit ? Color.cyan : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!canSubmit || flightLogService.isSaving)
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
        .navigationTitle("Flight Log")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .confirmationDialog("Submit Flight Log", isPresented: $showSubmitConfirmation) {
            Button("Submit", role: .destructive) {
                Task {
                    await submitForm()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Once submitted, this flight log entry cannot be modified. Are you sure you want to submit?")
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your flight log has been submitted successfully.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showPreviousLogs) {
            NavigationView {
                FlightLogHistoryView()
                    .environmentObject(authService)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var totalAirtimeMinutes: Int {
        let interval = timeIn.timeIntervalSince(timeOut)
        return max(0, Int(interval / 60))
    }
    
    private var formattedTotalAirtime: String {
        if totalAirtimeMinutes < 0 {
            return "Invalid (Out > In)"
        }
        let hours = totalAirtimeMinutes / 60
        let minutes = totalAirtimeMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var canSubmit: Bool {
        !aircraftNumber.isEmpty &&
        !descriptionOfFlight.isEmpty &&
        totalAirtimeMinutes >= 0 &&
        signatureImage != nil
    }
    
    // MARK: - Helper Methods
    
    private func submitForm() async {
        guard let pilotId = authService.currentUser?.id,
              let signature = signatureImage else {
            return
        }
        
        do {
            try await flightLogService.submitFlightLog(
                pilotId: pilotId,
                aircraftNumber: aircraftNumber,
                descriptionOfFlight: descriptionOfFlight,
                date: date,
                timeOut: timeOut,
                timeIn: timeIn,
                totalAirtimeMinutes: totalAirtimeMinutes,
                comments: comments.isEmpty ? nil : comments,
                signatureImage: signature
            )
            
            showSuccessAlert = true
        } catch {
            errorMessage = flightLogService.errorMessage ?? error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func openPDF() {
        let pdfURL = URL(string: "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/SOP/UAS%20FLIGHT%20LOG.pdf")!
        UIApplication.shared.open(pdfURL)
    }
}

// MARK: - Previous Logs History View

struct FlightLogHistoryView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var flightLogService = FlightLogService()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if flightLogService.isLoading {
                ProgressView("Loading...")
            } else if flightLogService.flightLogs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "airplane")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Flight Logs")
                        .font(.headline)
                    Text("Your submitted flight logs will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(flightLogService.flightLogs) { log in
                            FlightLogCard(log: log)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Flight History")
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
                await flightLogService.fetchFlightLogs(pilotId: pilotId)
            }
        }
    }
}

private struct FlightLogCard: View {
    let log: FlightLog
    
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
                Text("Description:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(log.descriptionOfFlight)
                    .font(.subheadline)
                    .lineLimit(3)
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Out")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(log.timeOut.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("In")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(log.timeIn.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(log.formattedTotalAirtime)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.cyan)
                }
                
                Spacer()
            }
            
            HStack {
                if let signatureData = Data(base64Encoded: log.signatureData),
                   let signatureImage = UIImage(data: signatureData) {
                    Image(uiImage: signatureImage)
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

private struct FlightFormSection<Content: View>: View {
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

private struct FlightFormTextField: View {
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

private struct FlightFormTextEditor: View {
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

private struct FlightFormDatePicker: View {
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

private struct FlightFormTimePicker: View {
    let title: String
    @Binding var time: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            DatePicker("", selection: $time, displayedComponents: [.hourAndMinute])
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

