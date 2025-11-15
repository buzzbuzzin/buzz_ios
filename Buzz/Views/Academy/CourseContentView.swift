//
//  CourseContentView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/14/25.
//

import SwiftUI

struct CourseContentView: View {
    let course: TrainingCourse
    @StateObject private var academyService = AcademyService()
    @State private var units: [CourseUnit] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var mandatoryUnits: [CourseUnit] {
        units.filter { $0.isMandatory }
    }
    
    var step1Units: [CourseUnit] {
        units.filter { $0.stepNumber == 1 }
    }
    
    var step2Units: [CourseUnit] {
        units.filter { $0.stepNumber == 2 }
    }
    
    var step3Units: [CourseUnit] {
        units.filter { $0.stepNumber == 3 }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Course Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(course.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(course.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    // Mandatory Units Section
                    if !mandatoryUnits.isEmpty {
                        SectionView(
                            title: "MANDATORY UNITS",
                            units: mandatoryUnits,
                            course: course
                        )
                    }
                    
                    // Step 1: Pick a Base Program
                    if !step1Units.isEmpty {
                        StepSectionView(
                            stepNumber: 1,
                            title: "PICK A BASE PROGRAM",
                            units: step1Units,
                            course: course
                        )
                    }
                    
                    // Step 2: Extension Courses
                    if !step2Units.isEmpty {
                        StepSectionView(
                            stepNumber: 2,
                            title: "EXTENSION COURSES",
                            units: step2Units,
                            course: course
                        )
                    }
                    
                    // Step 3: Further Your Base Training
                    if !step3Units.isEmpty {
                        StepSectionView(
                            stepNumber: 3,
                            title: "FURTHER YOUR BASE TRAINING",
                            units: step3Units,
                            course: course
                        )
                    }
                }
            }
        }
        .navigationTitle("Course Content")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadUnits()
        }
    }
    
    private func loadUnits() async {
        isLoading = true
        errorMessage = nil
        
        do {
            units = try await academyService.fetchCourseUnits(courseId: course.id)
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading course units: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Section View

struct SectionView: View {
    let title: String
    let units: [CourseUnit]
    let course: TrainingCourse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(units) { unit in
                    NavigationLink(destination: UnitDetailView(unit: unit, course: course)) {
                        UnitRow(unit: unit)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Step Section View

struct StepSectionView: View {
    let stepNumber: Int
    let title: String
    let units: [CourseUnit]
    let course: TrainingCourse
    
    var stepColor: Color {
        switch stepNumber {
        case 1: return .red
        case 2: return .blue
        case 3: return .black
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(units) { unit in
                    NavigationLink(destination: UnitDetailView(unit: unit, course: course)) {
                        UnitRow(unit: unit)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Unit Row

struct UnitRow: View {
    let unit: CourseUnit
    
    var body: some View {
        HStack(spacing: 16) {
            // Unit Number Badge
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text("\(unit.unitNumber)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(unit.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let description = unit.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

