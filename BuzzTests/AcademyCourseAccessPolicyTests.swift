//
//  AcademyCourseAccessPolicyTests.swift
//  BuzzTests
//

import XCTest
@testable import Buzz

final class AcademyCourseAccessPolicyTests: XCTestCase {

    func testRequiresSubscriptionToEnroll_uasPilotIsExempt() {
        let requiresSubscription = AcademyCourseAccessPolicy.requiresSubscriptionToEnroll(
            courseTitle: "UAS Pilot",
            provider: "Buzz",
            externalUrl: nil,
            sectionSnapshots: []
        )

        XCTAssertFalse(requiresSubscription)
    }

    func testRequiresSubscriptionToEnroll_unlockedFlightReviewSectionIsExempt() {
        let requiresSubscription = AcademyCourseAccessPolicy.requiresSubscriptionToEnroll(
            courseTitle: "RPAS Pilot",
            provider: "Buzz",
            externalUrl: nil,
            sectionSnapshots: [
                CourseSectionAccessSnapshot(
                    courseId: UUID(),
                    name: "FLIGHT REVIEW",
                    examType: "flight_review",
                    requiresSubscription: false
                )
            ]
        )

        XCTAssertFalse(requiresSubscription)
    }

    func testRequiresSubscriptionToEnroll_flightReviewerCourseRequiresSubscription() {
        let requiresSubscription = AcademyCourseAccessPolicy.requiresSubscriptionToEnroll(
            courseTitle: "Become A Flight Reviewer",
            provider: "Buzz",
            externalUrl: nil,
            sectionSnapshots: []
        )

        XCTAssertTrue(requiresSubscription)
    }

    func testRequiresSubscriptionToEnroll_paidBuzzCourseRequiresSubscription() {
        let requiresSubscription = AcademyCourseAccessPolicy.requiresSubscriptionToEnroll(
            courseTitle: "Advanced Drone Pilot",
            provider: "Buzz",
            externalUrl: nil,
            sectionSnapshots: [
                CourseSectionAccessSnapshot(
                    courseId: UUID(),
                    name: "ADVANCED DRONE PILOT",
                    examType: nil,
                    requiresSubscription: true
                )
            ]
        )

        XCTAssertTrue(requiresSubscription)
    }

    func testMissingEnrollmentRequirements_includesSubscriptionAndExamRequirements() {
        let course = TrainingCourse(
            id: UUID(),
            title: "Advanced Drone Pilot",
            description: "Desc",
            duration: "4h",
            level: .advanced,
            category: .advanced,
            instructor: "Buzz",
            instructorPictureUrl: nil,
            rating: 5.0,
            studentsCount: 0,
            isEnrolled: false,
            provider: .buzz,
            requiresUasGroundSchool: true,
            requiresFlightReviewPassed: true,
            requiresRocAPassed: true,
            externalUrl: nil,
            coverImageUrl: nil,
            region: .global,
            active: true,
            requiresSubscriptionToEnroll: true
        )

        let missing = AcademyCourseAccessPolicy.missingEnrollmentRequirements(
            for: course,
            hasSubscription: false,
            hasPassedGroundSchool: false,
            hasPassedFlightReview: false,
            hasPassedRocA: false
        )

        XCTAssertEqual(
            missing,
            [
                "Buzz Academy Pass subscription",
                "UAS Pilot Ground School Test",
                "Flight Review Test",
                "ROC-A Test"
            ]
        )
    }
}
