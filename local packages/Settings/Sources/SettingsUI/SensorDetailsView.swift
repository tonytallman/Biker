//
//  SensorDetailsView.swift
//  SettingsUI
//

import SwiftUI

import DesignSystem
import SettingsStrings
import SettingsVM

struct SensorDetailsView: View {
    @Bindable private var viewModel: SensorDetailsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showForgetConfirmation = false

    private static let wheelDiameterMMRange: ClosedRange<Int> = 400...900

    /// Fallback matches the plan when binding runs before the first wheel stream emission.
    private var wheelMillimetersForUI: Int {
        Int(
            round(
                (viewModel.wheelDiameter ?? .init(value: 0.7, unit: .meters))
                    .converted(to: .millimeters).value
            )
        )
    }

    private var wheelDiameterLabel: String {
        let format = String(
            localized: "SensorDetails.WheelDiameter.LabelMM",
            bundle: .settingsStrings,
            comment: "Wheel diameter label; first argument is millimeters (integer)"
        )
        return String(format: format, wheelMillimetersForUI)
    }

    init(viewModel: SensorDetailsViewModel) {
        self._viewModel = Bindable(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("SensorDetails.Field.Name", bundle: .settingsStrings, comment: "Sensor Details: name field label")
                    Spacer()
                    Text(viewModel.name)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("SensorDetails.Field.Type", bundle: .settingsStrings, comment: "Sensor Details: type field label")
                    Spacer()
                    Text(viewModel.type.localizedName)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("SensorDetails.Field.ConnectionState", bundle: .settingsStrings, comment: "Sensor Details: connection state field label")
                    Spacer()
                    Text(viewModel.statusText)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("SensorDetails.Section.Sensor", bundle: .settingsStrings, comment: "Sensor Details: first section (identity)")
            }

            Section {
                Toggle(
                    isOn: Binding(
                        get: { viewModel.isEnabled },
                        set: { newValue in
                            if newValue != viewModel.isEnabled {
                                viewModel.toggleEnabled()
                            }
                        }
                    )
                ) {
                    Text("SensorDetails.Toggle.Enabled", bundle: .settingsStrings, comment: "Toggle whether the sensor is enabled for auto-connect")
                }
                Button {
                    viewModel.connect()
                } label: {
                    Text("SensorDetails.Action.Connect", bundle: .settingsStrings, comment: "Connect to the BLE sensor")
                }
                .disabled(!viewModel.isEnabled || viewModel.connectionState == .connected || viewModel.connectionState == .connecting)

                Button {
                    viewModel.disconnect()
                } label: {
                    Text("SensorDetails.Action.Disconnect", bundle: .settingsStrings, comment: "Disconnect the BLE sensor")
                }
                .disabled(!viewModel.isEnabled || viewModel.connectionState == .disconnected)
            } header: {
                Text("SensorDetails.Section.Connection", bundle: .settingsStrings, comment: "Sensor Details: connection and enabled section")
            }

            if viewModel.wheelDiameter != nil {
                Section {
                    Stepper(
                        value: Binding(
                            get: { wheelMillimetersForUI },
                            set: { mm in
                                viewModel.setWheelDiameter(.init(value: Double(mm), unit: .millimeters))
                            }
                        ),
                        in: Self.wheelDiameterMMRange
                    ) {
                        Text(verbatim: wheelDiameterLabel)
                    }
                } header: {
                    Text("SensorDetails.Section.WheelDiameter", bundle: .settingsStrings, comment: "Sensor Details: wheel diameter (CSC) section")
                }
            }

            Section {
                Button(role: .destructive) {
                    showForgetConfirmation = true
                } label: {
                    Text("SensorDetails.Action.Forget", bundle: .settingsStrings, comment: "Forget the sensor and remove it from the list")
                }
            }
        }
        .navigationTitle(String(localized: "SensorDetails.Title", bundle: .settingsStrings, comment: "Navigation title for sensor details screen"))
        .navigationBarTitleDisplayMode(.inline)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bikerBackground.ignoresSafeArea())
        .alert(
            String(localized: "SensorDetails.Forget.Confirm.Title", bundle: .settingsStrings, comment: "Title for forget-sensor confirmation"),
            isPresented: $showForgetConfirmation
        ) {
            Button(
                String(localized: "SensorDetails.Forget.Confirm.Button", bundle: .settingsStrings, comment: "Confirm forget sensor"),
                role: .destructive
            ) {
                viewModel.forget()
            }
            Button(
                String(localized: "SensorDetails.Forget.Confirm.Cancel", bundle: .settingsStrings, comment: "Cancel forget sensor"),
                role: .cancel
            ) {}
        } message: {
            Text("SensorDetails.Forget.Confirm.Message", bundle: .settingsStrings, comment: "Body for forget-sensor confirmation")
        }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss {
                dismiss()
                viewModel.acknowledgeDismissal()
            }
        }
    }
}

#Preview("CSC with wheel") {
    NavigationStack {
        SensorDetailsView(
            viewModel: SensorDetailsViewModel(
                sensor: MockCSCSensorPreview(
                    id: UUID(),
                    name: "Bontrager DuoTrap",
                    connectionState: .connected
                ),
                dismiss: {}
            )
        )
    }
}

#Preview("Heart rate, no wheel") {
    NavigationStack {
        SensorDetailsView(
            viewModel: SensorDetailsViewModel(
                sensor: MockPlainSensor(
                    id: UUID(),
                    name: "Polar H10",
                    type: .heartRate,
                    connectionState: .disconnected
                ),
                dismiss: {}
            )
        )
    }
}
