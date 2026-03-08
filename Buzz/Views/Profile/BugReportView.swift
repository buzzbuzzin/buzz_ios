//
//  BugReportView.swift
//  Buzz
//
//  Created by Claude on 3/7/26.
//

import SwiftUI
import PhotosUI

// MARK: - Ticket Report List View

struct TicketReportListView: View {
    var reportType: TicketReportType = .bug
    @StateObject private var reportService = TicketReportService()
    @State private var showCreateSheet = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if reportService.isLoading {
                    LoadingView(message: reportType.loadingMessage)
                } else if reportService.reports.isEmpty {
                    EmptyStateView(
                        icon: reportType.icon,
                        title: reportType.emptyStateTitle,
                        message: reportType.emptyStateMessage
                    )
                } else {
                    List(reportService.reports) { report in
                        NavigationLink(destination: TicketReportDetailView(report: report, reportType: reportType)) {
                            TicketReportRowView(report: report)
                        }
                    }
                    .refreshable {
                        await reportService.fetchMyReports(type: reportType)
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
        .navigationTitle(reportType.listTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reportService.fetchMyReports(type: reportType)
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateTicketReportView(reportService: reportService, reportType: reportType)
        }
    }
}

// MARK: - Ticket Report Row View

struct TicketReportRowView: View {
    let report: TicketReport

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(report.title)
                    .font(.headline)
                Spacer()
                TicketReportStatusBadge(status: report.status)
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

// MARK: - Ticket Report Status Badge

struct TicketReportStatusBadge: View {
    let status: TicketReportStatus

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

// MARK: - Ticket Report Detail View

struct TicketReportDetailView: View {
    let report: TicketReport
    var reportType: TicketReportType = .bug

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status Badge
                HStack {
                    Text("Status")
                        .font(.headline)
                    Spacer()
                    TicketReportStatusBadge(status: report.status)
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                // Title
                VStack(alignment: .leading, spacing: 8) {
                    Label("Title", systemImage: reportType.icon)
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
        .navigationTitle(reportType.detailTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Create Ticket Report View

struct CreateTicketReportView: View {
    @ObservedObject var reportService: TicketReportService
    var reportType: TicketReportType = .bug
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

                    TextField(reportType.titlePlaceholder, text: $title)
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
                            Text(reportType.descriptionPlaceholder)
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
                    title: reportType.submitButtonTitle,
                    action: submitReport,
                    isLoading: isSubmitting,
                    isDisabled: isSubmitting || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .navigationTitle(reportType.createTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(reportType.successAlertTitle, isPresented: $showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text(reportType.successAlertMessage)
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task(id: selectedPhotos.count) {
                var images: [UIImage] = []
                for item in selectedPhotos.prefix(4) {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                selectedImages = images
            }
        }
    }

    private func removeImage(at index: Int) {
        guard index < selectedImages.count, index < selectedPhotos.count else { return }
        selectedPhotos.remove(at: index)
    }

    private func submitReport() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isSubmitting = true

        Task {
            do {
                _ = try await reportService.submitReport(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: reportType,
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
