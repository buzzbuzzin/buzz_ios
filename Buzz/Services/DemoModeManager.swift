//
//  DemoModeManager.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import Combine

@MainActor
class DemoModeManager: ObservableObject {
    static let shared = DemoModeManager()

    @Published var isDemoModeEnabled: Bool = false

    private init() {
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment
        self.isDemoModeEnabled = args.contains("DEMO_MODE") || args.contains("UI_TESTING") || env["UITEST_MODE"] == "1"
    }
}

