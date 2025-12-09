//
//  SettingsView.swift
//  Biker
//
//  Created by Tony Tallman on 1/10/25.
//

import SwiftUI
import CoreLogic

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    init(viewModel: SettingsViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack {
            Text("Settings")
                .font(.largeTitle)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bikerBackground.ignoresSafeArea())
    }
}

#if DEBUG
final class PreviewSettingsViewModel: SettingsViewModel {
    init(speedUnits: String = "mph") {
        super.init()
        self.speedUnits = speedUnits
    }
}
#endif

#Preview {
    SettingsView(viewModel: PreviewSettingsViewModel())
}

