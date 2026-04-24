//
//  HeartRateWidget.swift
//  DashboardUI
//

import SwiftUI

import DesignSystem

struct HeartRateWidget: View {
    let bpm: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
            Text(bpm)
                .font(.title3.weight(.semibold).monospacedDigit())
        }
        .foregroundStyle(Color.red)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.bikerSectionBackground.opacity(0.9))
        .clipShape(Capsule())
    }
}

#Preview {
    HeartRateWidget(bpm: "142")
        .padding()
        .background(Color.bikerBackground)
}
