//
//  BadgeModelTests.swift
//  BuzzTests
//
//  Tests for Badge, BadgeCatalog, and AvailableBadge models.
//

import XCTest
@testable import Buzz

final class BadgeModelTests: XCTestCase {

    // MARK: - Badge Expiration Computed Properties

    func testDaysUntilExpiration_futureDate() {
        let badge = makeBadge(expiresAt: Date().addingTimeInterval(86400 * 10)) // 10 days
        XCTAssertNotNil(badge.daysUntilExpiration)
        XCTAssertTrue((badge.daysUntilExpiration ?? 0) >= 9) // account for time drift
    }

    func testDaysUntilExpiration_nilExpiry() {
        let badge = makeBadge(expiresAt: nil)
        XCTAssertNil(badge.daysUntilExpiration)
    }

    func testIsExpiringSoon_within7Days() {
        let badge = makeBadge(expiresAt: Date().addingTimeInterval(86400 * 5)) // 5 days
        XCTAssertTrue(badge.isExpiringSoon)
    }

    func testIsExpiringSoon_moreThan7Days() {
        let badge = makeBadge(expiresAt: Date().addingTimeInterval(86400 * 30)) // 30 days
        XCTAssertFalse(badge.isExpiringSoon)
    }

    func testIsExpiringSoon_alreadyExpired() {
        let badge = makeBadge(expiresAt: Date().addingTimeInterval(-86400)) // yesterday
        XCTAssertFalse(badge.isExpiringSoon) // daysUntilExpiration <= 0
    }

    func testIsExpiringSoon_noExpiry() {
        let badge = makeBadge(expiresAt: nil)
        XCTAssertFalse(badge.isExpiringSoon)
    }

    func testIsExpired_pastDate() {
        let badge = makeBadge(expiresAt: Date().addingTimeInterval(-86400))
        XCTAssertTrue(badge.isExpired)
    }

    func testIsExpired_futureDate() {
        let badge = makeBadge(expiresAt: Date().addingTimeInterval(86400))
        XCTAssertFalse(badge.isExpired)
    }

    func testIsExpired_noExpiry() {
        let badge = makeBadge(expiresAt: nil)
        XCTAssertFalse(badge.isExpired)
    }

    // MARK: - Badge Display Properties

    func testDisplayTitle_courseBadge() {
        let badge = makeBadge(courseTitle: "Part 107 Prep", badgeType: .course)
        XCTAssertEqual(badge.displayTitle, "Part 107 Prep")
    }

    func testDisplayTitle_criteriaBadge() {
        let badge = makeBadge(courseTitle: nil, badgeType: .exMilitary)
        XCTAssertEqual(badge.displayTitle, "Ex-Military")
    }

    func testDisplayTitle_noCourseTitle() {
        let badge = makeBadge(courseTitle: nil, badgeType: .course)
        XCTAssertEqual(badge.displayTitle, "Unknown Badge")
    }

    func testDisplayCategory_exMilitary() {
        let badge = makeBadge(badgeType: .exMilitary)
        XCTAssertEqual(badge.displayCategory, "Service Recognition")
    }

    func testDisplayCategory_governmentEmployee() {
        let badge = makeBadge(badgeType: .governmentEmployee)
        XCTAssertEqual(badge.displayCategory, "Service Recognition")
    }

    func testDisplayCategory_faa() {
        let badge = makeBadge(badgeType: .faa)
        XCTAssertEqual(badge.displayCategory, "Certification")
    }

    func testDisplayCategory_buzz() {
        let badge = makeBadge(badgeType: .buzz)
        XCTAssertEqual(badge.displayCategory, "Partnership")
    }

    func testDisplayCategory_flightReviewer() {
        let badge = makeBadge(badgeType: .flightReviewer)
        XCTAssertEqual(badge.displayCategory, "Permits")
    }

    func testDisplayCategory_rocaExaminer() {
        let badge = makeBadge(badgeType: .rocaExaminer)
        XCTAssertEqual(badge.displayCategory, "Permits")
    }

    func testDisplayCategory_beaconVolunteer() {
        let badge = makeBadge(badgeType: .beaconVolunteer)
        XCTAssertEqual(badge.displayCategory, "Emergency Response")
    }

    func testDisplayCategory_cert() {
        let badge = makeBadge(badgeType: .cert)
        XCTAssertEqual(badge.displayCategory, "Emergency Response")
    }

    func testDisplayCategory_courseBadge() {
        let badge = makeBadge(courseCategory: "Flight Operations", badgeType: .course)
        XCTAssertEqual(badge.displayCategory, "Flight Operations")
    }

    func testDisplayCategory_courseBadge_nilCategory() {
        let badge = makeBadge(courseCategory: nil, badgeType: .course)
        XCTAssertEqual(badge.displayCategory, "Course")
    }

    // MARK: - BadgeType Enum

    func testAllBadgeTypesHaveDisplayNames() {
        let allTypes: [Badge.BadgeType] = [
            .course, .exMilitary, .buzz, .governmentEmployee, .faa,
            .flightReviewer, .rocaExaminer, .beaconVolunteer,
            .cert, .firstAid, .basicFirefighter
        ]
        for type in allTypes {
            XCTAssertFalse(type.displayName.isEmpty, "\(type) has empty displayName")
        }
    }

    func testAllBadgeTypesHaveIcons() {
        let allTypes: [Badge.BadgeType] = [
            .course, .exMilitary, .buzz, .governmentEmployee, .faa,
            .flightReviewer, .rocaExaminer, .beaconVolunteer,
            .cert, .firstAid, .basicFirefighter
        ]
        for type in allTypes {
            XCTAssertFalse(type.icon.isEmpty, "\(type) has empty icon")
        }
    }

    func testBuzzBadgeHasImageAsset() {
        XCTAssertEqual(Badge.BadgeType.buzz.imageAssetName, "Logo")
        XCTAssertNil(Badge.BadgeType.course.imageAssetName)
        XCTAssertNil(Badge.BadgeType.faa.imageAssetName)
        XCTAssertNil(Badge.BadgeType.exMilitary.imageAssetName)
    }

    // MARK: - CourseProvider Enum

    func testCourseProviderRawValues() {
        XCTAssertEqual(Badge.CourseProvider.buzz.rawValue, "Buzz")
        XCTAssertEqual(Badge.CourseProvider.redCross.rawValue, "Red Cross")
        XCTAssertEqual(Badge.CourseProvider.amazon.rawValue, "Amazon")
        XCTAssertEqual(Badge.CourseProvider.tmobile.rawValue, "T-Mobile")
    }

    func testCourseProviderIcons() {
        let allProviders: [Badge.CourseProvider] = [
            .buzz, .redCross, .usfa, .fema, .amazon, .tmobile, .other
        ]
        for provider in allProviders {
            XCTAssertFalse(provider.icon.isEmpty, "\(provider) has empty icon")
        }
    }

    // MARK: - AvailableBadge

    func testAvailableBadgeProviderColor_criteriaBadge() {
        let badge = AvailableBadge(
            id: UUID(), courseId: nil, courseTitle: "Ex-Military",
            courseCategory: "Service Recognition", provider: .buzz,
            isRecurrent: false, badgeType: .exMilitary
        )
        // criteria badge color should come from badgeType, not provider
        XCTAssertEqual(badge.providerColor, Badge.BadgeType.exMilitary.color)
    }

    func testAvailableBadgeProviderColor_courseBadge() {
        let badge = AvailableBadge(
            id: UUID(), courseId: UUID(), courseTitle: "Test Course",
            courseCategory: "Safety", provider: .amazon,
            isRecurrent: false, badgeType: .course
        )
        // course badge color should come from provider
        XCTAssertEqual(badge.providerColor, Badge.CourseProvider.amazon.color)
    }

    func testAvailableBadgeImageAsset_criteriaBadge() {
        let badge = AvailableBadge(
            id: UUID(), courseId: nil, courseTitle: "Buzz",
            courseCategory: "Partnership", provider: .buzz,
            isRecurrent: false, badgeType: .buzz
        )
        XCTAssertEqual(badge.imageAssetName, "Logo")
    }

    func testAvailableBadgeImageAsset_courseBadge() {
        let badge = AvailableBadge(
            id: UUID(), courseId: UUID(), courseTitle: "Course",
            courseCategory: "Safety", provider: .buzz,
            isRecurrent: false, badgeType: .course
        )
        XCTAssertNil(badge.imageAssetName)
    }

    // MARK: - Helpers

    private func makeBadge(
        courseTitle: String? = "Test Course",
        courseCategory: String? = "Test Category",
        expiresAt: Date? = nil,
        badgeType: Badge.BadgeType? = .course
    ) -> Badge {
        Badge(
            id: UUID(),
            courseId: badgeType == .course ? UUID() : nil,
            courseTitle: courseTitle,
            courseCategory: courseCategory,
            earnedAt: Date(),
            provider: .buzz,
            expiresAt: expiresAt,
            isRecurrent: expiresAt != nil,
            badgeType: badgeType
        )
    }
}
