//
//  LargeMetricView.swift
//  PhoneUI
//
//  Created from DashboardView speed metric
//

import SwiftUI

import DashboardModel
import DesignSystem

struct LargeMetricView: View {
    let metric: MetricViewModel

    init(metric: MetricViewModel) {
        self.metric = metric
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            Text(metric.value)
                .font(.system(size: 90, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(Color.bikerText)
            Text(metric.units)
                .font(.title2.weight(.medium))
                .foregroundStyle(Color.bikerTextSecondary)
        }
    }
}

#Preview {
    LargeMetricView(
        metric: MetricViewModel(title: "Speed", value: "25.5", units: "mph")
    )
    .padding()
    .background(Color.bikerBackground)
}
