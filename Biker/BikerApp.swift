//
//  BikerApp.swift
//  Biker
//
//  Created by Tony Tallman on 1/10/25.
//

import SwiftUI

@main
struct BikerApp: App {
    let compositionRoot = CompositionRoot.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: compositionRoot.getContentViewModel())
        }
    }
}
