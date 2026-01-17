//
//  ExamResultUploadService.swift
//  Buzz
//
//  Service for uploading and managing test result files
//  for non-multiple-choice exams (Flight Review, ROC-A)
//

import Foundation
import Combine
import Supabase
import Storage
import UniformTypeIdentifiers

@MainActor
class ExamResultUploadService: ObservableObject {
    private let supabase = SupabaseClient.shared.client
    private let bucketName = "course-test-results"
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var uploadError: String?
    
    // MARK: - Check Test Result Status
    
    /// Check if the pilot has a test result record and return its status
    func getTestResultStatus(pilotId: UUID, testId: UUID) async throws -> TestResult? {
        let response: [TestResult] = try await supabase
            .from("test_results")
            .select()
            .eq("pilot_id", value: pilotId.uuidString)
            .eq("test_id", value: testId.uuidString)
            .execute()
            .value
        
        return response.first
    }
    
    // MARK: - Upload Files
    
    /// Upload test result files to Supabase Storage
    func uploadTestResultFiles(
        pilotId: UUID,
        testId: UUID,
        courseId: UUID,
        fileData: [(data: Data, fileName: String, mimeType: String)]
    ) async throws -> UUID {
        isUploading = true
        uploadError = nil
        uploadProgress = 0.0
        
        defer {
            isUploading = false
            uploadProgress = 0.0
        }
        
        do {
            var uploadedUrls: [String] = []
            let totalFiles = Double(fileData.count)
            
            // Upload each file
            for (index, file) in fileData.enumerated() {
                let fileName = file.fileName
                let timestamp = Int(Date().timeIntervalSince1970)
                let filePath = "\(pilotId.uuidString)/\(testId.uuidString)/\(timestamp)_\(fileName)"
                
                // Upload to Supabase Storage
                let uploadResponse = try await supabase.storage
                    .from(bucketName)
                    .upload(
                        path: filePath,
                        file: file.data,
                        options: FileOptions(
                            contentType: file.mimeType,
                            upsert: false
                        )
                    )
                
                // Get public URL
                let publicURL = try supabase.storage
                    .from(bucketName)
                    .getPublicURL(path: filePath)
                
                uploadedUrls.append(publicURL.absoluteString)
                
                // Update progress
                uploadProgress = Double(index + 1) / totalFiles
            }
            
            // Submit the test result with uploaded file URLs
            let resultId = try await submitTestResultUpload(
                pilotId: pilotId,
                testId: testId,
                courseId: courseId,
                fileUrls: uploadedUrls
            )
            
            return resultId
            
        } catch {
            uploadError = "Failed to upload files: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Submit Test Result Upload
    
    /// Submit the test result upload to the database
    private func submitTestResultUpload(
        pilotId: UUID,
        testId: UUID,
        courseId: UUID,
        fileUrls: [String]
    ) async throws -> UUID {
        // Call the database function to submit the upload
        let response = try await supabase.rpc(
            "submit_test_result_upload",
            params: [
                "p_pilot_id": AnyJSON.string(pilotId.uuidString),
                "p_test_id": AnyJSON.string(testId.uuidString),
                "p_course_id": AnyJSON.string(courseId.uuidString),
                "p_file_urls": AnyJSON.array(fileUrls.map { AnyJSON.string($0) })
            ]
        ).execute()
        
        let data = response.data
        guard let jsonString = String(data: data, encoding: .utf8),
              let resultId = UUID(uuidString: jsonString.trimmingCharacters(in: CharacterSet(charactersIn: "\""))) else {
            throw NSError(domain: "ExamResultUploadService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse result ID from response"
            ])
        }
        
        return resultId
    }
    
    // MARK: - Delete Uploaded Files
    
    /// Delete uploaded files from storage (if user wants to re-upload)
    func deleteTestResultFiles(fileUrls: [String]) async throws {
        for urlString in fileUrls {
            guard let url = URL(string: urlString) else { continue }
            
            // Extract the file path from the URL
            let pathComponents = url.pathComponents
            guard let bucketIndex = pathComponents.firstIndex(of: bucketName),
                  pathComponents.count > bucketIndex + 1 else {
                continue
            }
            
            let filePath = pathComponents[(bucketIndex + 1)...].joined(separator: "/")
            
            // Delete from storage
            try await supabase.storage
                .from(bucketName)
                .remove(paths: [filePath])
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get MIME type from file extension
    static func getMimeType(for fileName: String) -> String {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        
        switch fileExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "pdf":
            return "application/pdf"
        case "heic":
            return "image/heic"
        case "heif":
            return "image/heif"
        default:
            return "application/octet-stream"
        }
    }
    
    /// Validate file before upload
    static func validateFile(data: Data, fileName: String) throws {
        // Check file size (max 10MB)
        let maxSize = 10 * 1024 * 1024 // 10MB
        guard data.count <= maxSize else {
            throw NSError(domain: "ExamResultUploadService", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "File size exceeds 10MB limit"
            ])
        }
        
        // Check file type
        let allowedExtensions = ["jpg", "jpeg", "png", "pdf", "heic", "heif"]
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        guard allowedExtensions.contains(fileExtension) else {
            throw NSError(domain: "ExamResultUploadService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "File type not supported. Please upload JPG, PNG, PDF, or HEIC files."
            ])
        }
    }
}
