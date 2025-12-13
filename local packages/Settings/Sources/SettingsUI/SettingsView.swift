//
//  SettingsView.swift
//  PhoneUI
//
//  Created by Tony Tallman on 1/10/25.
//

import SwiftUI

import DesignSystem
import SettingsVM

public struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    
    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            Text("Settings")
                .font(.largeTitle)
                .padding()
            
            Form {
                Section(header: Text("Speed Units")) {
                    Picker("Speed Units", selection: Binding(
                        get: { viewModel.currentSpeedUnits },
                        set: { viewModel.setSpeedUnits($0) }
                    )) {
                        ForEach(viewModel.availableSpeedUnits, id: \.self) { unit in
                            Text(unitDisplayName(unit)).tag(unit)
                        }
                    }
                }
                
                Section(header: Text("Distance Units")) {
                    Picker("Distance Units", selection: Binding(
                        get: { viewModel.currentDistanceUnits },
                        set: { viewModel.setDistanceUnits($0) }
                    )) {
                        ForEach(viewModel.availableDistanceUnits, id: \.self) { unit in
                            Text(unitLengthDisplayName(unit)).tag(unit)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bikerBackground.ignoresSafeArea())
    }
    
    private func unitDisplayName(_ unit: UnitSpeed) -> String {
        switch unit {
        case .milesPerHour:
            return "Miles per Hour (mph)"
        case .kilometersPerHour:
            return "Kilometers per Hour (km/h)"
        default:
            return unit.symbol
        }
    }
    
    private func unitLengthDisplayName(_ unit: UnitLength) -> String {
        switch unit {
        case .miles:
            return "Miles (mi)"
        case .kilometers:
            return "Kilometers (km)"
        default:
            return unit.symbol
        }
    }
}
