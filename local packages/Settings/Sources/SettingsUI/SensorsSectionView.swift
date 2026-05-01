//
//  SensorsSectionView.swift
//  SettingsUI
//

import SwiftUI

import DesignSystem
import SettingsStrings
import SettingsVM

struct SensorsSectionView: View {
    @Bindable private var viewModel: SensorsSectionViewModel
    @State private var showingScanSheet = false

    init(viewModel: SensorsSectionViewModel) {
        self._viewModel = Bindable(wrappedValue: viewModel)
    }

    var body: some View {
        Section {
            sectionBody
        } header: {
            sectionHeader
        }
    }

    @ViewBuilder
    private var sectionBody: some View {
        switch viewModel.sensorsSectionState {
        case .permissionBlocked:
            VStack(alignment: .leading, spacing: 8) {
                Text("Sensors.Permissions.Denied.Title", bundle: .settingsStrings, comment: "Title when Bluetooth permission is not granted for sensors")
                    .font(.headline)
                Text("Sensors.Permissions.Denied.Body", bundle: .settingsStrings, comment: "Explanation that user must allow Bluetooth in Settings to use sensors")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .bluetoothUnavailable:
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sensors.Bluetooth.Off.Title", bundle: .settingsStrings, comment: "Title when Bluetooth radio is off or unavailable")
                            .font(.headline)
                        Text("Sensors.Bluetooth.Off.Body", bundle: .settingsStrings, comment: "Explains that sensor lists are hidden until Bluetooth is on (iOS Settings parity)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .normal:
            ForEach(viewModel.knownSensors, id: \.sensorID) { sensor in
                NavigationLink(value: sensor.sensorID) {
                    HStack {
                        Text(sensor.title)
                        Spacer()
                        Text(sensor.statusText)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.forgetSensor(id: sensor.sensorID)
                    } label: {
                        Label(
                            String(localized: "Forget", bundle: .settingsStrings, comment: "Remove a known BLE sensor from the list"),
                            systemImage: "trash"
                        )
                    }
                    if sensor.connectionState == .connected || sensor.connectionState == .connecting {
                        Button {
                            viewModel.disconnectSensor(id: sensor.sensorID)
                        } label: {
                            Label(
                                String(localized: "Disconnect", bundle: .settingsStrings, comment: "Drop BLE connection but keep sensor known"),
                                systemImage: "wifi.slash"
                            )
                        }
                        .tint(.orange)
                    }
                }
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text("Sensors", bundle: .settingsStrings, comment: "Section header for sensors like speed and cadence")
            Spacer()
            if viewModel.sensorsSectionState != .permissionBlocked {
                Button {
                    showingScanSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.sensorsSectionState != .normal)
                .accessibilityLabel(
                    String(localized: "Scan for sensors", bundle: .settingsStrings, comment: "Accessibility: add a sensor via scan sheet")
                )
                .sheet(isPresented: $showingScanSheet) {
                    Group {
                        if let scanVM = viewModel.makeScanViewModel() {
                            ScanView(viewModel: scanVM)
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.shouldDismissScanSheet) { _, should in
            if should {
                showingScanSheet = false
                viewModel.acknowledgeScanSheetDismissal()
            }
        }
    }
}

// MARK: - Previews (SensorAvailability gating, ADR-0009 / SEN-PERM)

private struct SensorsSectionPreviewHost: View {
    let availability: SensorAvailability.PreviewCase

    var body: some View {
        NavigationStack {
            Form {
                SensorsSectionView(
                    viewModel: SensorsSectionViewModel(
                        sensorAvailability: SensorAvailability.previewStream(availability)
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bikerBackground.ignoresSafeArea())
    }
}

#Preview("Sensors | not determined") {
    SensorsSectionPreviewHost(availability: .notDetermined)
}

#Preview("Sensors | denied") {
    SensorsSectionPreviewHost(availability: .denied)
}

#Preview("Sensors | restricted") {
    SensorsSectionPreviewHost(availability: .restricted)
}

#Preview("Sensors | unsupported") {
    SensorsSectionPreviewHost(availability: .unsupported)
}

#Preview("Sensors | resetting") {
    SensorsSectionPreviewHost(availability: .resetting)
}

#Preview("Sensors | powered off") {
    SensorsSectionPreviewHost(availability: .poweredOff)
}

#Preview("Sensors | available (BLE on)") {
    SensorsSectionPreviewHost(availability: .available)
}

// MARK: - Sensor Details: dismiss when known row removed upstream (SEN-DET-4)

struct SensorDetailsNavigationHost: View {
    let sensorID: UUID
    @Bindable var sensorsSection: SensorsSectionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let detailsVM = sensorsSection.makeSensorDetailsViewModel(
                for: sensorID,
                dismiss: { dismiss() }
            ) {
                SensorDetailsView(viewModel: detailsVM)
                    .onChange(of: sensorsSection.knownSensorIDs) { _, ids in
                        if !ids.contains(sensorID) {
                            dismiss()
                        }
                    }
            } else {
                Color.bikerBackground
                    .onAppear { dismiss() }
            }
        }
    }
}
