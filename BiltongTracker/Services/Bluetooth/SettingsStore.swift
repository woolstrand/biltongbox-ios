//
//  SettingsStore.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 01/03/2024.
//

import Foundation

protocol SettingsStore {
    func string(forKey key: String) -> String?
    func setValue(_ value: Any?, forKey: String)
}

extension UserDefaults: SettingsStore {}

struct EmptySettingsStoreMock: SettingsStore {
    func string(forKey key: String) -> String? {
        nil
    }
    
    func setValue(_ value: Any?, forKey: String) {
    }
}
