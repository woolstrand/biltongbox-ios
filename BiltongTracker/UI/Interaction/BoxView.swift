//
//  BoxView.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 22/10/2023.
//

import SwiftUI

struct BoxView: View {
    @ObservedObject var viewModel: BoxViewModel
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            .background {
                Color.blue
            }
    }
}

struct BoxView_Previews: PreviewProvider {
    static var previews: some View {
        BoxView(viewModel: BoxViewModel(exchangeService: BluetoothExchangeComponent.Mock()))
    }
}
