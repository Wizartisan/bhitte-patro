//
//  LaunchAtLoginManager.swift
//  NepaliPatro
//
//  Created by Gemini on 20/03/2026.
//

import Foundation
import ServiceManagement
import Observation

@Observable
class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    
    var isEnabled: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login status: \(error)")
            }
        }
    }
    
    private init() {}
}
