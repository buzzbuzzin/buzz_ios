//
//  ExamResultUploadServiceTests.swift
//  BuzzTests
//
//  Tests for ExamResultUploadService static helper methods.
//

import XCTest
@testable import Buzz

@MainActor
final class ExamResultUploadServiceTests: XCTestCase {

    // MARK: - getMimeType

    func testGetMimeType_jpg() {
        XCTAssertEqual(ExamResultUploadService.getMimeType(for: "photo.jpg"), "image/jpeg")
    }

    func testGetMimeType_jpeg() {
        XCTAssertEqual(ExamResultUploadService.getMimeType(for: "photo.jpeg"), "image/jpeg")
    }

    func testGetMimeType_png() {
        XCTAssertEqual(ExamResultUploadService.getMimeType(for: "image.png"), "image/png")
    }

    func testGetMimeType_pdf() {
        XCTAssertEqual(ExamResultUploadService.getMimeType(for: "document.pdf"), "application/pdf")
    }

    func testGetMimeType_heic() {
        XCTAssertEqual(ExamResultUploadService.getMimeType(for: "photo.heic"), "image/heic")
    }

    func testGetMimeType_heif() {
        XCTAssertEqual(ExamResultUploadService.getMimeType(for: "photo.heif"), "image/heif")
    }

    func testGetMimeType_unknown() {
        XCTAssertEqual(ExamResultUploadService.getMimeType(for: "file.xyz"), "application/octet-stream")
    }

    func testGetMimeType_noExtension() {
        XCTAssertEqual(ExamResultUploadService.getMimeType(for: "noextension"), "application/octet-stream")
    }

    func testGetMimeType_uppercaseExtension() {
        XCTAssertEqual(ExamResultUploadService.getMimeType(for: "PHOTO.JPG"), "image/jpeg")
    }

    // MARK: - validateFile

    func testValidateFile_smallJpeg() {
        let data = Data(repeating: 0, count: 1024)
        XCTAssertNoThrow(try ExamResultUploadService.validateFile(data: data, fileName: "photo.jpg"))
    }

    func testValidateFile_validPdf() {
        let data = Data(repeating: 0, count: 1024)
        XCTAssertNoThrow(try ExamResultUploadService.validateFile(data: data, fileName: "document.pdf"))
    }

    func testValidateFile_exactlyAtLimit() {
        let data = Data(repeating: 0, count: 10 * 1024 * 1024)
        XCTAssertNoThrow(try ExamResultUploadService.validateFile(data: data, fileName: "photo.jpg"))
    }

    func testValidateFile_exceedsLimit() {
        let data = Data(repeating: 0, count: 10 * 1024 * 1024 + 1)
        XCTAssertThrowsError(try ExamResultUploadService.validateFile(data: data, fileName: "photo.jpg")) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "ExamResultUploadService")
            XCTAssertEqual(nsError.code, 2)
        }
    }

    func testValidateFile_unsupportedTxt() {
        let data = Data(repeating: 0, count: 100)
        XCTAssertThrowsError(try ExamResultUploadService.validateFile(data: data, fileName: "notes.txt")) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "ExamResultUploadService")
            XCTAssertEqual(nsError.code, 3)
        }
    }

    func testValidateFile_unsupportedDoc() {
        let data = Data(repeating: 0, count: 100)
        XCTAssertThrowsError(try ExamResultUploadService.validateFile(data: data, fileName: "report.doc")) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "ExamResultUploadService")
            XCTAssertEqual(nsError.code, 3)
        }
    }

    func testValidateFile_validHeic() {
        let data = Data(repeating: 0, count: 2048)
        XCTAssertNoThrow(try ExamResultUploadService.validateFile(data: data, fileName: "photo.heic"))
    }

    func testValidateFile_emptyData() {
        let data = Data()
        XCTAssertNoThrow(try ExamResultUploadService.validateFile(data: data, fileName: "photo.png"))
    }
}
