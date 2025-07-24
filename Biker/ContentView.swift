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
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.white)
                    .font(.system(size: 24, weight: .bold))
                    .padding(.leading, 24)
                Spacer()
            }
            Spacer()
            VStack(spacing: 12) {
                Text(viewModel.speed)
                    .font(.system(size: 90, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                Text("km/h")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 0) {
                ForEach(0..<3) { index in
                    VStack(spacing: 6) {
                        Text(["TIME", "DISTANCE", "CADENCE"][index])
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .textCase(.uppercase)
                        Text([
                            viewModel.time,
                            viewModel.distance,
                            viewModel.cadence
                        ][index])
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.white.opacity(0.04))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding([.horizontal, .bottom], 16)
        }
        .background(Color(.sRGB, white: 0.1, opacity: 1).ignoresSafeArea())
    }
}

#Preview {
    ContentView(viewModel: ContentViewModel(speed: Measurement(value: 5.101, unit: .milesPerHour)))
}
