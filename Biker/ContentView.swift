//
//  ContentView.swift
//  Biker
//
//  Created by Tony Tallman on 1/10/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel: ContentViewModel
    
    var body: some View {
        Text("\(viewModel.speed?.description ?? "--")")
            .font(.largeTitle)
            .padding()
    }
}

#Preview {
    ContentView(viewModel: ContentViewModel(speed: Measurement(value: 5, unit: .milesPerHour)))
}
