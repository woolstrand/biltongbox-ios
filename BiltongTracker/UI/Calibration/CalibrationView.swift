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
                .font(.title)
                .bold()
                .padding(.top, 12)
            Text("Before starting calibration process, please ensure you have a weight of exactly 1 kg which you can easily hook up to the bar of the box. The easiest way is to use 1 liter bottle of water.")
                .font(.footnote)
                .padding(8)
                .enframed(shadow: .clear, cornerRadius: 8)
            
            Spacer()
            VStack {
                Text(viewModel.statusDesc)
                    .font(.title2)
                    .padding(.bottom, 4)
                
                Text(viewModel.statusHint)
                    .font(.footnote)
                    .padding(.horizontal, 40)
                    .multilineTextAlignment(.center)
                
                Button(viewModel.buttonTitle) {
                    viewModel.didTapActionButton()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.buttonEnabled)
                .padding(.top, 5)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .enframed()
            
            Spacer()
        }
        .padding(16)
        .enframed()
        .padding(16)
    }
}

struct CalibrationView_Previews: PreviewProvider {
    static var previews: some View {
        CalibrationView(viewModel: CalibrationViewModel(exchangeService: BluetoothExchangeComponent.Mock()))
    }
}
