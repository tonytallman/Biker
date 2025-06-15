//
//  BikerApp.swift
//  Biker
//
//  Created by Tony Tallman on 1/10/25.
//

import SwiftUI

@main
struct BikerApp: App {
    let dependencyContainer = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: dependencyContainer.getContentViewModel())
        }
    }
}
