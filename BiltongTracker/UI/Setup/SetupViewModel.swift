//
//  SetupViewModel.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 22/10/2023.
//

import Foundation
import Combine

class SetupViewModel: ObservableObject {
    
    @Published var networkSSID: String = ""
    @Published var networkPassword: String = ""
    @Published var canProceed: Bool = false
    
    private var exchangeService: BluetoothExchangeComponent.Interface
    
    init(exchangeService: BluetoothExchangeComponent.Interface) {
        self.exchangeService = exchangeService
        
        $networkSSID
            .combineLatest($networkPassword)
            .map { values in
                values.0.count > 1 && values.1.count > 0
            }
            .assign(to: &$canProceed)
    }
    
    func userDidTapConfigure() {
        Task {
            let command = "WN:\(networkSSID.count):\(networkPassword.count):\(networkSSID)\(networkPassword)"
            do {
                let result = try await exchangeService.sendCommand(command)
                if result == "OK" {
                    DispatchQueue.main.async {
                        print("Setup completed successfully, will go further from here (replace stack)")
                    }
                } else {
                    DispatchQueue.main.async {
                        print("Setup comunication completed, but response is not OK, but \(result)")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print("Setup failed with error \(error)")
                }
            }
        }
    }
}
