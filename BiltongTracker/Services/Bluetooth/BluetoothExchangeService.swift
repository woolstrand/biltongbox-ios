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

struct ProgressData {
    let startDate: Date
    let initialWeight: Double
    let currentWeight: Double
}

enum Status: Int {
    case NOT_INITIALIZED = 0 // 0 - first run: have to setup wifi connection
    case STARTING_UP // 1 - have all required info, warming up
    case INITIALIZED_IDLE // 2 - initialized, wating for commands
    case RESUMING_PROCESS // 3 - Got an ongoing process, resuming after restart
    case STARTING_PROCESS // 4 - Startup sequesce for the process: weighing of raw meat, collecting process settings
    case PROCESS_IN_PROGRESS // 5 - Capturing data, waiting for target values to be reached
    case PROCESS_FINISHED // 6 - Target values reached, informing
    case CALIBRATION // 7 - Ongoing calibration
}

protocol BluetoothExchangeComponentInterface {
    func waitForInitializationToComplete() async throws
    @discardableResult func sendCommand(_ command: String) async throws -> String
    func readStatus() async throws -> Status
    func readProgress() async throws -> ProgressData
}

extension BluetoothExchangeComponent {
    class Service: NSObject, Interface {
        private var peripheral: CBPeripheral
        
        private var readStatusContinuation: CheckedContinuation<Status, Error>?
        private var readProgressContinuation: CheckedContinuation<ProgressData, Error>?
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
            
            guard peripheral.state == .connected else {
                throw BiltongError(code: BiltongError.Codes.deviceDisconnected)
            }
            
            await MainActor.run {
                commandTimer = .scheduledTimer(
                    withTimeInterval: DeviceDescriptor.defaultTimeout,
                    repeats: false) { _ in
                        if let sendCommandContinuation = self.sendCommandContinuation {
                            self.sendCommandContinuation = nil
                            self.commandTimer = nil
                            sendCommandContinuation.resume(throwing: BiltongError(code: BiltongError.Codes.dataExchangeTimeout))
                        }
                    }
            }
            
            return try await withCheckedThrowingContinuation { continuation in
                self.sendCommandContinuation = continuation
                peripheral.setNotifyValue(true, for: commandChar)
                peripheral.writeValue(data, for: commandChar, type: .withResponse)
            }
        }
        
        func sendSecureSettings(_ settings: String) {
            guard let ssChar = characteristics[DeviceDescriptor.Characteristics.secureSettings],
                  let data = settings.data(using: .utf8) else {
                return
            }

            if peripheral.state == .connected {
                peripheral.writeValue(data, for: ssChar, type: .withResponse)
            }
        }
        
        func readStatus() async throws -> Status {
            guard let statusChar = self.characteristics[DeviceDescriptor.Characteristics.status] else {
                throw BiltongError(code: BiltongError.Codes.deviceNotReady)
            }
            
            guard peripheral.state == .connected else {
                throw BiltongError(code: BiltongError.Codes.deviceDisconnected)
            }
            
            return try await withCheckedThrowingContinuation { continuation in
                self.readStatusContinuation = continuation
                peripheral.readValue(for: statusChar)
            }
        }
        
        func readProgress() async throws -> ProgressData {
            guard let readingsChar = self.characteristics[DeviceDescriptor.Characteristics.readings] else {
                throw BiltongError(code: BiltongError.Codes.deviceNotReady)
            }
            
            guard peripheral.state == .connected else {
                throw BiltongError(code: BiltongError.Codes.deviceDisconnected)
            }
            
            return try await withCheckedThrowingContinuation { continuation in
                self.readProgressContinuation = continuation
                peripheral.readValue(for: readingsChar)
            }
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
        let charName = DeviceDescriptor.Characteristics.charName(uuid: characteristic.uuid)
        print("DidWriteValue for \(charName), error: \(error?.localizedDescription ?? "n/a")")
        switch characteristic.uuid {
        case DeviceDescriptor.Characteristics.command:
            if let error {
                sendCommandContinuation?.resume(throwing: error)
                sendCommandContinuation = nil
            } else {
                // For command we immediately request reading response
                DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .milliseconds(500)), execute: {
                    peripheral.readValue(for: characteristic)
                })
            }
        
        default:
            break
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let charName = DeviceDescriptor.Characteristics.charName(uuid: characteristic.uuid)
        print("DidUpdateNotificationState for \(charName), is notifying: \(characteristic.isNotifying) error: \(error?.localizedDescription ?? "n/a")")
    }
        
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // === DEBUG ===
        var debugValue = "no data"
        if let data = characteristic.value,
           let string = String(data: data, encoding: .utf8) {
            debugValue = string
        }
        
        let charName = DeviceDescriptor.Characteristics.charName(uuid: characteristic.uuid)
        print("DidUpdateValue for \(charName), value:\(debugValue) error: \(error?.localizedDescription ?? "n/a")")
        // === DEBUG ===

        switch characteristic.uuid {
        case DeviceDescriptor.Characteristics.status:
            if let data = characteristic.value,
               let string = String(data: data, encoding: .utf8) {
                if let number = Int(string, radix: 10),
                   let status = Status(rawValue: number) {
                    self.readStatusContinuation?.resume(returning: status)
                } else {
                    self.readStatusContinuation?.resume(returning: .NOT_INITIALIZED)
                }
            } else {
                self.readStatusContinuation?.resume(throwing: BiltongError(code: BiltongError.Codes.deviceProvidedMalformedResponse))
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
            
        case DeviceDescriptor.Characteristics.readings:
            guard let continuation = readProgressContinuation else {
                return
            }
            
            if let data = characteristic.value,
               let string = String(data: data, encoding: .utf8) {
                // parse string
                let components = string.components(separatedBy: CharacterSet(charactersIn: ":"))
                guard components.count > 2,
                      let currentWeight = Double(components[0]),
                      let initialWeight = Double(components[1]),
                      let initialTime = Int(components[2]) else {
                    continuation.resume(throwing: BiltongError(code: BiltongError.Codes.deviceProvidedMalformedResponse))
                    return
                }
                
                let progressData = ProgressData(startDate: Date(timeIntervalSince1970: Double(initialTime)), initialWeight: initialWeight, currentWeight: currentWeight)
                continuation.resume(returning: progressData)
            } else {
                continuation.resume(throwing: BiltongError(code: BiltongError.Codes.deviceProvidedMalformedResponse))
            }
            
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
        
        func readStatus() async throws -> Status {
            try? await Task.sleep(for: .milliseconds(500))
            return .NOT_INITIALIZED
        }
        
        func readProgress() async throws -> ProgressData {
            try? await Task.sleep(for: .milliseconds(500))
            return ProgressData(startDate: .distantPast, initialWeight: 1, currentWeight: 1)
        }
        
        
    }
}
