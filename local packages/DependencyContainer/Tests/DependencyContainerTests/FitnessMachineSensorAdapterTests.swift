//
//  FitnessMachineSensorAdapterTests.swift
//  DependencyContainerTests
//

import Combine
import Foundation
import SettingsVM
import Testing

@testable import DependencyContainer
@testable import FitnessMachineService

@MainActor
@Suite("FitnessMachineSensorAdapter")
struct FitnessMachineSensorAdapterTests {
    @Test
    func updateForwardsConnectionStateFromConnectedSnapshot() {
        let central = TestFakeFTMSCentral()
        let persistence = InMemoryFTMSPersistence()
        let manager = FitnessMachineSensorManager(
            persistence: persistence,
            central: central
        )
        let id = UUID()
        let sensor = FitnessMachineSensor(
            id: id,
            name: "Unit",
            initialConnectionState: .disconnected
        )
        manager._test_registerSensor(sensor)
        let adapter = FitnessMachineSensorAdapter(manager: manager, id: id)
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
    func connectForwardsToManagerWithRetrievedPeripheral() {
        let central = TestFakeFTMSCentral()
        let id = UUID()
        let p = TestFakeFTMSPeripheral(identifier: id, name: "P")
        central.peripheralsById[id] = p
        let persistence = InMemoryFTMSPersistence()
        let manager = FitnessMachineSensorManager(
            persistence: persistence,
            central: central
        )
        let sensor = FitnessMachineSensor(
            id: id,
            name: "P",
            initialConnectionState: .disconnected
        )
        manager._test_registerSensor(sensor)
        let adapter = FitnessMachineSensorAdapter(manager: manager, id: id)
        adapter.connect()
        #expect(central.connectCallCount == 1)
    }

    @Test
    func ftmsSensorProvider_reusesAdapterInstanceWhenKnownListRepublishes() {
        let central = TestFakeFTMSCentral()
        let persistence = InMemoryFTMSPersistence()
        let manager = FitnessMachineSensorManager(
            persistence: persistence,
            central: central
        )
        let id = UUID()
        let sensor = FitnessMachineSensor(
            id: id,
            name: "A",
            initialConnectionState: .disconnected
        )
        let sensorProvider = FTMSSensorProvider(manager: manager)
        var refs: [ObjectIdentifier] = []
        let sub = sensorProvider.knownSensors.sink { list in
            if let f = list.first {
                refs.append(ObjectIdentifier(f as AnyObject))
            }
        }
        manager._test_registerSensor(sensor)
        sensor.updateName("Renamed")
        manager._test_registerSensor(sensor)
        #expect(refs.count == 2)
        #expect(refs[0] == refs[1])
        _ = sub
    }
}
