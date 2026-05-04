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
    func knownMergesCSCAndFTMSProvidersByName() {
        let p1 = FakeSensorProvider()
        let p2 = FakeSensorProvider()
        let u1 = UUID()
        let u2 = UUID()
        let csc = MockPlainSensor(
            id: u1,
            name: "Zebra",
            type: .cyclingSpeedAndCadence
        )
        let ftms = MockPlainSensor(
            id: u2,
            name: "alpha",
            type: .fitnessMachine
        )
        let (composite, _) = makeCompositePoweredOn(sensorProviders: [p1, p2])
        var last: [SensorType] = []
        let sub = composite.knownSensors.sink { sensors in
            last = sensors.map(\.type)
        }
        p1.setKnown([csc])
        p2.setKnown([ftms])
        #expect(last == [.fitnessMachine, .cyclingSpeedAndCadence])
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
    func scanAndStopScanFanOut_threeProviders() {
        let p1 = FakeSensorProvider()
        let p2 = FakeSensorProvider()
        let p3 = FakeSensorProvider()
        let (c, _) = makeCompositePoweredOn(sensorProviders: [p1, p2, p3])
        c.scan()
        c.stopScan()
        #expect(p1.scanCallCount == 1)
        #expect(p2.scanCallCount == 1)
        #expect(p3.scanCallCount == 1)
        #expect(p1.stopScanCallCount == 1)
        #expect(p2.stopScanCallCount == 1)
        #expect(p3.stopScanCallCount == 1)
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

    // MARK: - ADR-0012: same peripheral UUID from multiple providers

    @Test
    func knownDedup_sameUUID_prefersFTMSOverCSC() {
        let p1 = FakeSensorProvider()
        let p2 = FakeSensorProvider()
        let u = UUID()
        let csc = MockPlainSensor(id: u, name: "Bike", type: .cyclingSpeedAndCadence)
        let ftms = MockPlainSensor(id: u, name: "Bike", type: .fitnessMachine)
        let (composite, _) = makeCompositePoweredOn(sensorProviders: [p1, p2])
        var last: [SensorType] = []
        let sub = composite.knownSensors.sink { sensors in
            last = sensors.map(\.type)
        }
        p1.setKnown([csc])
        p2.setKnown([ftms])
        #expect(last == [.fitnessMachine])
        _ = sub
    }

    @Test
    func knownDedup_sameUUID_prefersCSCOverHR() {
        let p1 = FakeSensorProvider()
        let p2 = FakeSensorProvider()
        let u = UUID()
        let csc = MockPlainSensor(id: u, name: "X", type: .cyclingSpeedAndCadence)
        let hr = MockPlainSensor(id: u, name: "X", type: .heartRate)
        let (composite, _) = makeCompositePoweredOn(sensorProviders: [p1, p2])
        var last: [SensorType] = []
        let sub = composite.knownSensors.sink { sensors in
            last = sensors.map(\.type)
        }
        p1.setKnown([csc])
        p2.setKnown([hr])
        #expect(last == [.cyclingSpeedAndCadence])
        _ = sub
    }

    @Test
    func discoveredDedup_sameUUID_prefersFTMSAmongThreeProviders() {
        let p1 = FakeSensorProvider()
        let p2 = FakeSensorProvider()
        let p3 = FakeSensorProvider()
        let u = UUID()
        let csc = MockPlainSensor(id: u, name: "T", type: .cyclingSpeedAndCadence)
        let ftms = MockPlainSensor(id: u, name: "T", type: .fitnessMachine)
        let hr = MockPlainSensor(id: u, name: "T", type: .heartRate)
        let (composite, _) = makeCompositePoweredOn(sensorProviders: [p1, p2, p3])
        var last: [any Sensor] = []
        let sub = composite.discoveredSensors.sink { sensors in
            last = sensors
        }
        p1.setDiscovered([csc])
        p2.setDiscovered([ftms])
        p3.setDiscovered([hr])
        #expect(last.count == 1)
        #expect(last.first?.type == .fitnessMachine)
        #expect(last.first?.id == u)
        _ = sub
    }
}
