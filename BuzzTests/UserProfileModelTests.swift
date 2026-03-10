//
//  UserProfileModelTests.swift
//  BuzzTests
//
//  Tests for UserProfile model and related enums.
//

import XCTest
@testable import Buzz

final class UserProfileModelTests: XCTestCase {

    // MARK: - fullName Computed Property

    func testFullName_bothNames() {
        let profile = makeProfile(firstName: "John", lastName: "Doe")
        XCTAssertEqual(profile.fullName, "John Doe")
    }

    func testFullName_firstNameOnly() {
        let profile = makeProfile(firstName: "John", lastName: nil)
        XCTAssertEqual(profile.fullName, "John")
    }

    func testFullName_lastNameOnly() {
        let profile = makeProfile(firstName: nil, lastName: "Doe")
        XCTAssertEqual(profile.fullName, "Doe")
    }

    func testFullName_noNames() {
        let profile = makeProfile(firstName: nil, lastName: nil)
        XCTAssertEqual(profile.fullName, "User")
    }

    // MARK: - UserType Enum

    func testUserTypeRawValues() {
        XCTAssertEqual(UserType.pilot.rawValue, "pilot")
        XCTAssertEqual(UserType.customer.rawValue, "customer")
    }

    // MARK: - CommunicationPreference Enum

    func testCommunicationPreferenceDisplayNames() {
        XCTAssertEqual(CommunicationPreference.email.displayName, "Email")
        XCTAssertEqual(CommunicationPreference.text.displayName, "Text Message")
        XCTAssertEqual(CommunicationPreference.both.displayName, "Both")
    }

    // MARK: - Gender Enum

    func testGenderCaseIterable() {
        let allCases = Gender.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.male))
        XCTAssertTrue(allCases.contains(.female))
        XCTAssertTrue(allCases.contains(.other))
        XCTAssertTrue(allCases.contains(.preferNotToSay))
    }

    func testGenderDisplayNames() {
        XCTAssertEqual(Gender.male.displayName, "Male")
        XCTAssertEqual(Gender.female.displayName, "Female")
        XCTAssertEqual(Gender.other.displayName, "Other")
        XCTAssertEqual(Gender.preferNotToSay.displayName, "Prefer not to say")
    }

    // MARK: - CustomerRole Enum

    func testCustomerRoleDisplayNames() {
        XCTAssertEqual(CustomerRole.individual.displayName, "Individual")
        XCTAssertEqual(CustomerRole.company.displayName, "Company")
        XCTAssertEqual(CustomerRole.government.displayName, "Government")
        XCTAssertEqual(CustomerRole.nonProfit.displayName, "Non-profit")
    }

    func testCustomerRoleIcons() {
        for role in CustomerRole.allCases {
            XCTAssertFalse(role.icon.isEmpty, "\(role) has empty icon")
        }
    }

    // MARK: - Measurement System

    func testMeasurementSystemRegionalDefault_USAIsImperial() {
        XCTAssertEqual(MeasurementSystem.regionalDefault(for: "USA"), .imperial)
    }

    func testMeasurementSystemRegionalDefault_CanadaAndUKAreMetric() {
        XCTAssertEqual(MeasurementSystem.regionalDefault(for: "Canada"), .metric)
        XCTAssertEqual(MeasurementSystem.regionalDefault(for: "UK"), .metric)
    }

    func testEffectiveMeasurementSystem_UsesRegionalDefaultWhenNoOverrideExists() {
        let profile = makeProfile(
            firstName: "John",
            lastName: "Doe",
            selectedRegion: "Canada",
            preferredMeasurementSystem: nil
        )

        XCTAssertEqual(profile.effectiveMeasurementSystem, .metric)
    }

    func testEffectiveMeasurementSystem_UsesExplicitOverrideWhenPresent() {
        let profile = makeProfile(
            firstName: "John",
            lastName: "Doe",
            selectedRegion: "Canada",
            preferredMeasurementSystem: .imperial
        )

        XCTAssertEqual(profile.effectiveMeasurementSystem, .imperial)
    }

    // MARK: - Helpers

    private func makeProfile(
        firstName: String?,
        lastName: String?,
        selectedRegion: String? = nil,
        preferredMeasurementSystem: MeasurementSystem? = nil
    ) -> UserProfile {
        UserProfile(
            id: UUID(),
            userType: .pilot,
            firstName: firstName,
            lastName: lastName,
            callSign: nil,
            email: nil,
            phone: nil,
            gender: nil,
            profilePictureUrl: nil,
            communicationPreference: nil,
            role: nil,
            specialization: nil,
            createdAt: Date(),
            balance: nil,
            stripeAccountId: nil,
            isExMilitary: nil,
            isGovernmentEmployee: nil,
            hasFaaCertification: nil,
            isBuzzAffiliate: nil,
            veteranServiceName: nil,
            veteranServiceCountry: nil,
            veteranMilitaryBranch: nil,
            veteranServiceNumber: nil,
            lastLocationLat: nil,
            lastLocationLng: nil,
            lastLocationUpdate: nil,
            referralCredits: nil,
            referredBy: nil,
            isBeaconVolunteer: nil,
            selectedRegion: selectedRegion,
            preferredMeasurementSystem: preferredMeasurementSystem,
            isVerified: nil
        )
    }
}
