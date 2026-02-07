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
            Text("Settings")
                .font(.largeTitle)
                .padding()
            
            Form {
                Section(header: Text("Units")) {
                    Picker("Speed", selection: Binding(
                        get: { viewModel.currentSpeedUnits },
                        set: { viewModel.setSpeedUnits($0) }
                    )) {
                        ForEach(viewModel.availableSpeedUnits, id: \.self) { unit in
                            Text(Self.unitDisplayName(unit)).tag(unit)
                        }
                    }
                    
                    Picker("Distance", selection: Binding(
                        get: { viewModel.currentDistanceUnits },
                        set: { viewModel.setDistanceUnits($0) }
                    )) {
                        ForEach(viewModel.availableDistanceUnits, id: \.self) { unit in
                            Text(Self.unitDisplayName(unit)).tag(unit)
                        }
                    }
                }
                
                Section(header: Text("Auto-Pause")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speed Threshold")
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bikerBackground.ignoresSafeArea())
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
            preferences: SettingsModel.Settings()
        )
    )
}
