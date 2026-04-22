//
//  ScanView.swift
//  SettingsUI
//

import SwiftUI

import DesignSystem
import SettingsStrings
import SettingsVM

struct ScanView: View {
    @Bindable private var viewModel: ScanViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: ScanViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.discoveredSensors.isEmpty {
                    ContentUnavailableView {
                        Label(
                            String(localized: "No sensors found", bundle: .settingsStrings, comment: "Empty state when BLE scan finds no CSC sensors"),
                            systemImage: "antenna.radiowaves.left.and.right.slash"
                        )
                    } description: {
                        if viewModel.isScanning {
                            Text(
                                String(localized: "Scanning…", bundle: .settingsStrings, comment: "Shown while actively scanning for sensors")
                            )
                        }
                    }
                } else {
                    List(viewModel.discoveredSensors) { row in
                        Button {
                            viewModel.connect(sensorID: row.id)
                            dismiss()
                        } label: {
                            HStack {
                                Text(row.name)
                                Spacer()
                                if let rssi = row.rssi {
                                    Image(systemName: Self.rssiSymbol(rssi: rssi))
                                        .foregroundStyle(.secondary)
                                        .accessibilityLabel(
                                            String(localized: "Signal strength", bundle: .settingsStrings, comment: "Accessibility label for RSSI icon")
                                        )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "Scan for sensors", bundle: .settingsStrings, comment: "Navigation title for BLE sensor scan sheet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done", bundle: .settingsStrings, comment: "Dismiss sensor scan sheet")) {
                        dismiss()
                    }
                }
            }
            .overlay(alignment: .top) {
                if viewModel.isScanning, !viewModel.discoveredSensors.isEmpty {
                    ProgressView()
                        .padding(.top, 8)
                }
            }
            .onAppear {
                viewModel.startScan()
            }
            .onDisappear {
                viewModel.stopScan()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bikerBackground.ignoresSafeArea())
    }

    private static func rssiSymbol(rssi: Int) -> String {
        if rssi >= -55 {
            "wifi.3"
        } else if rssi >= -70 {
            "wifi.2"
        } else if rssi >= -85 {
            "wifi.1"
        } else {
            "wifi.slash"
        }
    }
}

#Preview {
    ScanView(
        viewModel: ScanViewModel(
            sensorProvider: PreviewSensorProvider()
        )
    )
}
