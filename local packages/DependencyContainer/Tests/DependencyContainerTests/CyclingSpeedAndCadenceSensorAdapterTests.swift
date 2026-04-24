//
//  CyclingSpeedAndCadenceSensorAdapterTests.swift
//  DependencyContainerTests
//

@preconcurrency import CoreBluetooth
import Combine
import Foundation
import SettingsVM
import Testing
@testable import CyclingSpeedAndCadenceService
@testable import DependencyContainer

@MainActor
@Suite("CyclingSpeedAndCadenceSensorAdapter")
struct CyclingSpeedAndCadenceSensorAdapterTests {
    @Test
    func updateForwardsConnectionStateFromConnectedSnapshot() {
        let central = TestFakeCSCCentral()
        let persistence = InMemoryCSCPersistence()
        let manager = CyclingSpeedAndCadenceSensorManager(
            persistence: persistence,
            central: central
        )
        let id = UUID()
        let csc = CyclingSpeedAndCadenceSensor(
            id: id,
            name: "Unit",
            initialConnectionState: .disconnected
        )
        manager._test_registerSensor(csc)
        let adapter = CyclingSpeedAndCadenceSensorAdapter(manager: manager, id: id)
        var latest: [SensorConnectionState] = []
        let sub = adapter.connectionState.sink { latest.append($0) }
        adapter.update(
            from: ConnectedSensor(
                id: id,
                name: "Unit",
                connectionState: .connecting
            )
        )
        #expect(latest.last == .connecting)
        _ = sub
    }

    @Test
    func setWheelDiameterForwardsToSensor() {
        let central = TestFakeCSCCentral()
        let persistence = InMemoryCSCPersistence()
        let manager = CyclingSpeedAndCadenceSensorManager(
            persistence: persistence,
            central: central
        )
        let id = UUID()
        let csc = CyclingSpeedAndCadenceSensor(
            id: id,
            name: "W",
            initialConnectionState: .disconnected
        )
        manager._test_registerSensor(csc)
        let adapter = CyclingSpeedAndCadenceSensorAdapter(manager: manager, id: id)
        var last: Measurement<UnitLength>?
        let sub = adapter.wheelDiameter.sink { last = $0 }
        let m = Measurement(value: 0.7, unit: UnitLength.meters)
        adapter.setWheelDiameter(m)
        #expect(last == m)
        _ = sub
    }

    @Test
    func connectForwardsToManagerWithRetrievedPeripheral() {
        let central = TestFakeCSCCentral()
        let id = UUID()
        let p = TestFakeCSCPeripheral(identifier: id, name: "P")
        central.peripheralsById[id] = p
        let persistence = InMemoryCSCPersistence()
        let manager = CyclingSpeedAndCadenceSensorManager(
            persistence: persistence,
            central: central
        )
        let csc = CyclingSpeedAndCadenceSensor(
            id: id,
            name: "P",
            initialConnectionState: .disconnected
        )
        manager._test_registerSensor(csc)
        let adapter = CyclingSpeedAndCadenceSensorAdapter(manager: manager, id: id)
        adapter.connect()
        #expect(central.connectCallCount == 1)
    }

    @Test
    func cscSensorProvider_reusesAdapterInstanceWhenKnownListRepublishes() {
        let central = TestFakeCSCCentral()
        let persistence = InMemoryCSCPersistence()
        let manager = CyclingSpeedAndCadenceSensorManager(
            persistence: persistence,
            central: central
        )
        let id = UUID()
        let csc = CyclingSpeedAndCadenceSensor(
            id: id,
            name: "A",
            initialConnectionState: .disconnected
        )
        let sensorProvider = CSCSensorProvider(manager: manager)
        var refs: [ObjectIdentifier] = []
        let sub = sensorProvider.knownSensors.sink { list in
            if let f = list.first {
                refs.append(ObjectIdentifier(f as AnyObject))
            }
        }
        manager._test_registerSensor(csc)
        csc.updateName("Renamed")
        manager._test_registerSensor(csc)
        #expect(refs.count == 2)
        #expect(refs[0] == refs[1])
        _ = sub
    }
}
