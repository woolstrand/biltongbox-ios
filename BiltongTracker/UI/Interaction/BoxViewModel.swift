//
//  BoxViewModel.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 22/10/2023.
//

import Foundation

class BoxViewModel: ObservableObject {
    private var exchangeService: BluetoothExchangeComponent.Interface
    
    @Published var statusString: String = ""
    @Published var initialWeightString: String = ""
    @Published var currentWeightString: String = ""
    @Published var elapsedTimeString: String = ""
    @Published var progress: Double = 1.0

    @Published var processIsRunning: Bool = false
    @Published var canStart: Bool = false
    @Published var isInitialized: Bool = false
    
    @Published var navigatingToCalibration = false
    @Published var showsAlert: Bool = false
    @Published var alert: AlertData?

    var timer: Timer? = nil
    
    init(exchangeService: BluetoothExchangeComponent.Interface) {
        self.exchangeService = exchangeService
        updateStatus()
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    private func updateStatus() {
        Task {
            do {
                let status: Status = try await self.exchangeService.readStatus()
                await MainActor.run {
                    switch status {
                    case .INITIALIZED_IDLE:
                        statusString = "Idle, waiting to start"
                        processIsRunning = false
                        canStart = true
                        
                    case .PROCESS_IN_PROGRESS:
                        statusString = "In progress"
                        processIsRunning = true
                        canStart = false
                        
                    case .STARTING_PROCESS, .RESUMING_PROCESS, .STARTING_UP:
                        statusString = "Please wait..."
                        processIsRunning = false
                        canStart = false
                        
                        Task.detached {
                            try? await Task.sleep(for: .seconds(2))
                            self.updateStatus()
                        }
                        
                    case .PROCESS_FINISHED:
                        statusString = "Process is finished! Enjoy!"
                        processIsRunning = false
                        canStart = true
                        
                    default:
                        statusString = "Incorrect status. Please reset."
                        processIsRunning = false
                        canStart = false
                    }
                    
                    if processIsRunning {
                        if self.timer != nil {
                            self.timer?.invalidate()
                            self.timer = nil
                        }
                        
                        self.timer = .scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] _ in
                            self?.performUpdate()
                        })
                    }
                    
                    self.isInitialized = true
                }
            } catch {
                await MainActor.run {
                    statusString = "Can't update status."
                    processIsRunning = false
                    canStart = false
                    isInitialized = true
                }
            }
        }
    }
    
    private func performUpdate() {
        Task {
            do {
                let progress = try await self.exchangeService.readProgress()
                await MainActor.run {
                    self.statusString = "Connected"
                    if progress.initialWeight != 0 {
                        self.progress = progress.currentWeight / progress.initialWeight
                        self.initialWeightString = "Initial weight: \(progress.initialWeight) g"
                        self.currentWeightString = "Current weight: \(progress.currentWeight) g"
                        self.elapsedTimeString = "\(progress.startDate.timeIntervalSinceNow)"
                    } else {
                        self.progress = 1.0
                        self.initialWeightString = "Initial weight: n/a"
                        self.currentWeightString = "Current weight: \(progress.currentWeight) g"
                    }
                }
            } catch {
                await MainActor.run {
                    self.statusString = "Connection failed"
                }
            }
        }
    }
    
    func getCalibrationViewModelForNavigation() -> CalibrationViewModel {
        CalibrationViewModel(exchangeService: exchangeService)
    }
    
    func start() {
        canStart = false
        Task {
            do {
                let response = try await self.exchangeService.sendCommand("START")
                await MainActor.run {
                    if response == "OK" {
                        self.updateStatus()
                    } else {
                        self.statusString = "Could not start process."
                    }
                }
            } catch {
                await MainActor.run {
                    self.statusString = "Could not start process."
                }
            }
        }
    }
    
    func calibrate() {
        self.navigatingToCalibration = true
    }
    
    func stop() {
        alert = AlertData(
            title: "Confirm your action",
            message: "You're going to terminate current process. Are you sure?",
            actions: [
                AlertAction(
                    title: "Yes",
                    action: {
                        self.doStop()
                    }
                ),
                AlertAction(
                    title: "No",
                    action: nil
                )
            ]
        )
        showsAlert =  true
    }
    
    private func doStop() {
        Task {
            do {
                let response = try await self.exchangeService.sendCommand("STOP")
                await MainActor.run {
                    if response == "OK" {
                        self.updateStatus()
                    } else {
                        self.statusString = "Could not stop process."
                    }
                }
            } catch {
                await MainActor.run {
                    self.statusString = "Could not stop process."
                }
            }
        }
    }
}
