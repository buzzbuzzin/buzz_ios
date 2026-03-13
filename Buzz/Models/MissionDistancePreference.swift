//
//  MissionDistancePreference.swift
//  Buzz
//

import Foundation

enum MissionDistancePreference {
    static let storageKey = "pilotMissionDistanceMiles"
    static let defaultMiles: Double = 25
    static let quickOptions: [Double] = [5, 25, 50, 100, 150]
    static let maxMiles: Double = 150

    static var savedMiles: Double {
        let storedValue = UserDefaults.standard.double(forKey: storageKey)
        return storedValue > 0 ? storedValue : defaultMiles
    }
}
