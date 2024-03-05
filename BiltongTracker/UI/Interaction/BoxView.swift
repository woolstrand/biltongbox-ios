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
            ZStack {
                if viewModel.isInitialized {
                    VStack {
                        VStack {
                            Text("Weight status")
                                .font(.title)
                                .bold()
                                .padding(8)
                            
                            WedgeProgressView(
                                progress: viewModel.progress,
                                target: viewModel.target
                            )
                            .animation(.easeIn, value: viewModel.progress)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                            
                            HStack(alignment: .center) {
                                VStack {
                                    Text("INITIAL")
                                        .font(.footnote)
                                    Text(viewModel.initialWeightString)
                                }
                                .padding(8)
                                .enframed(cornerRadius: 8)
                                
                                TripleRightArrow()
                                
                                VStack {
                                    Text("NOW")
                                        .font(.footnote)
                                    Text(viewModel.currentWeightString)
                                }
                                .padding(8)
                                .enframed(
                                    background: .green.opacity(0.1),
                                    outline: .green.opacity(0.1),
                                    shadow: .green.opacity(0.3),
                                    cornerRadius: 8
                                )
                                
                                TripleRightArrow()
                                
                                VStack {
                                    Text("TARGET")
                                        .font(.footnote)
                                    Text(viewModel.targetWeightString)
                                }
                                .padding(8)
                                .enframed(cornerRadius: 8)
                                
                            }
                            .padding(.horizontal, 16)
                            
                            Text("TIME ELAPSED: \(viewModel.elapsedTimeString)")
                                .font(.footnote)
                                .padding(.vertical, 4)
                                .padding(.bottom, 8)
                        }
                        .enframed()
                        .padding(16)
                        
                        VStack {
                            Text("Internal conditions")
                                .bold()
                            HStack(spacing: 0) {
                                Image("icon_temperature")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                Text(viewModel.temperatureString)
                                    .font(.title2)
                                
                                Divider()
                                    .frame(height: 20)
                                    .padding(.horizontal, 16)
                                
                                Image("icon_humidity")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                Text(viewModel.humidityString)
                                    .font(.title2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .enframed()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            if viewModel.canStart {
                                Button(action: viewModel.start, label: {
                                    VStack {
                                        Image(systemName: "play.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 32))
                                            .padding(.bottom, 4)
                                        Text("Start")
                                    }
                                })
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .enframed(outline: .black.opacity(0.1), shadow: .clear, cornerRadius: 12)
                            } else {
                                Button(action: viewModel.stop, label: {
                                    VStack {
                                        Image(systemName: "stop.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 32))
                                            .padding(.bottom, 4)
                                        Text("Stop")
                                    }
                                })
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .enframed(outline: .black.opacity(0.1), shadow: .clear, cornerRadius: 12)
                            }
                            
                            
                            Button(action: viewModel.calibrate, label: {
                                VStack {
                                    Image(systemName: "scalemass")
                                        .foregroundColor(.black)
                                        .font(.system(size: 32))
                                        .padding(.bottom, 4)
                                    Text("Calibrate")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .enframed(outline: .black.opacity(0.1), shadow: .clear, cornerRadius: 12)
                            })
                            
                            Button(action: viewModel.forget, label: {
                                VStack {
                                    Image(systemName: "bolt.horizontal.circle")
                                        .foregroundColor(.black)
                                        .font(.system(size: 32))
                                        .padding(.bottom, 4)
                                    Text("Disconnect")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .enframed(outline: .black.opacity(0.1), shadow: .clear, cornerRadius: 12)
                            })
                        }
                        .padding(12)
                        .enframed()
                        .padding(.bottom, 32)
                        .padding(.horizontal, 16)
                    }
                } else {
                    ProgressView("Connecting...").progressViewStyle(CircularProgressViewStyle())
                }
                
                if viewModel.shouldShowStartInput {
                    VStack {
                        SliderInputView(
                            value: 60.0,
                            continueAction: { value in
                                viewModel.userDidEnterTargetPercentage(value)
                            },
                            cancelAction: {
                                viewModel.shouldShowStartInput = false
                            },
                            caption: "Target weight",
                            details: "Please select target weight percentage. 60% means that from 1 kg of meat you will get  600 g of final product.")
                        .padding(.horizontal, 24)
                        .padding(.top, 48)
                        
                        Spacer()
                    }
                    .background(Color.black.opacity(0.6))
                    .animation(.easeInOut, value: viewModel.shouldShowStartInput)
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
    
}

struct BoxView_Previews: PreviewProvider {
    static var previews: some View {
        BoxView(
            viewModel: BoxViewModel(
                scannerService: BluetoothScannerComponent.Mock(),
                exchangeService: BluetoothExchangeComponent.Mock()
            )
        )
    }
}
