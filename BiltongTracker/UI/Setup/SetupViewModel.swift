//
//  SetupViewModel.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 22/10/2023.
//

import Foundation
import Combine

class SetupViewModel: ObservableObject {
    
    enum CompletionRoute {
        case setupCompleted
        case setupCancelled
        case setupFailed
    }
    
    @Published var networkSSID: String = "KISHECHNIK"
    @Published var networkPassword: String = "anus_psa"
    @Published var canProceed: Bool = false
    
    private var exchangeService: BluetoothExchangeComponent.Interface
    private var completionRoute: PassthroughSubject<CompletionRoute, Never>
    
    init(exchangeService: BluetoothExchangeComponent.Interface, completionRoute: PassthroughSubject<CompletionRoute, Never>) {
        self.exchangeService = exchangeService
        self.completionRoute = completionRoute
        
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
                        self.completionRoute.send(.setupCompleted)
                    }
                } else {
                    DispatchQueue.main.async {
                        print("Setup comunication completed, but response is not OK: \(result)")
                        self.completionRoute.send(.setupFailed)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print("Setup failed with error \(error)")
                    self.completionRoute.send(.setupFailed)
                }
            }
        }
    }
}
