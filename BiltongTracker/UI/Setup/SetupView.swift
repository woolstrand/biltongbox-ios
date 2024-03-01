//
//  SetupView.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 22/10/2023.
//

import Combine
import SwiftUI

struct SetupView: View {
    @ObservedObject var viewModel: SetupViewModel
    
    var body: some View {
        VStack {
            Text("Connect wifi")
                .padding(.top, 24)
                .padding(.vertical, 8)
            TextField("Network name", text: $viewModel.networkSSID)
            TextField("Password", text: $viewModel.networkPassword)
            Button("Apply") {
                viewModel.userDidTapConfigure()
            }
            .disabled(!viewModel.canProceed)
        }
        .padding(.horizontal, 16)
    }
}

struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        SetupView(viewModel: SetupViewModel(exchangeService: BluetoothExchangeComponent.Mock(), completionRoute: PassthroughSubject<SetupViewModel.CompletionRoute, Never>()))
    }
}
