//
//  AcademyCourseAccessPolicy.swift
//  Buzz
//

import Foundation

struct CourseSectionAccessSnapshot: Codable {
    let courseId: UUID
    let name: String
    let examType: String?
    let requiresSubscription: Bool

    enum CodingKeys: String, CodingKey {
        case courseId = "course_id"
        case name
        case examType = "exam_type"
        case requiresSubscription = "requires_subscription"
    }
}

enum AcademyCourseAccessPolicy {
    static func requiresSubscriptionToEnroll(
        courseTitle: String,
        provider: String?,
        externalUrl: String?,
        sectionSnapshots: [CourseSectionAccessSnapshot]
    ) -> Bool {
        if let externalUrl, !externalUrl.isEmpty {
            return false
        }

        guard normalized(provider) == normalized(TrainingCourse.CourseProvider.buzz.rawValue) else {
            return false
        }

        return !isSubscriptionExemptCourse(courseTitle: courseTitle, sectionSnapshots: sectionSnapshots)
    }

    static func missingEnrollmentRequirements(
        for course: TrainingCourse,
        hasSubscription: Bool,
        hasPassedGroundSchool: Bool,
        hasPassedFlightReview: Bool,
        hasPassedRocA: Bool
    ) -> [String] {
        var missing: [String] = []

        if course.requiresSubscriptionToEnroll && !hasSubscription {
            missing.append("Buzz Academy Pass subscription")
        }

        if course.requiresUasGroundSchool && !hasPassedGroundSchool {
            missing.append("UAS Pilot Ground School Test")
        }

        if course.requiresFlightReviewPassed && !hasPassedFlightReview {
            missing.append("Flight Review Test")
        }

        if course.requiresRocAPassed && !hasPassedRocA {
            missing.append("ROC-A Test")
        }

        return missing
    }

    private static func isSubscriptionExemptCourse(
        courseTitle: String,
        sectionSnapshots: [CourseSectionAccessSnapshot]
    ) -> Bool {
        let title = normalized(courseTitle)

        if ["uas pilot", "rpas pilot", "roc a"].contains(title) {
            return true
        }

        let hasUnlockedFlightReviewOrRocASection = sectionSnapshots.contains { section in
            guard !section.requiresSubscription else {
                return false
            }

            let sectionName = normalized(section.name)
            let examType = normalized(section.examType)

            return examType == "flight review"
                || examType == "roc a"
                || sectionName.contains("flight review")
                || sectionName.contains("roc a")
        }

        return hasUnlockedFlightReviewOrRocASection
    }

    private static func normalized(_ value: String?) -> String {
        guard let value else {
            return ""
        }

        return value
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
