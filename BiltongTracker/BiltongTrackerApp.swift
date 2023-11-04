//
//  BiltongTrackerApp.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 21/10/2023.
//

import SwiftUI

@main
struct BiltongTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ConnectView(viewModel: ConnectViewModel(scannerService: BluetoothScannerComponent.Service()))
        }
    }
}
