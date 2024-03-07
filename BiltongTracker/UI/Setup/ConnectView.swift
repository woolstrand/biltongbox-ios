//
//  SetupView.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 21/10/2023.
//

import SwiftUI

struct ConnectView: View {
    
    @ObservedObject var viewModel: ConnectViewModel
    
    var body: some View {
        NavigationStack {
            VStack {
                switch viewModel.state {
                case .idle:
                    Button {
                        viewModel.startScanning()
                    } label: {
                        Text("Start scanning")
                    }
                    
                case .scanning:
                    HStack (spacing: 8) {
                        ProgressView()
                        Text("Searching for devices...")
                    }
                    
                    List(viewModel.devices, id: \.id) { device in
                        Text(device.displayName)
                            .onTapGesture {
                                viewModel.connectDevice(device.id)
                            }
                    }
                    .clipShape(
                        RoundedRectangle(cornerRadius: 12)
                    )
                    
                    Button {
                        viewModel.stopScanning()
                    } label: {
                        Text("Stop scanning")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 24)
                    .enframed(cornerRadius: 8)
                    .padding(.top, 12)
                    
                case .connecting:
                    HStack {
                        ProgressView()
                        Text("Connecting to the selected device...")
                    }
                    
                case .error(let error):
                    Text("Error: " + error.localizedDescription)
                    Button {
                        viewModel.resetState()
                    } label: {
                        Text("Reset")
                    }
                }
                Spacer()
            }
            .padding(16)
            .enframed()
            .padding(.top, 48)
            .padding(16)
            .navigationDestination(isPresented: $viewModel.navigatingToSetup) {
                if let viewModel = viewModel.getSetupViewModelForNavigation() {
                    SetupView(viewModel: viewModel)
                } else {
                    Text("ERROR")
                }
            }
            .navigationDestination(isPresented: $viewModel.navigatingToBox) {
                if let viewModel = viewModel.getBoxViewModelForNavigation() {
                    BoxView(viewModel: viewModel)
                } else {
                    Text("ERROR")
                }
            }
        }
    }
}

struct ConnectView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectView(viewModel: ConnectViewModel(scannerService: BluetoothScannerComponent.Mock()))
    }
}
