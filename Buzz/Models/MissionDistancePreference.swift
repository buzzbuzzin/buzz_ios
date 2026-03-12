//
//  MissionDistancePreference.swift
//  Buzz
//

import Foundation

enum MissionDistancePreference {
    static let storageKey = "pilotMissionDistanceMiles"
    static let defaultMiles: Double = 25
    static let quickOptions: [Double] = [5, 25, 50, 100, 200]
    static let maxMiles: Double = 200

    static var savedMiles: Double {
        let storedValue = UserDefaults.standard.double(forKey: storageKey)
        return storedValue > 0 ? storedValue : defaultMiles
    }
}
