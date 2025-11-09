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
    
    @Published var isDemoModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDemoModeEnabled, forKey: "demoModeEnabled")
        }
    }
    
    private init() {
        self.isDemoModeEnabled = UserDefaults.standard.bool(forKey: "demoModeEnabled")
    }
    
    func toggleDemoMode() {
        isDemoModeEnabled.toggle()
    }
}

