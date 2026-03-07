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
        #expect(allCases.count == 6)
        #expect(allCases.contains(.like))
        #expect(allCases.contains(.reply))
        #expect(allCases.contains(.mention))
        #expect(allCases.contains(.follow))
        #expect(allCases.contains(.newPost))
        #expect(allCases.contains(.spaceLive))
    }

    @Test func hangerAuthorProfileFullNameWithBothNames() async throws {
        let profile = HangerAuthorProfile(
            id: UUID(),
            userType: .pilot,
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
            userType: .pilot,
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
            userType: .customer,
            callSign: nil,
            profilePictureUrl: nil,
            firstName: "John",
            lastName: nil
        )
        #expect(profile.fullName == "John")
    }
}
