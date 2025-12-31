//
//  LogsView.swift
//  Buzz
//
//  Created for Flight Logs feature
//

import SwiftUI

struct LogsView: View {
    @State private var selectedPDF: PDFSelection?
    
    // PDF URLs from Supabase Storage
    private let incidentLogURL = "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/SOP/UAS%20INCIDENT%20LOG.pdf"
    private let maintenanceLogURL = "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/SOP/UAS%20MAINTENANCE%20LOG.pdf"
    private let flightLogURL = "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/SOP/UAS%20FLIGHT%20LOG.pdf"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Flight Logs")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Track incidents, maintenance, and flight records")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
                
                // Incident Log Card - Navigate to electronic form
                NavigationLink(destination: IncidentLogBookingSelectionView()) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.15))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.purple)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Incident Log")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Document incidents, accidents, and safety events")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
                
                // Maintenance Log Card
                Button(action: {
                    selectedPDF = PDFSelection(url: maintenanceLogURL)
                }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.indigo.opacity(0.15))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.title2)
                                .foregroundColor(.indigo)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Maintenance Log")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Track repairs, replacements, and maintenance activities")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
                
                // Flight Log Card
                Button(action: {
                    selectedPDF = PDFSelection(url: flightLogURL)
                }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.cyan.opacity(0.15))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "cloud.fill")
                                .font(.title2)
                                .foregroundColor(.cyan)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Flight Log")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Record flight details, duration, and operational data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
                
                // Info Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("About Logs")
                            .font(.headline)
                    }
                    
                    Text("Flight logs help you maintain detailed records of your operations, incidents, and maintenance activities. Regular documentation ensures compliance and improves safety.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedPDF) { pdfSelection in
            NavigationView {
                FileViewer(
                    fileUrl: pdfSelection.url,
                    fileType: .pdf,
                    bucketName: "SOP"
                )
            }
        }
    }
}

// MARK: - PDF Selection Wrapper

private struct PDFSelection: Identifiable {
    let id = UUID()
    let url: String
}

