//
//  ContentView.swift
//  Biker watch app Watch App
//
//  Created by Tony Tallman on 11/22/25.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        ZStack {
            // Simple solid background for readability
            Color.black.ignoresSafeArea()

            VStack(spacing: 8) {
                Text(String(format: "%.1f", viewModel.speed))
                    .font(.system(size: 90, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text(viewModel.unit.uppercased())
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                
            }
            .padding()
        }
    }
}

#Preview {
    ContentView(viewModel: ContentViewModel())
}
