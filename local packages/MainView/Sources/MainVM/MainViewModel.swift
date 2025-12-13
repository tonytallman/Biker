//
//  MainViewModel.swift
//  MainView
//
//  Created by Tony Tallman on 1/10/25.
//

import Combine
import Observation

import DashboardVM
import SettingsVM

/// Main view model that manages tab selection and provides view models for dashboard and settings.
@MainActor
@Observable
public final class MainViewModel {
    public var selectedTab: Int = 0
    
    private let dashboardViewModelFactory: () -> DashboardViewModel
    private let settingsViewModelFactory: () -> SettingsVM.SettingsViewModel
    
    public init(
        dashboardViewModelFactory: @escaping () -> DashboardViewModel,
        settingsViewModelFactory: @escaping () -> SettingsVM.SettingsViewModel,
        selectedTab: Int = 0,
    ) {
        self.selectedTab = selectedTab
        self.dashboardViewModelFactory = dashboardViewModelFactory
        self.settingsViewModelFactory = settingsViewModelFactory
    }
    
    public func getDashboardViewModel() -> DashboardViewModel {
        dashboardViewModelFactory()
    }
    
    public func getSettingsViewModel() -> SettingsVM.SettingsViewModel {
        settingsViewModelFactory()
    }
}

