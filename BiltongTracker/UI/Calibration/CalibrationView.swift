//
//  CalibrationView.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 11/11/2023.
//

import SwiftUI

struct CalibrationView: View {

    @ObservedObject var viewModel: CalibrationViewModel

    var body: some View {
        VStack {
            Text("Calibration")
            Spacer()
            Text(viewModel.statusDesc)
                .font(.title)
                .bold()
            
            Text(viewModel.statusHint)
                .padding(.horizontal, 40)
                .multilineTextAlignment(.center)
            
            Button(viewModel.buttonTitle) {
                viewModel.didTapActionButton()
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.buttonEnabled)
            .padding(.top, 5)
            
            Spacer()
        }
    }
}

struct CalibrationView_Previews: PreviewProvider {
    static var previews: some View {
        CalibrationView(viewModel: CalibrationViewModel(exchangeService: BluetoothExchangeComponent.Mock()))
    }
}
