//
//  MainView.swift
//  MainView
//
//  Created by Tony Tallman on 1/10/25.
//

import SwiftUI

import DashboardUI
import MainVM
import SettingsUI

public struct MainView: View {
    @State var viewModel: MainViewModel
    
    public init(viewModel: MainViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        TabView(selection: Binding(
            get: { viewModel.selectedTab },
            set: { viewModel.selectedTab = $0 }
        )) {
            DashboardView(viewModel: viewModel.getDashboardViewModel())
                .tabItem {
                    Label("Dashboard", systemImage: "speedometer")
                }
                .tag(0)
            
            SettingsUI.SettingsView(viewModel: viewModel.getSettingsViewModel())
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
    }
}

