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
                let status = try await waitForStatusUpdate()
                
                DispatchQueue.main.async {
                    switch status {
                    case .NOT_INITIALIZED:
                        self.navigatingToSetup = true
                        self.state = .idle
                    default:
                        self.navigatingToBox = true
                        self.state = .idle
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.state = .error(error)
                }
            }
        }
    }
    
    func waitForStatusUpdate() async throws -> Status {
        guard let status = try? await self.connectedExchangeService?.readStatus() else {
            try await Task.sleep(nanoseconds: 1_000_000_000 / 2)
            return try await waitForStatusUpdate()
        }
        
        return status
    }
    
    func getSetupViewModelForNavigation() -> SetupViewModel? {
        guard let connectedExchangeService else {
            return nil
        }
        
        let route = PassthroughSubject<SetupViewModel.CompletionRoute, Never>()
        route.sink { [weak self] route in
            switch route {
            case .setupCancelled:
                print("Setup cancelled")
            case .setupFailed:
                print("Setup failed")
            case .setupCompleted:
                print("Setup completed")
                self?.navigatingToBox = true
            }
        }.store(in: &subs)
        return SetupViewModel(exchangeService: connectedExchangeService, completionRoute: route)
    }
    
    func getBoxViewModelForNavigation() -> BoxViewModel? {
        guard let connectedExchangeService else {
            return nil
        }
        
        return BoxViewModel(exchangeService: connectedExchangeService)
    }
}
