//
//  SettingsView.swift
//  PhoneUI
//
//  Created by Tony Tallman on 1/10/25.
//

import SwiftUI
import Foundation

import DesignSystem
import SettingsStrings
import SettingsVM

public struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    @State private var showingScanSheet = false

    private static let unitFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .long
        return formatter
    }()
    
    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            Text("Settings", bundle: .settingsStrings, comment: "Settings screen title")
                .font(.largeTitle)
                .padding()
            
            Form {
                Section(header: Text("Units", bundle: .settingsStrings, comment: "Section header for speed and distance unit pickers")) {
                    Picker(String(localized: "Speed", bundle: .settingsStrings, comment: "Picker label for speed unit (e.g. mph, km/h)"), selection: Binding(
                        get: { viewModel.currentSpeedUnits },
                        set: { viewModel.setSpeedUnits($0) }
                    )) {
                        ForEach(viewModel.availableSpeedUnits, id: \.self) { unit in
                            Text(Self.unitDisplayName(unit)).tag(unit)
                        }
                    }
                    
                    Picker(String(localized: "Distance", bundle: .settingsStrings, comment: "Picker label for distance unit (e.g. miles, km)"), selection: Binding(
                        get: { viewModel.currentDistanceUnits },
                        set: { viewModel.setDistanceUnits($0) }
                    )) {
                        ForEach(viewModel.availableDistanceUnits, id: \.self) { unit in
                            Text(Self.unitDisplayName(unit)).tag(unit)
                        }
                    }
                }
                
                Section(header: Text("Auto-Pause", bundle: .settingsStrings, comment: "Section header for auto-pause ride detection settings")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speed Threshold", bundle: .settingsStrings, comment: "Label for speed below which the app auto-pauses the ride")
                            Spacer()
                            Text(String(format: "%.1f %@", viewModel.currentAutoPauseThreshold.converted(to: viewModel.currentSpeedUnits).value, viewModel.currentSpeedUnits.symbol))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { viewModel.currentAutoPauseThreshold.converted(to: viewModel.currentSpeedUnits).value },
                                set: { newValue in
                                    let newThreshold = Measurement(value: newValue, unit: viewModel.currentSpeedUnits)
                                    viewModel.setAutoPauseThreshold(newThreshold)
                                }
                            ),
                            in: 0...10
                        )
                    }
                }
                
                Section(header: Text("System", bundle: .settingsStrings, comment: "Section header for system toggles and permissions")) {
                    Toggle(isOn: Binding(
                        get: { viewModel.keepScreenOn },
                        set: { viewModel.setKeepScreenOn($0) }
                    )) {
                        Text("Keep screen on", bundle: .settingsStrings, comment: "Toggle to prevent screen from sleeping during a ride")
                    }
                    
                    HStack {
                        Text("Location in Background", bundle: .settingsStrings, comment: "Row label for location permission status when app is in background")
                        Spacer()
                        Text(viewModel.locationBackgroundStatusText)
                            .foregroundColor(.secondary)
                        Button {
                            viewModel.openLocationPermissions()
                        } label: {
                            Image(systemName: "arrow.up.forward.app")
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    HStack {
                        Text("Bluetooth in Background", bundle: .settingsStrings, comment: "Row label for Bluetooth permission status when app is in background")
                        Spacer()
                        Text(viewModel.bluetoothBackgroundStatusText)
                            .foregroundColor(.secondary)
                        Button {
                            viewModel.openBluetoothPermissions()
                        } label: {
                            Image(systemName: "arrow.up.forward.app")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Section {
                    switch viewModel.sensorsSectionState {
                    case .permissionBlocked:
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sensors.Permissions.Denied.Title", bundle: .settingsStrings, comment: "Title when Bluetooth permission is not granted for sensors")
                                .font(.headline)
                            Text("Sensors.Permissions.Denied.Body", bundle: .settingsStrings, comment: "Explanation that user must allow Bluetooth in Settings to use sensors")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    case .bluetoothUnavailable:
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Sensors.Bluetooth.Off.Title", bundle: .settingsStrings, comment: "Title when Bluetooth radio is off or unavailable")
                                        .font(.headline)
                                    Text("Sensors.Bluetooth.Off.Body", bundle: .settingsStrings, comment: "Explains that sensor lists are hidden until Bluetooth is on (iOS Settings parity)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    case .normal:
                        ForEach(viewModel.knownSensors, id: \.sensorID) { sensor in
                            HStack {
                                Text(sensor.title)
                                Spacer()
                                Text(sensor.connectionState.localizedStatusText)
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    viewModel.forgetSensor(id: sensor.sensorID)
                                } label: {
                                    Label(
                                        String(localized: "Forget", bundle: .settingsStrings, comment: "Remove a known BLE sensor from the list"),
                                        systemImage: "trash"
                                    )
                                }
                                if sensor.connectionState == .connected || sensor.connectionState == .connecting {
                                    Button {
                                        viewModel.disconnectSensor(id: sensor.sensorID)
                                    } label: {
                                        Label(
                                            String(localized: "Disconnect", bundle: .settingsStrings, comment: "Drop BLE connection but keep sensor known"),
                                            systemImage: "wifi.slash"
                                        )
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Sensors", bundle: .settingsStrings, comment: "Section header for sensors like speed and cadence")
                        Spacer()
                        if viewModel.sensorsSectionState != .permissionBlocked {
                            Button {
                                showingScanSheet = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.borderless)
                            .disabled(viewModel.sensorsSectionState != .normal)
                            .accessibilityLabel(
                                String(localized: "Scan for sensors", bundle: .settingsStrings, comment: "Accessibility: add a sensor via scan sheet")
                            )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bikerBackground.ignoresSafeArea())
        .onAppear {
            viewModel.refreshBackgroundStatuses()
        }
        .sheet(isPresented: $showingScanSheet) {
            Group {
                if let scanVM = viewModel.makeScanViewModel() {
                    ScanView(viewModel: scanVM)
                }
            }
        }
        .onChange(of: viewModel.shouldDismissScanSheet) { _, should in
            if should {
                showingScanSheet = false
                viewModel.acknowledgeScanSheetDismissal()
            }
        }
    }
    
    private static func unitDisplayName(_ unit: Dimension) -> String {
        let name = unitFormatter.string(from: unit)
        let symbol = unit.symbol
        return "\(name) (\(symbol))"
    }
}

#Preview {
    let storage = InMemorySettingsStorage()
    SettingsView(
        viewModel: SettingsViewModel(
            metricsSettings: DefaultMetricsSettings(storage: storage),
            systemSettings: DefaultSystemSettings(storage: storage),
            sensorAvailability: SensorAvailability.preview
        )
    )
}
