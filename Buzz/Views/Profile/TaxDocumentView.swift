//
//  TaxDocumentView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct TaxDocumentView: View {
    @EnvironmentObject var authService: AuthService
    @State private var taxDocuments: [TaxDocument] = []
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if taxDocuments.isEmpty {
                EmptyStateView(
                    icon: "doc.text.fill",
                    title: "No Tax Documents",
                    message: "Your tax documents will appear here once they are issued."
                )
            } else {
                List {
                    ForEach(groupedDocuments.keys.sorted(by: >), id: \.self) { year in
                        Section(header: Text("\(year)")) {
                            ForEach(groupedDocuments[year] ?? []) { document in
                                NavigationLink(destination: TaxDocumentDetailView(document: document)) {
                                    TaxDocumentRow(document: document)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Tax Documents")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            await loadTaxDocuments()
        }
        .refreshable {
            await loadTaxDocuments()
        }
    }
    
    private var groupedDocuments: [Int: [TaxDocument]] {
        Dictionary(grouping: taxDocuments) { $0.year }
    }
    
    private func loadTaxDocuments() async {
        guard let currentUser = authService.currentUser else { return }
        
        isLoading = true
        do {
            // TODO: Implement TaxDocumentService to fetch from Supabase
            // For now, return empty array
            taxDocuments = []
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Tax Document Row

struct TaxDocumentRow: View {
    let document: TaxDocument
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "doc.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.documentType.displayName)
                    .font(.headline)
                
                Text(document.issuedAt, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Tax Document Detail View

struct TaxDocumentDetailView: View {
    let document: TaxDocument
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 24) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(document.documentType.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Tax Year \(document.year)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Issued:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(document.issuedAt, style: .date)
                        }
                        
                        HStack {
                            Text("Type:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(document.documentType.displayName)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        openDocument()
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download Document")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Tax Document")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func openDocument() {
        guard let url = URL(string: document.fileUrl) else {
            errorMessage = "Invalid document URL"
            showError = true
            return
        }
        
        UIApplication.shared.open(url)
    }
}

