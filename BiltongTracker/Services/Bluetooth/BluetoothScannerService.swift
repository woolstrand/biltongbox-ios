//
//  BluetoothService.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 21/10/2023.
//

import CoreBluetooth
import Combine
import Foundation

enum BluetoothScannerComponent {
    typealias Interface = BluetoothScannerComponentInterface
    
    /// This structure describes a device found during scanning
    struct Device: Identifiable {
        
        /// Device identifier
        let id: UUID
        
        /// Display name of the device
        let displayName: String
        
        /// Initialized connection component if the device was automatically connected, nil otherwise.
        let connection: BluetoothExchangeComponent.Interface?
    }
}


protocol BluetoothScannerComponentInterface {
    /// Starts scanning for nearby devices.
    /// @param autoconnect if true, attempts to connect to the last used device automatically.
    func scan(autoconnect: Bool) -> AnyPublisher<BluetoothScannerComponent.Device, Never>
    
    /// Stops scanning process
    func stopScan()
    
    /// Connects to a specific peripheral device
    /// @param id device identifier
    func connectToPeripheral(with id: UUID) async throws -> BluetoothExchangeComponent.Interface
    
    /// Disconnects any active peripheral
    func disconnectActivePeripheral() async
    
    /// Erases saved device info, this way disables next autoconnection attempt
    func forgetSavedDevice()
}

extension BluetoothScannerComponent {
    class Service: NSObject, BluetoothScannerComponent.Interface {
        var neverAuthorized: Bool {
            CBCentralManager.authorization == .notDetermined
        }
        
        // Consts
        private enum Constants {
            static let lastUsedDeviceIdKey = "biltong.lastUsedCBUUID"
        }
        
        // External Deps
        private var settingsStore: SettingsStore
        
        // Internal Deps (do I want to mock CBCentralManager? Guess not right now)
        lazy private var manager: CBCentralManager = {
            CBCentralManager(delegate: self, queue: nil)
        }()

        // Internal state
        private var foundDevicesNotifier: PassthroughSubject<Device, Never>?
        private var needsStartScanning = false
        private var devicesList: [CBPeripheral] = []
        private var activeDevice: CBPeripheral?
        
        private var connectionTimeoutTimer: Timer?
        private var connectionContinuation: CheckedContinuation<BluetoothExchangeComponent.Interface, Error>?
        private var disconnectionContinuation: CheckedContinuation<Void, Never>?
        
        private var deviceForAutoconnection: UUID?

        init(settingsStore: SettingsStore) {
            self.settingsStore = settingsStore
            super.init()
        }
        
        func scan(autoconnect: Bool) -> AnyPublisher<Device, Never> {
            if autoconnect,
               let storedUUIDString = settingsStore.string(forKey: Constants.lastUsedDeviceIdKey) {
                deviceForAutoconnection = UUID(uuidString: storedUUIDString)
            } else {
                deviceForAutoconnection = nil
            }
            
            if self.manager.isScanning {
                if let foundDevicesNotifier {
                    return foundDevicesNotifier
                        .eraseToAnyPublisher()
                } else {
                    let publisher = PassthroughSubject<Device, Never>()
                    foundDevicesNotifier = publisher
                    return publisher.eraseToAnyPublisher()
                }
            }
            
            if self.manager.state == .poweredOn {
                doStartScan()
            } else {
                needsStartScanning = true
            }
            
            let publisher = PassthroughSubject<Device, Never>()
            foundDevicesNotifier = publisher
            return publisher.eraseToAnyPublisher()
        }
        
        private func doStartScan() {
            devicesList = []
            manager.scanForPeripherals(withServices: [DeviceDescriptor.uuid])
        }
        
        func stopScan() {
            manager.stopScan()
            deviceForAutoconnection = nil
        }
        
        func connectToPeripheral(with id: UUID) async throws -> BluetoothExchangeComponent.Interface {
            guard let device = devicesList.first(where: { $0.identifier == id }) else {
                throw BiltongError(code: BiltongError.Codes.deviceNotFound)
            }
            
            return try await connectToPeripheral(device)
        }
        
        private func connectToPeripheral(_ device: CBPeripheral) async throws -> BluetoothExchangeComponent.Interface {
            
            if let activeDevice {
                manager.cancelPeripheralConnection(activeDevice)
            }
            
            activeDevice = device

            return try await withCheckedThrowingContinuation { continuation in
                connectionContinuation = continuation
                connectionTimeoutTimer = .scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                    self.manager.cancelPeripheralConnection(device)
                    self.connectionContinuation?.resume(throwing: BiltongError(code: BiltongError.Codes.connectionTimeout))
                    self.connectionTimeoutTimer = nil
                    self.connectionContinuation = nil
                }
                if manager.isScanning {
                    manager.stopScan()
                }

                manager.connect(device)
            }
        }
        
        func disconnectActivePeripheral() async -> Void {
            guard let activeDevice else {
                return
            }
            
            return await withCheckedContinuation({ continuation in
                self.disconnectionContinuation = continuation
                manager.cancelPeripheralConnection(activeDevice)
            })
        }
        
        func forgetSavedDevice() {
            settingsStore.setValue(nil, forKey: Constants.lastUsedDeviceIdKey)
        }
    }
}


extension BluetoothScannerComponent.Service: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            if needsStartScanning {
                if !central.isScanning {
                    doStartScan()
                }
            }
        }
        
        // TODO: add reaction on powering off during search
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        // If we consider autoconnection
        if let deviceForAutoconnection {
            // Check if the found device is eligible
            if peripheral.identifier == deviceForAutoconnection {
                Task {
                    // Try to connect
                    let connection = try? await connectToPeripheral(peripheral)
                    let device = BluetoothScannerComponent.Device(
                        id: peripheral.identifier,
                        displayName: peripheral.name ?? "unnamed",
                        connection: connection
                    )
                    
                    // Notify about device found, this device will hold connection object if the
                    // connection was established successfully
                    foundDevicesNotifier?.send(device)
                }
                
                // Do not notify immediately about that device, try to connect first
                return
            }
        }
        
        // Otherwise notify about the device, but without connection specified.
        let device = BluetoothScannerComponent.Device(
            id: peripheral.identifier,
            displayName: peripheral.name ?? "unnamed",
            connection: nil
        )
        
        if !devicesList.contains(where: { $0.identifier == peripheral.identifier}) {
            devicesList.append(peripheral)
        }
        
        foundDevicesNotifier?.send(device)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard let activeDevice, activeDevice.identifier == peripheral.identifier else {
            assertionFailure("Central manager did fail to connect to a device which is not active.")
            return
        }
        
        connectionContinuation?.resume(
            throwing: BiltongError(
                code: BiltongError.Codes.connectionFailure,
                underlyingError: error
            )
        )
        connectionTimeoutTimer?.invalidate()
        connectionContinuation = nil
        connectionTimeoutTimer = nil
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let activeDevice, activeDevice.identifier == peripheral.identifier else {
            assertionFailure("Central manager did connect to a device which is not active.")
            return
        }

        settingsStore.setValue(peripheral.identifier.uuidString, forKey: Constants.lastUsedDeviceIdKey)
        
        connectionContinuation?.resume(returning: BluetoothExchangeComponent.Service(peripheral))
        connectionTimeoutTimer?.invalidate()
        connectionContinuation = nil
        connectionTimeoutTimer = nil
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let activeDevice,
           activeDevice.identifier == peripheral.identifier {
            self.activeDevice = nil
        }
        disconnectionContinuation?.resume(returning: ())
    }
}

extension BluetoothScannerComponent {
    class Mock: BluetoothScannerComponent.Interface {
        func scan(autoconnect: Bool) -> AnyPublisher<BluetoothScannerComponent.Device, Never> {
            Just(
                BluetoothScannerComponent.Device(
                    id: UUID(),
                    displayName: "Box Mock I",
                    connection: nil
                )
            )
            .delay(for: .seconds(2), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
        }
        
        func stopScan() {
        }
        
        func connectToPeripheral(with id: UUID) async throws -> BluetoothExchangeComponent.Interface {
            try await Task.sleep(for: .seconds(1))
            return BluetoothExchangeComponent.Mock()
        }
        
        func disconnectActivePeripheral() async {
            try? await Task.sleep(for: .seconds(1))
            return
        }
        
        func forgetSavedDevice() {}
    }
}
