//
//  Errors.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 22/10/2023.
//

import Foundation

struct BiltongError: Error {
    enum Codes {
        // Generic
        static let genericProxyError = 1
        
        // Bluetooth generic
        static let deviceNotFound = 1001 // device you're trying to connect can't be found in device list
        static let connectionFailure = 1002
        static let connectionTimeout = 1003
        
        static let deviceNotReady = 1010
        static let communicationInProgress = 1012 // device is already executing the same type of command
        
        // Device communication outcomes
        static let deviceInUnknownState = 2001
        static let deviceReportedError = 2002
        static let deviceProvidedMalformedResponse = 2003
        static let dataExchangeTimeout = 2005
        
        // Generic data errors
        static let malformedInput = 8001 // input parameter can't be processed
    }
    
    
    let code: Int
    let description: String
    let underlyingError: Error?
    
    var localizedDescription: String {
        "\(code): \(description)"
    }
    
    init(code: Int, description: String, underlyingError: Error? = nil) {
        self.code = code
        self.description = description
        self.underlyingError = underlyingError
    }
    
    init(code: Int, underlyingError: Error? = nil) {
        self.underlyingError = underlyingError
        self.code = code
        
        switch code {
        case Codes.genericProxyError:
            description = "This is a proxy error. It should never be used without custom description."
            assertionFailure("Trying to use proxy error without providing description or underlying error")
            
        case Codes.deviceNotFound:
            description = "Device you're trying to connect is not on a found devices list"
            
        case Codes.connectionFailure:
            description = "Device connection attempt failed. Reason: \(underlyingError?.localizedDescription ?? "n/a")"
            
        case Codes.connectionTimeout:
            description = "Conection attempt timed out"
            
        case Codes.deviceNotReady:
            description = "Device is not ready yet for data exchange"
            
        case Codes.communicationInProgress:
            description = "Communication channel is busy with ongoing operation."
            
        case Codes.deviceInUnknownState:
            description = "Device state is unknown to the app."
            
        case Codes.deviceProvidedMalformedResponse:
            description = "Device response could not be parsed."
            
        case Codes.dataExchangeTimeout:
            description = "Device did not respond in time."
            
        case Codes.malformedInput:
            description = "Input parameter could not be processed."
            
        default:
            description = "No information provided for that code."
        }
    }
}
