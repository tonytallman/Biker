//
//  Biker_watch_appApp.swift
//  Biker watch app Watch App
//
//  Created by Tony Tallman on 11/22/25.
//

import SwiftUI

@main
struct Biker_watch_app_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView(viewModel: DashboardViewModel())
        }
    }
}
