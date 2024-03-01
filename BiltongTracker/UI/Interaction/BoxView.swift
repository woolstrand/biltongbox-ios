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
        NavigationStack {
            if viewModel.isInitialized {
                Text("\(viewModel.statusString)")
                
                if viewModel.processIsRunning {
                    Text("\(viewModel.elapsedTimeString)")
                    Text("\(viewModel.initialWeightString)")
                    Text("\(viewModel.currentWeightString)")
                }
                
                WedgeProgressView(progress: viewModel.progress, hint: "")
                    .animation(.easeIn, value: viewModel.progress)
                
                Button(action: viewModel.start, label: {
                    Text("Start")
                })
                .disabled(!viewModel.canStart)
                
                Button(action: viewModel.stop, label: {
                    Text("Stop and reset")
                })
                .disabled(viewModel.canStart)
                
                Button(action: viewModel.calibrate, label: {
                    Text("Calibrate")
                })
                .padding(.top, 28)
            } else {
                ProgressView("Connecting...").progressViewStyle(CircularProgressViewStyle())
            }
        }
        .navigationDestination(isPresented: $viewModel.navigatingToCalibration) {
            let viewModel = viewModel.getCalibrationViewModelForNavigation()
            CalibrationView(viewModel: viewModel)
        }
        .alert(
            "",
            isPresented: $viewModel.showsAlert,
            presenting: viewModel.alert) { alert in
                Button(
                    role: .destructive) {
                        alert.actions[0].action?()
                    } label: {
                        Text(alert.actions[0].title)
                    }
                Button(
                    role: .cancel) {
                        alert.actions[1].action?()
                    } label: {
                        Text(alert.actions[1].title)
                    }
            } message: { alert in
                Text(alert.message)
            }
    }
    
}

struct BoxView_Previews: PreviewProvider {
    static var previews: some View {
        BoxView(viewModel: BoxViewModel(exchangeService: BluetoothExchangeComponent.Mock()))
    }
}
