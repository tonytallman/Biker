//
//  MockSensor.swift
//  SettingsVM
//

import Combine
import Foundation

// MARK: - Base mock (Sensor only)

@MainActor
open class MockPlainSensor: Sensor {
    public let id: UUID
    public var name: String
    public let type: SensorType

    private let connectionStateSubject: CurrentValueSubject<SensorConnectionState, Never>
    private let isEnabledSubject: CurrentValueSubject<Bool, Never>

    public var connectionState: AnyPublisher<SensorConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    public var isEnabled: AnyPublisher<Bool, Never> {
        isEnabledSubject.eraseToAnyPublisher()
    }

    public var connectionStateValue: SensorConnectionState {
        get { connectionStateSubject.value }
        set { connectionStateSubject.send(newValue) }
    }

    public var isEnabledValue: Bool {
        get { isEnabledSubject.value }
        set { isEnabledSubject.send(newValue) }
    }

    public private(set) var connectCallCount = 0
    public private(set) var disconnectCallCount = 0
    public private(set) var forgetCallCount = 0
    public private(set) var setEnabledCallCount = 0
    public private(set) var lastSetEnabledValue: Bool?

    public init(
        id: UUID,
        name: String,
        type: SensorType,
        connectionState: SensorConnectionState = .disconnected,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.connectionStateSubject = CurrentValueSubject(connectionState)
        self.isEnabledSubject = CurrentValueSubject(isEnabled)
    }

    public func connect() {
        connectCallCount += 1
    }

    public func disconnect() {
        disconnectCallCount += 1
    }

    public func forget() {
        forgetCallCount += 1
    }

    public func setEnabled(_ enabled: Bool) {
        setEnabledCallCount += 1
        lastSetEnabledValue = enabled
        isEnabledSubject.send(enabled)
    }
}

// MARK: - RSSI (scan / discovered rows)

@MainActor
public final class MockSensorWithRSSI: MockPlainSensor, SignalStrengthReporting {
    private let rssiSubject: CurrentValueSubject<Int, Never>

    public var rssi: AnyPublisher<Int, Never> {
        rssiSubject.eraseToAnyPublisher()
    }

    public var rssiValue: Int {
        get { rssiSubject.value }
        set { rssiSubject.send(newValue) }
    }

    public init(
        id: UUID,
        name: String,
        type: SensorType,
        rssi: Int,
        connectionState: SensorConnectionState = .disconnected,
        isEnabled: Bool = true
    ) {
        self.rssiSubject = CurrentValueSubject(rssi)
        super.init(id: id, name: name, type: type, connectionState: connectionState, isEnabled: isEnabled)
    }
}

// MARK: - Wheel (known CSC-style rows)

@MainActor
public final class MockSensorWithWheel: MockPlainSensor, WheelDiameterAdjustable {
    private let wheelDiameterSubject: CurrentValueSubject<Measurement<UnitLength>, Never>

    public var wheelDiameter: AnyPublisher<Measurement<UnitLength>, Never> {
        wheelDiameterSubject.eraseToAnyPublisher()
    }

    public var wheelDiameterValue: Measurement<UnitLength> {
        get { wheelDiameterSubject.value }
        set { wheelDiameterSubject.send(newValue) }
    }

    public private(set) var setWheelDiameterCallCount = 0
    public private(set) var lastSetWheelDiameter: Measurement<UnitLength>?

    public init(
        id: UUID,
        name: String,
        type: SensorType = .cyclingSpeedAndCadence,
        connectionState: SensorConnectionState = .disconnected,
        isEnabled: Bool = true,
        wheelDiameter: Measurement<UnitLength> = .init(value: 700, unit: .millimeters)
    ) {
        self.wheelDiameterSubject = CurrentValueSubject(wheelDiameter)
        super.init(id: id, name: name, type: type, connectionState: connectionState, isEnabled: isEnabled)
    }

    public func setWheelDiameter(_ diameter: Measurement<UnitLength>) {
        setWheelDiameterCallCount += 1
        lastSetWheelDiameter = diameter
        wheelDiameterSubject.send(diameter)
    }
}

// MARK: - Full CSC-style mock (preview)

@MainActor
public final class MockCSCSensorPreview: MockPlainSensor, WheelDiameterAdjustable, SignalStrengthReporting {
    private let wheelDiameterSubject: CurrentValueSubject<Measurement<UnitLength>, Never>
    private let rssiSubject: CurrentValueSubject<Int, Never>

    public var wheelDiameter: AnyPublisher<Measurement<UnitLength>, Never> {
        wheelDiameterSubject.eraseToAnyPublisher()
    }

    public var rssi: AnyPublisher<Int, Never> {
        rssiSubject.eraseToAnyPublisher()
    }

    public init(
        id: UUID,
        name: String,
        rssi: Int = -55,
        connectionState: SensorConnectionState,
        isEnabled: Bool = true,
        wheelDiameter: Measurement<UnitLength> = .init(value: 700, unit: .millimeters)
    ) {
        self.wheelDiameterSubject = CurrentValueSubject(wheelDiameter)
        self.rssiSubject = CurrentValueSubject(rssi)
        super.init(
            id: id,
            name: name,
            type: .cyclingSpeedAndCadence,
            connectionState: connectionState,
            isEnabled: isEnabled
        )
    }

    public func setWheelDiameter(_ diameter: Measurement<UnitLength>) {
        wheelDiameterSubject.send(diameter)
    }
}
