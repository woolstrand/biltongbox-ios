//
//  SetupViewModel.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 21/10/2023.
//

import Foundation
import Combine

class ConnectViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case scanning
        case error(Error)
        case connecting
        
        static func == (lhs: ConnectViewModel.State, rhs: ConnectViewModel.State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                (.scanning, .scanning),
                (.connecting, .connecting):
                return true
                
            case let (.error(lerr), .error(rerr)):
                return lerr.localizedDescription == rerr.localizedDescription
                
            default:
                return false
            }
        }
    }
    
    @Published var devices: [BluetoothScannerComponent.Device]
    @Published var state: State = .idle
    
    @Published var navigatingToSetup = false
    @Published var navigatingToBox = false

    private var scannerService: BluetoothScannerComponent.Interface
    private var connectedExchangeService: BluetoothExchangeComponent.Interface?
    
    private var subs = Set<AnyCancellable>()
    private var scannerSub: AnyCancellable?
    
    init(scannerService: BluetoothScannerComponent.Interface) {
        devices = []
        self.scannerService = scannerService
    }
    
    func startScanning() {
        if state == .scanning {
            return
        }
        
        Task {
            await scannerService.disconnectActivePeripheral()
        }
        
        scannerSub = scannerService.scan()
            .sink { device in
                if !self.devices.contains(where: { $0.id == device.id }) {
                    self.devices.append(device)
                }
            }
        
        state = .scanning
    }
    
    func stopScanning() {
        scannerService.stopScan()
        scannerSub?.cancel()
        scannerSub = nil
        state = .idle
    }
    
    func resetState() {
        Task {
            await self.scannerService.disconnectActivePeripheral()
            DispatchQueue.main.async {
                self.state = .idle
            }
        }
    }
    
    func connectDevice(_ deviceId: UUID) {
        stopScanning()
        state = .connecting
        Task {
            do {
                let connectedService = try await scannerService.connectToPeripheral(with: deviceId)
                self.proceedWithConnectedDevice(connectedService)
            } catch {
                print("Error during connection: \(error)")
            }
        }
    }
    
    func proceedWithConnectedDevice(_ connectedService: BluetoothExchangeComponent.Interface) {
        // Check if the device is set up. yes -> BoxView. no -> SetupView
        print("Connection successful")
        self.connectedExchangeService = connectedService
        Task {
            do {
                try await connectedService.waitForInitializationToComplete()
                let status = try await connectedService.readStatus()
                DispatchQueue.main.async {
                    switch status {
                    case "X":
                        self.navigatingToSetup = true
                        self.state = .idle
                    case "A":
                        self.navigatingToBox = true
                        self.state = .idle
                    default:
                        self.state = .error(BiltongError(code: BiltongError.Codes.deviceInUnknownState))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.state = .error(error)
                }
            }
        }
    }
    
    func getSetupViewModelForNavigation() -> SetupViewModel? {
        guard let connectedExchangeService else {
            return nil
        }
        
        return SetupViewModel(exchangeService: connectedExchangeService)
    }
    
    func getBoxViewModelForNavigation() -> BoxViewModel? {
        guard let connectedExchangeService else {
            return nil
        }
        
        return BoxViewModel(exchangeService: connectedExchangeService)
    }
}
