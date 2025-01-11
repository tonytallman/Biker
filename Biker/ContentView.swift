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
        VStack {
            Text("\(viewModel.speed?.description ?? "--")")
                .font(.largeTitle)
                .padding()
            Text("Add comments.")
            Text("Add Preferences type with units preference.")
            Text("Add speed decorator to convert to preferred units.")
        }
    }
}

#Preview {
    ContentView(viewModel: ContentViewModel(speed: Measurement(value: 5, unit: .milesPerHour)))
}
