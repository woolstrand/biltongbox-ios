//
//  BoxViewModel.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 22/10/2023.
//

import Foundation

class BoxViewModel: ObservableObject {
    private var exchangeService: BluetoothExchangeComponent.Interface
    
    init(exchangeService: BluetoothExchangeComponent.Interface) {
        self.exchangeService = exchangeService
    }
}
