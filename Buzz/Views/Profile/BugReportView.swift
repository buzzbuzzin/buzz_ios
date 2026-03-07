//
//  BugReportView.swift
//  Buzz
//
//  Created by Claude on 3/7/26.
//

import SwiftUI
import PhotosUI

// MARK: - Bug Report List View

struct BugReportListView: View {
    @StateObject private var bugReportService = BugReportService()
    @State private var showCreateSheet = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if bugReportService.isLoading {
                    LoadingView(message: "Loading bug reports...")
                } else if bugReportService.bugReports.isEmpty {
                    EmptyStateView(
                        icon: "ladybug.fill",
                        title: "No Bug Reports",
                        message: "You haven't submitted any bug reports yet"
                    )
                } else {
                    List(bugReportService.bugReports) { report in
                        NavigationLink(destination: BugReportDetailView(report: report)) {
                            BugReportRowView(report: report)
                        }
                    }
                    .refreshable {
                        await bugReportService.fetchMyReports()
                    }
                }
            }

            // FAB
            Button(action: { showCreateSheet = true }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .padding(20)
        }
        .navigationTitle("Bug Reports")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await bugReportService.fetchMyReports()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateBugReportView(bugReportService: bugReportService)
        }
    }
}

// MARK: - Bug Report Row View

struct BugReportRowView: View {
    let report: BugReport

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(report.title)
                    .font(.headline)
                Spacer()
                BugReportStatusBadge(status: report.status)
            }

            HStack {
                Text(report.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                if !report.imageUrls.isEmpty {
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "paperclip")
                        Text("\(report.imageUrls.count)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            Text(report.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Bug Report Status Badge

struct BugReportStatusBadge: View {
    let status: BugReportStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .cornerRadius(6)
    }
}

// MARK: - Bug Report Detail View

struct BugReportDetailView: View {
    let report: BugReport

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status Badge
                HStack {
                    Text("Status")
                        .font(.headline)
                    Spacer()
                    BugReportStatusBadge(status: report.status)
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                // Title
                VStack(alignment: .leading, spacing: 8) {
                    Label("Title", systemImage: "ladybug.fill")
                        .font(.headline)
                    Text(report.title)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Label("Description", systemImage: "text.alignleft")
                        .font(.headline)
                    Text(report.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                // Screenshots
                if !report.imageUrls.isEmpty {
                    Divider()
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Screenshots", systemImage: "photo.on.rectangle")
                            .font(.headline)
                        HangerImageCarousel(imageUrls: report.imageUrls, height: 240)
                    }
                    .padding(.horizontal)
                }

                // Admin Response
                if let adminResponse = report.adminResponse, !adminResponse.isEmpty {
                    Divider()
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Admin Response", systemImage: "arrowshape.turn.up.left.fill")
                            .font(.headline)
                        Text(adminResponse)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }

                Divider()
                    .padding(.horizontal)

                // Timeline
                VStack(alignment: .leading, spacing: 16) {
                    Label("Timeline", systemImage: "clock.fill")
                        .font(.headline)

                    TimelineRow(
                        icon: "circle.fill",
                        color: .blue,
                        title: "Report Filed",
                        date: report.createdAt,
                        isActive: true
                    )

                    TimelineRow(
                        icon: report.status == .inProgress || report.status == .resolved || report.status == .closed ? "circle.fill" : "circle",
                        color: .blue,
                        title: "In Progress",
                        date: nil,
                        isActive: report.status == .inProgress || report.status == .resolved || report.status == .closed
                    )

                    if report.status == .resolved {
                        TimelineRow(
                            icon: "checkmark.circle.fill",
                            color: .green,
                            title: "Resolved",
                            date: report.updatedAt,
                            isActive: true
                        )
                    } else if report.status == .closed {
                        TimelineRow(
                            icon: "xmark.circle.fill",
                            color: .gray,
                            title: "Closed",
                            date: report.updatedAt,
                            isActive: true
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Bug Report Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Create Bug Report View

struct CreateBugReportView: View {
    @ObservedObject var bugReportService: BugReportService
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                // Title Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("Brief description of the bug", text: $title)
                        .textContentType(.none)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }

                // Description Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("Please describe the bug in detail, including steps to reproduce...")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }

                        TextEditor(text: $description)
                            .frame(minHeight: 150)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }

                // Photos
                VStack(alignment: .leading, spacing: 8) {
                    Text("Screenshots")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 120, height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))

                                        Button {
                                            removeImage(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundColor(.white)
                                                .shadow(radius: 2)
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }
                            }
                        }
                    }

                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 4,
                        matching: .images
                    ) {
                        Label("Add Screenshots (\(selectedImages.count)/4)", systemImage: "photo")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }

                Spacer()

                CustomButton(
                    title: "Submit Bug Report",
                    action: submitReport,
                    isLoading: isSubmitting,
                    isDisabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .navigationTitle("Report a Bug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Bug Report Submitted", isPresented: $showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("Thank you for your report. We'll look into it and get back to you.")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onChange(of: selectedPhotos) { newItems in
                Task {
                    var images: [UIImage] = []
                    for item in newItems.prefix(4) {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            images.append(image)
                        }
                    }
                    selectedImages = images
                }
            }
        }
    }

    private func removeImage(at index: Int) {
        guard index < selectedImages.count else { return }
        selectedImages.remove(at: index)
        if index < selectedPhotos.count {
            selectedPhotos.remove(at: index)
        }
    }

    private func submitReport() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isSubmitting = true

        Task {
            do {
                _ = try await bugReportService.submitReport(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    images: selectedImages
                )
                isSubmitting = false
                showSuccessAlert = true
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
}
