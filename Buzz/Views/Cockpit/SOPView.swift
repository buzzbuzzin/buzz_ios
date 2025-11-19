//
//  SOPView.swift
//  Buzz
//
//  Created for Standard Operating Procedures (SOP) feature
//

import SwiftUI

struct SOPView: View {
    @State private var selectedPDF: PDFSelection?
    
    // PDF URLs from Supabase Storage
    private let normalProceduresURL = "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/SOP/UAS%20NORMAL%20PROCEDURES.pdf"
    private let emergencyProceduresURL = "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/SOP/UAS%20EMERGENCY%20PROCEDURES.pdf"
    private let importantPhoneNumbersURL = "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/SOP/UAS%20IMPORTANT%20PHONE%20NUMBERS.pdf"
    private let radioScriptURL = "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/SOP/UAS%20RADIO%20SCRIPT.pdf"
    private let incidentLogURL = "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/SOP/UAS%20INCIDENT%20LOG.pdf"
    private let maintenanceLogURL = "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/SOP/UAS%20MAINTENANCE%20LOG.pdf"
    private let flightLogURL = "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/SOP/UAS%20FLIGHT%20LOG.pdf"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Standard Operating Procedures")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Access important flight procedures and emergency protocols")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
                
                // Normal Procedures Card
                Button(action: {
                    selectedPDF = PDFSelection(url: normalProceduresURL)
                }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "book.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Normal Procedures")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Preflight checklists, take-off, landing, and standard operations")
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
                
                // Emergency Procedures Card
                Button(action: {
                    selectedPDF = PDFSelection(url: emergencyProceduresURL)
                }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.15))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Emergency Procedures")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Emergency protocols, fly-away procedures, and safety measures")
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
                
                // Reference Documents Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reference Documents")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                    
                    // Important Phone Numbers Card
                    Button(action: {
                        selectedPDF = PDFSelection(url: importantPhoneNumbersURL)
                    }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "phone.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Important Phone Numbers")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Aviation emergency contacts and ARTCC phone numbers")
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
                    
                    // Radio Script Card
                    Button(action: {
                        selectedPDF = PDFSelection(url: radioScriptURL)
                    }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Radio Script")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Standard radio communication scripts and procedures")
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
                }
                .padding(.top, 8)
                
                // Logs Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Logs & Documentation")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                    
                    // Incident Log Card
                    Button(action: {
                        selectedPDF = PDFSelection(url: incidentLogURL)
                    }) {
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
                }
                .padding(.top, 8)
                
                // Info Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("About SOP")
                            .font(.headline)
                    }
                    
                    Text("Standard Operating Procedures (SOP) provide essential guidelines for safe and efficient drone operations. Review these documents regularly to ensure compliance and safety.")
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
        .navigationTitle("SOP")
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

