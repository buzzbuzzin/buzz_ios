//
//  TrainingCourseModelTests.swift
//  BuzzTests
//
//  Tests for TrainingCourse enums and RecurrentTrainingNotice.
//

import XCTest
import SwiftUI
@testable import Buzz

final class TrainingCourseModelTests: XCTestCase {

    // MARK: - CourseLevel Enum

    func testCourseLevelRawValues() {
        XCTAssertEqual(TrainingCourse.CourseLevel.beginner.rawValue, "Beginner")
        XCTAssertEqual(TrainingCourse.CourseLevel.intermediate.rawValue, "Intermediate")
        XCTAssertEqual(TrainingCourse.CourseLevel.advanced.rawValue, "Advanced")
    }

    // MARK: - CourseCategory Enum

    func testCourseCategoryRawValues() {
        XCTAssertEqual(TrainingCourse.CourseCategory.mandatory.rawValue, "Mandatory")
        XCTAssertEqual(TrainingCourse.CourseCategory.extensions.rawValue, "Extension")
        XCTAssertEqual(TrainingCourse.CourseCategory.intermediate.rawValue, "Intermediate")
        XCTAssertEqual(TrainingCourse.CourseCategory.advanced.rawValue, "Advanced")
        XCTAssertEqual(TrainingCourse.CourseCategory.specialized.rawValue, "Specialized")
    }

    func testCourseCategoryIcons() {
        let allCategories: [TrainingCourse.CourseCategory] = [
            .mandatory, .extensions, .intermediate, .advanced, .specialized
        ]
        for category in allCategories {
            XCTAssertFalse(category.icon.isEmpty, "\(category) has empty icon")
        }
    }

    // MARK: - CourseProvider Enum

    func testCourseProviderRawValues() {
        XCTAssertEqual(TrainingCourse.CourseProvider.buzz.rawValue, "Buzz")
        XCTAssertEqual(TrainingCourse.CourseProvider.redCross.rawValue, "Red Cross")
        XCTAssertEqual(TrainingCourse.CourseProvider.usfa.rawValue, "USFA")
        XCTAssertEqual(TrainingCourse.CourseProvider.fema.rawValue, "FEMA")
        XCTAssertEqual(TrainingCourse.CourseProvider.amazon.rawValue, "Amazon")
        XCTAssertEqual(TrainingCourse.CourseProvider.tmobile.rawValue, "T-Mobile")
        XCTAssertEqual(TrainingCourse.CourseProvider.other.rawValue, "Other")
    }

    func testCourseProviderIcons() {
        let allProviders: [TrainingCourse.CourseProvider] = [
            .buzz, .redCross, .usfa, .fema, .amazon, .tmobile, .other
        ]
        for provider in allProviders {
            XCTAssertFalse(provider.icon.isEmpty, "\(provider) has empty icon")
        }
    }

    // MARK: - CourseRegion Enum

    func testCourseRegionRawValues() {
        XCTAssertEqual(TrainingCourse.CourseRegion.canada.rawValue, "Canada")
        XCTAssertEqual(TrainingCourse.CourseRegion.usa.rawValue, "USA")
        XCTAssertEqual(TrainingCourse.CourseRegion.uk.rawValue, "UK")
        XCTAssertEqual(TrainingCourse.CourseRegion.australia.rawValue, "Australia")
        XCTAssertEqual(TrainingCourse.CourseRegion.newZealand.rawValue, "New Zealand")
        XCTAssertEqual(TrainingCourse.CourseRegion.southAfrica.rawValue, "South Africa")
        XCTAssertEqual(TrainingCourse.CourseRegion.other.rawValue, "Other")
        XCTAssertEqual(TrainingCourse.CourseRegion.global.rawValue, "Global")
    }

    func testCourseRegionIcons() {
        let allRegions: [TrainingCourse.CourseRegion] = [
            .canada, .usa, .uk, .australia, .newZealand, .southAfrica, .other, .global
        ]
        for region in allRegions {
            XCTAssertFalse(region.icon.isEmpty, "\(region) has empty icon")
        }
    }

    // MARK: - RecurrentTrainingNotice

    func testRecurrentTrainingNotice_daysUntilDue_future() {
        let futureDate = Date().addingTimeInterval(86400 * 15) // 15 days from now
        let notice = RecurrentTrainingNotice(
            id: UUID(), courseTitle: "Test", courseCategory: "Safety",
            dueDate: futureDate, provider: .buzz
        )
        XCTAssertTrue(notice.daysUntilDue >= 14) // allow for time drift
    }

    func testRecurrentTrainingNotice_daysUntilDue_past() {
        let pastDate = Date().addingTimeInterval(-86400 * 5) // 5 days ago
        let notice = RecurrentTrainingNotice(
            id: UUID(), courseTitle: "Test", courseCategory: "Safety",
            dueDate: pastDate, provider: .buzz
        )
        XCTAssertTrue(notice.daysUntilDue < 0)
    }

    func testRecurrentTrainingNotice_isOverdue_true() {
        let pastDate = Date().addingTimeInterval(-86400)
        let notice = RecurrentTrainingNotice(
            id: UUID(), courseTitle: "Overdue", courseCategory: "Safety",
            dueDate: pastDate, provider: .buzz
        )
        XCTAssertTrue(notice.isOverdue)
    }

    func testRecurrentTrainingNotice_isOverdue_false() {
        let futureDate = Date().addingTimeInterval(86400 * 30)
        let notice = RecurrentTrainingNotice(
            id: UUID(), courseTitle: "Active", courseCategory: "Safety",
            dueDate: futureDate, provider: .buzz
        )
        XCTAssertFalse(notice.isOverdue)
    }

    func testRecurrentTrainingNotice_urgencyColor_overdue() {
        let pastDate = Date().addingTimeInterval(-86400)
        let notice = RecurrentTrainingNotice(
            id: UUID(), courseTitle: "Test", courseCategory: "Safety",
            dueDate: pastDate, provider: .buzz
        )
        XCTAssertEqual(notice.urgencyColor, .red)
    }

    func testRecurrentTrainingNotice_urgencyColor_urgent() {
        let soonDate = Date().addingTimeInterval(86400 * 10) // 10 days
        let notice = RecurrentTrainingNotice(
            id: UUID(), courseTitle: "Test", courseCategory: "Safety",
            dueDate: soonDate, provider: .buzz
        )
        XCTAssertEqual(notice.urgencyColor, .orange)
    }

    func testRecurrentTrainingNotice_urgencyColor_safe() {
        let farDate = Date().addingTimeInterval(86400 * 60) // 60 days
        let notice = RecurrentTrainingNotice(
            id: UUID(), courseTitle: "Test", courseCategory: "Safety",
            dueDate: farDate, provider: .buzz
        )
        XCTAssertEqual(notice.urgencyColor, .blue)
    }
}
