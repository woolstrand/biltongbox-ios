//
//  BluetoothService.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 21/10/2023.
//

import CoreBluetooth
import Combine
import Foundation

struct BluetoothScannerComponent {
    typealias Interface = BluetoothScannerComponentInterface
    
    struct Device: Identifiable {
        let id: UUID
        let displayName: String
    }
}


protocol BluetoothScannerComponentInterface {
    func scan() -> AnyPublisher<BluetoothScannerComponent.Device, Never>
    func stopScan()
    func connectToPeripheral(with id: UUID) async throws -> BluetoothExchangeComponent.Interface
    func disconnectActivePeripheral() async -> Void
}

extension BluetoothScannerComponent {
    class Service: NSObject, BluetoothScannerComponent.Interface {
        lazy private var manager: CBCentralManager = {
            CBCentralManager(delegate: self, queue: nil)
        }()
        
        var neverAuthorized: Bool {
            CBCentralManager.authorization == .notDetermined
        }
        
        private var foundDevicesNotifier: PassthroughSubject<Device, Never>?
        private var needsStartScanning = false
        private var devicesList: [CBPeripheral] = []
        private var activeDevice: CBPeripheral?
        
        private var connectionTimeoutTimer: Timer?
        private var connectionContinuation: CheckedContinuation<BluetoothExchangeComponent.Interface, Error>?
        private var disconnectionContinuation: CheckedContinuation<Void, Never>?

        override init() {
            super.init()
        }
        
        func scan() -> AnyPublisher<Device, Never> {
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
        }
        
        func connectToPeripheral(with id: UUID) async throws -> BluetoothExchangeComponent.Interface {
            guard let device = devicesList.first(where: { $0.identifier == id }) else {
                throw BiltongError(code: BiltongError.Codes.deviceNotFound)
            }
            
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
        let device = BluetoothScannerComponent.Device(
            id: peripheral.identifier,
            displayName: peripheral.name ?? "unnamed"
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
        func scan() -> AnyPublisher<BluetoothScannerComponent.Device, Never> {
            Just(
                BluetoothScannerComponent.Device(
                    id: UUID(),
                    displayName: "Box Mock I"
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
        
    }
}
