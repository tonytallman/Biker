//
//  ContentViewModel.swift
//  CoreLogic
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation
import Combine

/// Base class for content view models.
@MainActor
open class ContentViewModel: ObservableObject {
    @Published public var selectedTab: Int = 0
    
    public init(selectedTab: Int = 0) {
        self.selectedTab = selectedTab
    }
    
    open func getDashboardViewModel() -> DashboardViewModel {
        fatalError("Subclasses must implement getDashboardViewModel()")
    }
    
    open func getSettingsViewModel() -> SettingsViewModel {
        fatalError("Subclasses must implement getSettingsViewModel()")
    }
}

/// Production implementation of ContentViewModel
final class ProductionContentViewModel: ContentViewModel {
    private let dashboardViewModelFactory: () -> DashboardViewModel
    private let settingsViewModelFactory: () -> SettingsViewModel
    
    init(
        dashboardViewModelFactory: @escaping () -> DashboardViewModel,
        settingsViewModelFactory: @escaping () -> SettingsViewModel
    ) {
        self.dashboardViewModelFactory = dashboardViewModelFactory
        self.settingsViewModelFactory = settingsViewModelFactory
        super.init()
    }
    
    override func getDashboardViewModel() -> DashboardViewModel {
        dashboardViewModelFactory()
    }
    
    override func getSettingsViewModel() -> SettingsViewModel {
        settingsViewModelFactory()
    }
}
