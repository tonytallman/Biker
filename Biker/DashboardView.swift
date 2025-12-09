//
//  ContentView.swift
//  Biker
//
//  Created by Tony Tallman on 1/10/25.
//

import SwiftUI
import CoreLogic

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    init(viewModel: DashboardViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 12) {
                Text(viewModel.speed)
                    .font(.system(size: 90, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(Color.bikerText)
                Text(viewModel.speedUnits)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Color.bikerTextSecondary)
            }
            Spacer()
            HStack(spacing: 0) {
                ForEach(0..<3) { index in
                    VStack(spacing: 6) {
                        Text(["TIME", "DISTANCE", "CADENCE"][index])
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Color.bikerSectionText)
                            .textCase(.uppercase)
                        Text([
                            viewModel.time,
                            viewModel.distance,
                            viewModel.cadence
                        ][index])
                            .font(.title.weight(.bold))
                            .foregroundStyle(Color.bikerSectionText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.bikerSectionBackground)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding([.horizontal, .bottom], 16)
        }
        .background(Color.bikerBackground.ignoresSafeArea())
    }
}

#if DEBUG
final class PreviewDashboardViewModel: DashboardViewModel {
    init(
        speed: String = "25.5",
        speedUnits: String = "mph",
        time: String = "12:34",
        distance: String = "5.2 mi",
        cadence: String = "85 rpm"
    ) {
        super.init()
        self.speed = speed
        self.speedUnits = speedUnits
        self.time = time
        self.distance = distance
        self.cadence = cadence
    }
}
#endif

#Preview {
    DashboardView(viewModel: PreviewDashboardViewModel())
}
