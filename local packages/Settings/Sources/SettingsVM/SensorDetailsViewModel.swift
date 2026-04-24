//
//  SensorDetailsViewModel.swift
//  SettingsVM
//

import Combine
import Foundation
import Observation

/// Drives the Sensor Details screen (SEN-DET-1..6, SEN-KNOWN-1..5/7) with optional ``WheelDiameterAdjustable`` support (ADR-0002).
@MainActor
@Observable
public final class SensorDetailsViewModel {
    public let sensorID: UUID
    public let name: String
    public let type: SensorType
    public private(set) var connectionState: SensorConnectionState
    public private(set) var isEnabled: Bool
    /// Non-nil if the sensor supports ``WheelDiameterAdjustable`` (CSC, etc.).
    public private(set) var wheelDiameter: Measurement<UnitLength>?
    /// Set after ``forget()`` so the view can pop (SEN-DET-4) without racing the known-sensor list.
    public private(set) var shouldDismiss: Bool = false

    private let sensor: any Sensor
    /// Set only for sensors that support wheel-diameter; holds the same object as ``Sensor``.
    private var wheelCapable: (any WheelDiameterAdjustable)?
    private let dismiss: () -> Void
    private var cancellables = Set<AnyCancellable>()

    public init(
        sensor: any Sensor,
        dismiss: @escaping () -> Void
    ) {
        self.sensor = sensor
        self.sensorID = sensor.id
        self.name = sensor.name
        self.type = sensor.type
        self.connectionState = .disconnected
        self.isEnabled = true
        self.dismiss = dismiss
        if let wheel = sensor as? any WheelDiameterAdjustable {
            self.wheelCapable = wheel
            wheel.wheelDiameter
                .sink { [weak self] in self?.wheelDiameter = $0 }
                .store(in: &cancellables)
        } else {
            self.wheelDiameter = nil
        }
        sensor.connectionState
            .sink { [weak self] in self?.connectionState = $0 }
            .store(in: &cancellables)
        sensor.isEnabled
            .sink { [weak self] in self?.isEnabled = $0 }
            .store(in: &cancellables)
    }

    public func toggleEnabled() {
        sensor.setEnabled(!isEnabled)
    }

    public func connect() {
        sensor.connect()
    }

    public func disconnect() {
        sensor.disconnect()
    }

    public func forget() {
        sensor.forget()
        shouldDismiss = true
        dismiss()
    }

    public func setWheelDiameter(_ diameter: Measurement<UnitLength>) {
        wheelCapable?.setWheelDiameter(diameter)
    }

    public func acknowledgeDismissal() {
        shouldDismiss = false
    }
}
