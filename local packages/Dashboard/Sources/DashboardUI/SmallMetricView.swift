//
//  SmallMetricView.swift
//  PhoneUI
//
//  Created from DashboardView cadence metric
//

import SwiftUI

import DashboardModel
import DesignSystem

struct SmallMetricView: View {
    let metric: Metric
    
    init(metric: Metric) {
        self.metric = metric
    }
    
    public var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(metric.title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.bikerSectionText)
                .textCase(.uppercase)
            VStack(spacing: 2) {
                Text(metric.value)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.bikerSectionText)
                Text(metric.units)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bikerSectionText.opacity(0.7))
            }
        }
    }
}

#Preview {
    SmallMetricView(
        metric: Metric(title: "CADENCE", value: "85", units: "rpm")
    )
    .padding()
    .background(Color.bikerSectionBackground)
}
