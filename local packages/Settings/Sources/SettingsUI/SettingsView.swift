//
//  SettingsView.swift
//  PhoneUI
//
//  Created by Tony Tallman on 1/10/25.
//

import SwiftUI
import Foundation

import DesignSystem
import SettingsModel
import SettingsStrings
import SettingsVM

public struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    
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
                        get: { viewModel.currentKeepScreenOn },
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bikerBackground.ignoresSafeArea())
        .onAppear {
            viewModel.refreshBackgroundStatuses()
        }
    }
    
    private static func unitDisplayName(_ unit: Dimension) -> String {
        let name = unitFormatter.string(from: unit)
        let symbol = unit.symbol
        return "\(name) (\(symbol))"
    }
}

#Preview {
    SettingsView(
        viewModel: SettingsViewModel(
            settings: SettingsModel.Settings()
        )
    )
}
