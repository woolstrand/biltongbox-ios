//
//  BoxViewModel.swift
//  BiltongTracker
//
//  Created by Igor Chertenkov on 22/10/2023.
//

import Foundation

class BoxViewModel: ObservableObject {
    private var exchangeService: BluetoothExchangeComponent.Interface
    private var scannerService: BluetoothScannerComponent.Interface

    @Published var connectionStatusString: String = ""
    @Published var processStatusString: String = ""
    @Published var initialWeightString: String = ""
    @Published var currentWeightString: String = ""
    @Published var targetWeightString: String = ""
    @Published var temperatureString: String = ""
    @Published var humidityString: String = ""
    @Published var elapsedTimeString: String = ""
    @Published var progress: Double = 1.0
    @Published var target: Double?

    @Published var processIsRunning: Bool = false
    @Published var canStart: Bool = false
    @Published var isInitialized: Bool = false
    @Published var shouldShowStartInput: Bool = false
    
    @Published var navigatingToCalibration = false
    @Published var showsAlert: Bool = false
    @Published var alert: AlertData?

    var timer: Timer? = nil
    
    init(scannerService: BluetoothScannerComponent.Interface, exchangeService: BluetoothExchangeComponent.Interface) {
        self.exchangeService = exchangeService
        self.scannerService = scannerService
        pushTime()
        updateStatus()
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    private func pushTime() {
        Task {
            do {
                let timeCommand = "TM:\(Int(Date().timeIntervalSince1970))"
                try await self.exchangeService.sendCommand(timeCommand)
            } catch {
                print("Error while setting time")
            }
        }
    }
    
    private func updateStatus() {
        Task {
            do {
                let status: Status = try await self.exchangeService.readStatus()
                await MainActor.run {
                    switch status {
                    case .INITIALIZED_IDLE:
                        processStatusString = "Idle, waiting to start"
                        processIsRunning = false
                        canStart = true
                        
                    case .PROCESS_IN_PROGRESS:
                        processStatusString = "In progress"
                        processIsRunning = true
                        canStart = false
                        
                    case .STARTING_PROCESS, .RESUMING_PROCESS, .STARTING_UP:
                        processStatusString = "Please wait..."
                        processIsRunning = false
                        canStart = false
                        
                        Task.detached {
                            try? await Task.sleep(for: .seconds(2))
                            self.updateStatus()
                        }
                        
                    case .PROCESS_FINISHED:
                        processStatusString = "Process is finished! Enjoy!"
                        processIsRunning = false
                        canStart = true
                        
                    default:
                        processStatusString = "Incorrect status. Please reset."
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
                    processStatusString = "Can't update status."
                    processIsRunning = false
                    canStart = false
                    isInitialized = true
                }
            }
        }
    }
    
    private func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        
        guard let formattedDuration = formatter.string(from: timeInterval) else {
            return "--"
        }
        
        return formattedDuration
    }
    
    private func performUpdate() {
        Task {
            do {
                let progress = try await self.exchangeService.readProgress()
                await MainActor.run {
                    self.connectionStatusString = "Connected"
                    if progress.initialWeight != 0 {
                        self.progress = progress.currentWeight / progress.initialWeight
                        self.target = progress.targetWeight / progress.initialWeight
                        self.initialWeightString = "\(progress.initialWeight) g"
                        self.currentWeightString = "\(progress.currentWeight) g"
                        self.targetWeightString = "\(progress.targetWeight) g"
                        self.temperatureString = "\(progress.temperature)˚C"
                        self.humidityString = "\(progress.humidity)%"
                        self.elapsedTimeString =  formatTimeInterval(-progress.startDate.timeIntervalSinceNow)
                    } else {
                        self.progress = 1.0
                        self.initialWeightString = "Initial weight: n/a"
                        self.currentWeightString = "Current weight: \(progress.currentWeight) g"
                    }
                }
            } catch {
                await MainActor.run {
                    self.connectionStatusString = "Connection failed"
                }
            }
        }
    }
    
    func getCalibrationViewModelForNavigation() -> CalibrationViewModel {
        CalibrationViewModel(exchangeService: exchangeService)
    }
    
    func start() {
        shouldShowStartInput = true
    }
    
    func userDidEnterTargetPercentage(_ stringValue: String) {
        canStart = false
        Task {
            do {
                let response = try await self.exchangeService.sendCommand("START:\(stringValue)")
                await MainActor.run {
                    if response == "OK" {
                        self.updateStatus()
                    } else {
                        self.processStatusString = "Could not start process."
                    }
                }
            } catch {
                await MainActor.run {
                    self.processStatusString = "Could not start process."
                }
            }
        }
    }
    
    func calibrate() {
        self.navigatingToCalibration = true
    }
    
    func forget() {
        Task {
            scannerService.forgetSavedDevice()
            await scannerService.disconnectActivePeripheral()
        }
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
                        self.processStatusString = "Could not stop process."
                    }
                }
            } catch {
                await MainActor.run {
                    self.processStatusString = "Could not stop process."
                }
            }
        }
    }
}
