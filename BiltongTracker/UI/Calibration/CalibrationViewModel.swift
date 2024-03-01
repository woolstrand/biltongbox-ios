//
//  CalibrationViewModel.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 11/11/2023.
//

import Foundation
import Combine

class CalibrationViewModel: ObservableObject {
    enum Status {
        case idle
        case starting
        case step1
        case step2
        case done
        case failed
    }
    
    @Published var status: Status = .idle
    
    var statusDesc: String {
        switch status {
        case .idle:
            "Idle"
            
        case .starting:
            "Initializing..."
            
        case .step1:
            "Measuring empty weight"
            
        case .step2:
            "Measuring reference weight"
        
        case .done:
            "Done"
        
        case .failed:
            "Failed"
        }
    }
    
    var statusHint: String {
        switch status {
        case .idle:
            "press the button below to begin"
            
        case .starting:
            "please wait for connection to be established"
            
        case .step1:
            "remove everything from the bar and tap \"continue\""
            
        case .step2:
            "place 1000g weight to the center of the bar and tap \"continue\""
        
        case .done:
            "calibration done!"
        
        case .failed:
            "calibration failed. try again."
        }
    }
    
    var buttonTitle: String {
        switch status {
        case .idle:
            "Start"
            
        case .starting:
            "wait..."
            
        case .step1:
            "Continue"
            
        case .step2:
            "Continue"
            
        case .done:
            "Back"
            
        case .failed:
            "Try again"
        }
    }
    
    var buttonEnabled: Bool {
        switch status {
        case .starting:
            false
            
        default:
            true
        }
    }
    
    private var exchangeService: BluetoothExchangeComponent.Interface
    
    init(exchangeService: BluetoothExchangeComponent.Interface) {
        self.exchangeService = exchangeService
    }
    
    private func updateStatus(_ status: Status) async {
        await MainActor.run {
            self.status = status
        }
    }
    
    func didTapActionButton() {
        switch status {
        case .idle:
            Task {
                await updateStatus(.starting)
                do {
                    let result = try await self.exchangeService.sendCommand("CAL")
                    print("result: \(result)")
                    await updateStatus(.step1)
                } catch {
                    print("starting failed with error: \(error)")
                    await updateStatus(.failed)
                }
            }
        case .starting:
            break
            
        case .step1:
            Task {
                do {
                    let result = try await self.exchangeService.sendCommand("CAL+")
                    print("result: \(result)")
                    await updateStatus(.step2)
                } catch {
                    await updateStatus(.failed)
                }
            }

        case .step2:
            Task {
                do {
                    let result = try await self.exchangeService.sendCommand("CAL+")
                    print("result: \(result)")
                    await updateStatus(.done)
                } catch {
                    await updateStatus(.failed)
                }
            }
        case .done:
            break
            
        case .failed:
            self.status = .idle
        }
    }
}
