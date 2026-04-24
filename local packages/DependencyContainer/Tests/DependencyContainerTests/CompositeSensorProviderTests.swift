//
//  CompositeSensorProviderTests.swift
//  DependencyContainerTests
//

import Combine
import Foundation
import SettingsVM
import Testing
@testable import DependencyContainer

@MainActor
@Suite("CompositeSensorProvider")
struct CompositeSensorProviderTests {
    private func makeComposite(
        sensorProviders: [any SensorProvider],
        systemAvailability: AnyPublisher<BluetoothAvailability, Never>,
    ) -> CompositeSensorProvider {
        CompositeSensorProvider(sensorProviders: sensorProviders, systemAvailability: systemAvailability)
    }

    private func makeCompositePoweredOn(
        sensorProviders: [any SensorProvider]
    ) -> (CompositeSensorProvider, CurrentValueSubject<BluetoothAvailability, Never>) {
        let subj = CurrentValueSubject<BluetoothAvailability, Never>(.poweredOn)
        let c = makeComposite(
            sensorProviders: sensorProviders,
            systemAvailability: subj.removeDuplicates().eraseToAnyPublisher()
        )
        return (c, subj)
    }

    @Test
    func knownMergesMultipleSensorProvidersByLocalizedCaseInsensitiveName() {
        let p1 = FakeSensorProvider()
        let p2 = FakeSensorProvider()
        let u1 = UUID()
        let u2 = UUID()
        let z = MockPlainSensor(
            id: u1,
            name: "Zebra",
            type: .cyclingSpeedAndCadence
        )
        let a = MockPlainSensor(
            id: u2,
            name: "alpha",
            type: .heartRate
        )
        let (composite, _) = makeCompositePoweredOn(sensorProviders: [p1, p2])
        var last: [String] = []
        let sub = composite.knownSensors.sink { sensors in
            last = sensors.map(\.name)
        }
        p1.setKnown([z])
        p2.setKnown([a])
        #expect(last == ["alpha", "Zebra"])
        _ = sub
    }

    @Test
    func discoveredConnectedBeforeStrongerRSSI() {
        let p1 = FakeSensorProvider()
        let u1 = UUID()
        let u2 = UUID()
        let z = MockSensorWithRSSI(
            id: u1,
            name: "Z",
            type: .cyclingSpeedAndCadence,
            rssi: -100,
            connectionState: .connected
        )
        let a = MockSensorWithRSSI(
            id: u2,
            name: "A",
            type: .cyclingSpeedAndCadence,
            rssi: -30,
            connectionState: .disconnected
        )
        let (composite, _) = makeCompositePoweredOn(sensorProviders: [p1])
        var lastOrder: [UUID] = []
        let sub = composite.discoveredSensors.sink { sensors in
            lastOrder = sensors.map(\.id)
        }
        p1.setDiscovered([z, a])
        #expect(lastOrder == [u1, u2])
        _ = sub
    }

    @Test
    func discoveredRSSIDescendingWhenBothDisconnected() {
        let p1 = FakeSensorProvider()
        let u1 = UUID()
        let u2 = UUID()
        let sWeak = MockSensorWithRSSI(
            id: u1,
            name: "A",
            type: .cyclingSpeedAndCadence,
            rssi: -60
        )
        let sStrong = MockSensorWithRSSI(
            id: u2,
            name: "B",
            type: .cyclingSpeedAndCadence,
            rssi: -50
        )
        let (composite, _) = makeCompositePoweredOn(sensorProviders: [p1])
        var lastOrder: [UUID] = []
        let sub = composite.discoveredSensors.sink { sensors in
            lastOrder = sensors.map(\.id)
        }
        p1.setDiscovered([sWeak, sStrong])
        #expect(lastOrder == [u2, u1])
        _ = sub
    }

    @Test
    func rssiChangeCanReorderDiscovered() {
        let p1 = FakeSensorProvider()
        let u1 = UUID()
        let u2 = UUID()
        let s1 = MockSensorWithRSSI(
            id: u1,
            name: "A",
            type: .cyclingSpeedAndCadence,
            rssi: -50
        )
        let s2 = MockSensorWithRSSI(
            id: u2,
            name: "B",
            type: .cyclingSpeedAndCadence,
            rssi: -60
        )
        let (composite, _) = makeCompositePoweredOn(sensorProviders: [p1])
        var orders: [[UUID]] = []
        let sub = composite.discoveredSensors.sink { sensors in
            orders.append(sensors.map(\.id))
        }
        p1.setDiscovered([s1, s2])
        #expect(orders.last == [u1, u2])
        s2.rssiValue = -40
        #expect(orders.last == [u2, u1])
        _ = sub
    }

    @Test
    func discoveredDoesNotReemitWhenOrderUnchanged() {
        let p1 = FakeSensorProvider()
        let s1 = MockSensorWithRSSI(
            id: UUID(),
            name: "A",
            type: .cyclingSpeedAndCadence,
            rssi: -50
        )
        let s2 = MockSensorWithRSSI(
            id: UUID(),
            name: "B",
            type: .cyclingSpeedAndCadence,
            rssi: -60
        )
        let (composite, _) = makeCompositePoweredOn(sensorProviders: [p1])
        var count = 0
        let sub = composite.discoveredSensors.sink { _ in
            count += 1
        }
        p1.setDiscovered([s1, s2])
        p1.setDiscovered([s1, s2])
        // `CurrentValueSubject` first emits `[]` on subscribe, then the merged list once; duplicate set must not re-emit.
        #expect(count == 2)
        _ = sub
    }

    @Test
    func scanAndStopScanFanOut() {
        let p1 = FakeSensorProvider()
        let p2 = FakeSensorProvider()
        let (c, _) = makeCompositePoweredOn(sensorProviders: [p1, p2])
        c.scan()
        c.stopScan()
        #expect(p1.scanCallCount == 1)
        #expect(p2.scanCallCount == 1)
        #expect(p1.stopScanCallCount == 1)
        #expect(p2.stopScanCallCount == 1)
    }

    @Test
    func availabilityWrapsSelfWhenSystemPoweredOn() {
        let p1 = FakeSensorProvider()
        let (composite, sys) = makeCompositePoweredOn(sensorProviders: [p1])
        var last: SensorAvailability = .notDetermined
        let sub = composite.availability.sink { last = $0 }
        if case .available = last {
        } else {
            #expect(false, "Expected .available when system radio is .poweredOn")
        }
        sys.send(.poweredOn)
        _ = sub
    }

    @Test
    func availabilityMapsSystemStatesWhenNotPoweredOn() {
        let p1 = FakeSensorProvider()
        let sys = CurrentValueSubject<BluetoothAvailability, Never>(.denied)
        let composite = makeComposite(
            sensorProviders: [p1],
            systemAvailability: sys.eraseToAnyPublisher()
        )
        var last: SensorAvailability = .notDetermined
        let sub = composite.availability.sink { last = $0 }
        #expect(last == .denied)
        sys.send(.poweredOff)
        #expect(last == .poweredOff)
        _ = sub
    }

    @Test
    func availabilityDoesNotReemitDuplicateCase() {
        let p1 = FakeSensorProvider()
        let sys = CurrentValueSubject<BluetoothAvailability, Never>(.denied)
        let composite = makeComposite(
            sensorProviders: [p1],
            systemAvailability: sys
                .removeDuplicates()
                .eraseToAnyPublisher()
        )
        var count = 0
        let sub = composite.availability.sink { _ in count += 1 }
        sys.send(.denied)
        #expect(count == 1)
        _ = sub
    }
}
