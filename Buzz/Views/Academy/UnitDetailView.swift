//
//  UnitDetailView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/14/25.
//

import SwiftUI

struct UnitDetailView: View {
    let unit: CourseUnit
    let course: TrainingCourse
    @State private var showPDFViewer = false
    @State private var selectedPDFUrl: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Unit Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        // Unit Number Badge
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 60, height: 60)
                            
                            Text("\(unit.unitNumber)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(unit.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if unit.isMandatory {
                                Text("Mandatory")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(6)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    if let description = unit.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // PDF Course Material Buttons (multiple modules per unit)
                if !unit.pdfUrls.isEmpty {
                    VStack(spacing: 12) {
                        Text("Course Material PDFs")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ForEach(Array(unit.pdfUrls.enumerated()), id: \.offset) { index, pdfUrl in
                            Button(action: {
                                selectedPDFUrl = pdfUrl
                                showPDFViewer = true
                            }) {
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .font(.title3)
                                    Text("Module \(index + 1)")
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .sheet(isPresented: $showPDFViewer) {
                        if let pdfUrl = selectedPDFUrl {
                            NavigationView {
                                FileViewer(
                                    fileUrl: pdfUrl,
                                    fileType: .pdf,
                                    bucketName: "course-materials"
                                )
                            }
                        }
                    }
                }
                
                // Course Material Content (text content)
                if let content = unit.content, !content.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Course Material")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(content)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else if unit.pdfUrls.isEmpty {
                    // Placeholder content (only show if no PDF)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Course Material")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Course material for \(unit.title) will be available here. This section will contain detailed lessons, videos, readings, and assessments.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Course Info Footer
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "book.fill")
                            .foregroundColor(.blue)
                        Text("Course: \(course.title)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let stepNumber = unit.stepNumber {
                        HStack {
                            Image(systemName: "list.number")
                                .foregroundColor(.blue)
                            Text("Step \(stepNumber)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Unit \(unit.unitNumber)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

