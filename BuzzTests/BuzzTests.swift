//
//  BuzzTests.swift
//  BuzzTests
//
//  Created by Xinyu Fang on 12/9/25.
//

import Foundation
import Testing
@testable import Buzz

struct BuzzTests {
    @Test func hangerTalkNotificationTypeCoversAllCases() async throws {
        let allCases = HangerTalkNotificationType.allCases
        #expect(allCases.count == 5)
        #expect(allCases.contains(.like))
        #expect(allCases.contains(.reply))
        #expect(allCases.contains(.mention))
        #expect(allCases.contains(.follow))
        #expect(allCases.contains(.newPost))
    }

    @Test func hangerAuthorProfileFullNameWithBothNames() async throws {
        let profile = HangerAuthorProfile(
            id: UUID(),
            callSign: "MAVERICK",
            profilePictureUrl: nil,
            firstName: "John",
            lastName: "Doe"
        )
        #expect(profile.fullName == "John Doe")
    }

    @Test func hangerAuthorProfileFullNameWithNoNames() async throws {
        let profile = HangerAuthorProfile(
            id: UUID(),
            callSign: nil,
            profilePictureUrl: nil,
            firstName: nil,
            lastName: nil
        )
        #expect(profile.fullName == "Pilot")
    }

    @Test func hangerAuthorProfileFullNameWithOnlyFirstName() async throws {
        let profile = HangerAuthorProfile(
            id: UUID(),
            callSign: nil,
            profilePictureUrl: nil,
            firstName: "John",
            lastName: nil
        )
        #expect(profile.fullName == "John")
    }
}
