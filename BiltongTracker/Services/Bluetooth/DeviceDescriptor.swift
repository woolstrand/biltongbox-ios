//
//  DeviceDescriptor.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 22/10/2023.
//

import Foundation
import CoreBluetooth

enum DeviceDescriptor {
    static let defaultTimeout = 5.0
    static let uuid = CBUUID(string: "018b53a5-84e5-7b55-9963-f3f664a89f50")
    
    enum Characteristics {
        static let status = CBUUID(string: "abdf5f40-f3cf-4625-a2c7-12de46bc510e")
        static let readings = CBUUID(string: "8be38717-63c1-42fe-909e-0af64bfb4c8b")
        static let settings = CBUUID(string: "41659141-e392-4157-b33d-80269cf2dbe6")
        static let secureSettings = CBUUID(string: "799c188f-c60f-4a72-9a36-3284922198f0")
        static let command = CBUUID(string: "a831f156-f70d-479f-b11b-9c2a8e2203de")
//        static let commandResult = CBUUID(string: "5cb7fac1-215e-4713-bc3f-614af4278d9a")
        static let dataOut = CBUUID(string: "07c769ae-9de2-4e07-bad4-dc4f52f98790")
        
        static func charName(uuid: CBUUID) -> String {
            switch uuid {
            case status:
                "STATUS"
            case readings:
                "READINGS"
            case settings:
                "SETTINGS"
            case secureSettings:
                "SECURE SETTINGS"
            case command:
                "COMMAND"
            case dataOut:
                "DATA OUT"
            default:
                ">>UNKNOWN<<"
            }
        }
    }
}
