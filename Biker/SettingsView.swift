//
//  SettingsView.swift
//  Biker
//
//  Created by Tony Tallman on 1/10/25.
//

import SwiftUI
import Combine
import CoreLogic

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    init(viewModel: SettingsViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }
    
    var body: some View {
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

#if DEBUG
final class PreviewPreferences: SettingsViewModel.Preferences {
    private let speedUnitsSubject = CurrentValueSubject<UnitSpeed, Never>(.milesPerHour)
    private let distanceUnitsSubject = CurrentValueSubject<UnitLength, Never>(.miles)
    
    var speedUnits: AnyPublisher<UnitSpeed, Never> {
        speedUnitsSubject.eraseToAnyPublisher()
    }
    
    var distanceUnits: AnyPublisher<UnitLength, Never> {
        distanceUnitsSubject.eraseToAnyPublisher()
    }
    
    func setSpeedUnits(_ units: UnitSpeed) {
        speedUnitsSubject.send(units)
    }
    
    func setDistanceUnits(_ units: UnitLength) {
        distanceUnitsSubject.send(units)
    }
}

final class PreviewSettingsViewModel: SettingsViewModel {
    init() {
        super.init(preferences: PreviewPreferences())
    }
}

#Preview {
    SettingsView(viewModel: PreviewSettingsViewModel())
}

#endif
