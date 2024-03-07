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
                .font(.title)
                .padding(.top, 12)
                .padding(.vertical, 8)
            TextField("Network name", text: $viewModel.networkSSID)
                .textFieldStyle(.roundedBorder)
            TextField("Password", text: $viewModel.networkPassword)
                .textFieldStyle(.roundedBorder)
            Button("Apply") {
                viewModel.userDidTapConfigure()
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canProceed)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .enframed()
        .padding(16)
    }
}

struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        SetupView(viewModel: SetupViewModel(exchangeService: BluetoothExchangeComponent.Mock(), completionRoute: PassthroughSubject<SetupViewModel.CompletionRoute, Never>()))
    }
}
