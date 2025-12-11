//
//  ContentView.swift
//  Biker
//
//  Created by Tony Tallman on 1/10/25.
//

import SwiftUI
import CoreLogic

struct ContentView: View {
    @StateObject var viewModel: ContentViewModel
    
    init(viewModel: ContentViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        TabView(selection: Binding(
            get: { viewModel.selectedTab },
            set: { viewModel.selectedTab = $0 }
        )) {
            DashboardView(viewModel: viewModel.getDashboardViewModel())
                .tabItem {
                    Label("Dashboard", systemImage: "speedometer")
                }
                .tag(0)
            
            SettingsView(viewModel: viewModel.getSettingsViewModel())
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
    }
}

#if DEBUG
final class PreviewContentViewModel: ContentViewModel {
    override func getDashboardViewModel() -> DashboardViewModel {
        PreviewDashboardViewModel()
    }
    
    override func getSettingsViewModel() -> SettingsViewModel {
        PreviewSettingsViewModel()
    }
}

#Preview {
    ContentView(viewModel: PreviewContentViewModel())
}

#endif
