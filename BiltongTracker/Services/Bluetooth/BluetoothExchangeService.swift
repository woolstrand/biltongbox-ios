//
//  BluetoothExchangeService.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 21/10/2023.
//

import Foundation
import CoreBluetooth

struct BluetoothExchangeComponent {
    typealias Interface = BluetoothExchangeComponentInterface
}

protocol BluetoothExchangeComponentInterface {
    func waitForInitializationToComplete() async throws
    func sendCommand(_ command: String) async throws -> String
    func readStatus() async throws -> String
}

extension BluetoothExchangeComponent {
    class Service: NSObject, Interface {
        private var peripheral: CBPeripheral
        
        private var readStatusContinuation: CheckedContinuation<String, Never>?
        private var initializationContinuation: CheckedContinuation<Void, Error>?
        private var sendCommandContinuation: CheckedContinuation<String, Error>?

        private var service: CBService?
        private var characteristics: [CBUUID: CBCharacteristic] = [:]
        
        private var commandTimer: Timer?
        
        init(_ peripheral: CBPeripheral) {
            self.peripheral = peripheral
            super.init()
            
            peripheral.delegate = self
            peripheral.discoverServices(nil)
        }
        
        func waitForInitializationToComplete() async throws {
            if self.service != nil && self.characteristics.keys.count > 0 {
                return
            }
            return try await withCheckedThrowingContinuation({ continuation in
                self.initializationContinuation = continuation
            })
        }
                
        func sendCommand(_ command: String) async throws -> String {
            guard sendCommandContinuation == nil else {
                throw BiltongError(code: BiltongError.Codes.communicationInProgress)
            }
            
            guard let commandChar = characteristics[DeviceDescriptor.Characteristics.command] else {
                throw BiltongError(code: BiltongError.Codes.deviceNotReady)
            }
            
            guard let data = command.data(using: .utf8) else {
                throw BiltongError(code: BiltongError.Codes.malformedInput)
            }
            
            commandTimer = .scheduledTimer(
                withTimeInterval: DeviceDescriptor.defaultTimeout,
                repeats: false) { _ in
                    if let sendCommandContinuation = self.sendCommandContinuation {
                        self.sendCommandContinuation = nil
                        self.commandTimer = nil
                        sendCommandContinuation.resume(throwing: BiltongError(code: BiltongError.Codes.dataExchangeTimeout))
                    }
                }
            
            return try await withCheckedThrowingContinuation({ continuation in
                self.sendCommandContinuation = continuation
                peripheral.writeValue(data, for: commandChar, type: .withResponse)
            })
        }
        
        func sendSecureSettings(_ settings: String) {
            guard let ssChar = characteristics[DeviceDescriptor.Characteristics.secureSettings],
                  let data = settings.data(using: .utf8) else {
                return
            }

            peripheral.writeValue(data, for: ssChar, type: .withResponse)
        }
        
        func readStatus() async throws -> String {
            guard let statusChar = self.characteristics[DeviceDescriptor.Characteristics.status] else {
                throw BiltongError(code: BiltongError.Codes.deviceNotReady)
            }
                        
            return await withCheckedContinuation({ continuation in
                self.readStatusContinuation = continuation
                peripheral.readValue(for: statusChar)
            })
        }
    }
}

extension BluetoothExchangeComponent.Service: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == DeviceDescriptor.uuid }) else {
            return
        }
        
        self.service = service
        peripheral.discoverCharacteristics(nil, for: service)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if self.service != service {
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        for char in characteristics {
            switch char.uuid {
            case DeviceDescriptor.Characteristics.status:
                self.characteristics[DeviceDescriptor.Characteristics.status] = char
                
            case DeviceDescriptor.Characteristics.settings:
                self.characteristics[DeviceDescriptor.Characteristics.settings] = char
                
            case DeviceDescriptor.Characteristics.secureSettings:
                self.characteristics[DeviceDescriptor.Characteristics.secureSettings] = char
                
            case DeviceDescriptor.Characteristics.command:
                self.characteristics[DeviceDescriptor.Characteristics.command] = char
                
            case DeviceDescriptor.Characteristics.readings:
                self.characteristics[DeviceDescriptor.Characteristics.readings] = char
                
            case DeviceDescriptor.Characteristics.dataOut:
                self.characteristics[DeviceDescriptor.Characteristics.dataOut] = char
                
            default:
                // Ignore unknown characteristics
                break
            }
            if self.characteristics.keys.count == 6 {
                self.initializationContinuation?.resume()
                self.initializationContinuation = nil
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
        case DeviceDescriptor.Characteristics.command:
            if let error {
                sendCommandContinuation?.resume(throwing: error)
                sendCommandContinuation = nil
            }
        
        default:
            break
        }
    }
        
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
        case DeviceDescriptor.Characteristics.status:
            if let data = characteristic.value,
               let string = String(data: data, encoding: .utf8) {
                self.readStatusContinuation?.resume(returning: string)
            }

        case DeviceDescriptor.Characteristics.command:
            guard let continuation = sendCommandContinuation else {
                return
            }
            
            if let data = characteristic.value,
               let string = String(data: data, encoding: .utf8) {
                if string.prefix(2) == "OK" {
                    continuation.resume(returning: string)
                } else {
                    continuation.resume(throwing: BiltongError(code: BiltongError.Codes.deviceReportedError, description: string))
                }
            } else {
                continuation.resume(throwing: BiltongError(code: BiltongError.Codes.deviceProvidedMalformedResponse))
            }
            sendCommandContinuation = nil
            
        default:
            break
        }
    }
}

extension BluetoothExchangeComponent {
    class Mock: Interface {
        func waitForInitializationToComplete() async throws {
        }
        
        func sendCommand(_ command: String) async throws -> String {
            try? await Task.sleep(for: .milliseconds(500))
            return "OK"
        }
        
        func readStatus() async throws -> String {
            try? await Task.sleep(for: .milliseconds(500))
            return "X"
        }
        
        
    }
}
