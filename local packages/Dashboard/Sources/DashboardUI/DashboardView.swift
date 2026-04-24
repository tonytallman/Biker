//
//  DashboardView.swift
//  PhoneUI
//
//  Dashboard view using LargeMetricView and SmallMetricView components
//

import SwiftUI

import DashboardVM
import DesignSystem

public struct DashboardView: View {
    @State var viewModel: DashboardViewModel
    
    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            Spacer()
            LargeMetricView(metric: viewModel.primaryMetric)
            Spacer()
            HStack(alignment: .top, spacing: 0) {
                // Time metric
                SmallMetricView(metric: viewModel.secondaryMetric1)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.vertical, 24)
                
                // Distance metric
                SmallMetricView(metric: viewModel.secondaryMetric2)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.vertical, 24)
                
                // Cadence metric
                SmallMetricView(metric: viewModel.secondaryMetric3)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.vertical, 24)
            }
            .background(Color.bikerSectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding([.horizontal, .bottom], 16)
        }
        .background(Color.bikerBackground.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            if let bpm = viewModel.heartRateBPM {
                HeartRateWidget(bpm: bpm)
                    .padding(.top, 12)
                    .padding(.trailing, 16)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.default, value: viewModel.heartRateBPM)
    }
}
