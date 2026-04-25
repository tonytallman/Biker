//
//  SensorStackCompositionIntegrationTests.swift
//  DependencyContainerIntegrationTests
//

import Combine
import Foundation
import SettingsVM
import Testing

@testable import CyclingSpeedAndCadenceService
@testable import DependencyContainer
@testable import FitnessMachineService
@testable import HeartRateService

@MainActor
@Suite("SensorStackComposition (DependencyContainer + fakes)")
struct SensorStackCompositionIntegrationTests {
    @Test func composite_mergedDiscoveredOrderMatchesSENScan7() {
        let c = IntegrationCSCCentral()
        let f = IntegrationFTMSCentral()
        let h = IntegrationHRCentral()

        let cscM = CyclingSpeedAndCadenceSensorManager(
            persistence: InMemoryCSCIntegrationPersistence(),
            central: c
        )
        let ftmsM = FitnessMachineSensorManager(
            persistence: InMemoryFTMSIntegrationPersistence(),
            central: f
        )
        let hrM = HeartRateSensorManager(
            persistence: InMemoryHRIntegrationPersistence(),
            central: h
        )
        c.onAuthorizationOrStateChange = { [weak cscM] in cscM?.handleBluetoothStateChange() }
        f.onAuthorizationOrStateChange = { [weak ftmsM] in ftmsM?.handleBluetoothStateChange() }
        h.onAuthorizationOrStateChange = { [weak hrM] in hrM?.handleBluetoothStateChange() }
        cscM.handleBluetoothStateChange()
        ftmsM.handleBluetoothStateChange()
        hrM.handleBluetoothStateChange()

        let uC = UUID()
        let uF = UUID()
        let uH = UUID()
        cscM._test_publishDiscovered([CyclingSpeedAndCadenceService.DiscoveredSensor(id: uC, name: "CscWeak", rssi: -80)])
        ftmsM._test_publishDiscovered([FitnessMachineService.DiscoveredSensor(id: uF, name: "FtmsStrong", rssi: -20)])
        hrM._test_publishDiscovered([HeartRateService.DiscoveredSensor(id: uH, name: "HrMid", rssi: -50)])

        let tmpSuite = "dc.compose.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: tmpSuite)!
        defer { UserDefaults().removePersistentDomain(forName: tmpSuite) }
        let deps = SettingsDependencies(
            appStorage: defaults.asAppStorage(),
            csc: cscM,
            ftms: ftmsM,
            hr: hrM
        )
        let composite = deps.integrationComposite
        var last: [UUID] = []
        let sub = composite.discoveredSensors.sink { s in
            last = s.map(\.id)
        }
        #expect(last == [uF, uH, uC])
        _ = sub
    }

    @Test func composite_scanAndStopScan_fanOutsToAllCentrals() {
        let c = IntegrationCSCCentral()
        let f = IntegrationFTMSCentral()
        let h = IntegrationHRCentral()
        let cscM = CyclingSpeedAndCadenceSensorManager(
            persistence: InMemoryCSCIntegrationPersistence(),
            central: c
        )
        let ftmsM = FitnessMachineSensorManager(
            persistence: InMemoryFTMSIntegrationPersistence(),
            central: f
        )
        let hrM = HeartRateSensorManager(
            persistence: InMemoryHRIntegrationPersistence(),
            central: h
        )
        c.onAuthorizationOrStateChange = { [weak cscM] in cscM?.handleBluetoothStateChange() }
        f.onAuthorizationOrStateChange = { [weak ftmsM] in ftmsM?.handleBluetoothStateChange() }
        h.onAuthorizationOrStateChange = { [weak hrM] in hrM?.handleBluetoothStateChange() }
        cscM.handleBluetoothStateChange()
        ftmsM.handleBluetoothStateChange()
        hrM.handleBluetoothStateChange()
        let tmpSuite = "dc.scan.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: tmpSuite)!
        defer { UserDefaults().removePersistentDomain(forName: tmpSuite) }
        let deps = SettingsDependencies(
            appStorage: defaults.asAppStorage(),
            csc: cscM,
            ftms: ftmsM,
            hr: hrM
        )
        deps.integrationComposite.scan()
        deps.integrationComposite.stopScan()
        #expect(c.scanForPeripheralsCallCount == 1)
        #expect(f.scanForPeripheralsCallCount == 1)
        #expect(h.scanForPeripheralsCallCount == 1)
        #expect(c.stopScanCallCount == 1)
        #expect(f.stopScanCallCount == 1)
        #expect(h.stopScanCallCount == 1)
    }

    @Test func combinedAvailability_deniedBeatsPoweredOn() async {
        let c = IntegrationCSCCentral(state: .poweredOn, authorization: .allowedAlways)
        let f = IntegrationFTMSCentral(state: .poweredOn, authorization: .notDetermined)
        let h = IntegrationHRCentral(state: .poweredOn, authorization: .allowedAlways)
        let cscM = CyclingSpeedAndCadenceSensorManager(
            persistence: InMemoryCSCIntegrationPersistence(),
            central: c
        )
        let ftmsM = FitnessMachineSensorManager(
            persistence: InMemoryFTMSIntegrationPersistence(),
            central: f
        )
        let hrM = HeartRateSensorManager(
            persistence: InMemoryHRIntegrationPersistence(),
            central: h
        )
        c.onAuthorizationOrStateChange = { [weak cscM] in cscM?.handleBluetoothStateChange() }
        f.onAuthorizationOrStateChange = { [weak ftmsM] in ftmsM?.handleBluetoothStateChange() }
        h.onAuthorizationOrStateChange = { [weak hrM] in hrM?.handleBluetoothStateChange() }
        cscM.handleBluetoothStateChange()
        ftmsM.handleBluetoothStateChange()
        hrM.handleBluetoothStateChange()
        f.simulate(authorization: .denied, state: .poweredOn)
        let tmpSuite = "dc.avail.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: tmpSuite)!
        defer { UserDefaults().removePersistentDomain(forName: tmpSuite) }
        let deps = SettingsDependencies(
            appStorage: defaults.asAppStorage(),
            csc: cscM,
            ftms: ftmsM,
            hr: hrM
        )
        let first = await integrationFirstSensorAvailability(deps.integrationComposite.availability)
        if case SensorAvailability.denied = first {
        } else {
            Issue.record("expected denied from most-restrictive merge")
        }
    }

    @Test func ftms_reconnectsDisconnectedKnownOnPowerOn() {
        let id = UUID()
        let p = InMemoryFTMSIntegrationPersistence()
        let fake = IntegrationFTMSCentral(state: .poweredOff, authorization: .allowedAlways)
        let m = FitnessMachineSensorManager(persistence: p, central: fake)
        fake.onAuthorizationOrStateChange = { [weak m] in
            m?.handleBluetoothStateChange()
        }
        m.handleBluetoothStateChange()
        m._test_registerSensor(
            makeFTMSSensor(id: id, name: "T", connected: false)
        )
        fake.peripheralsById[id] = IntegrationFTMSPeripheral(identifier: id, name: "T")
        m.reconnectDisconnectedKnownSensorsIfPoweredOn()
        #expect(fake.connectCallCount == 0)
        fake.simulate(authorization: .allowedAlways, state: .poweredOn)
        m.reconnectDisconnectedKnownSensorsIfPoweredOn()
        #expect(fake.connectCallCount == 1)
    }

    @Test func ftms_reconnectSkipsWhenKnownDisabled() {
        let p = InMemoryFTMSIntegrationPersistence()
        let id = UUID()
        FTMSKnownSensorStore(persistence: p).upsert(FTMSKnownSensorRecord(
            id: id,
            name: "D",
            isEnabled: false
        ))
        let fake = IntegrationFTMSCentral()
        let m = FitnessMachineSensorManager(persistence: p, central: fake)
        fake.onAuthorizationOrStateChange = { [weak m] in m?.handleBluetoothStateChange() }
        m.handleBluetoothStateChange()
        #expect(m.ftmsSensor(for: id)?.isEnabledValue == false)
        fake.peripheralsById[id] = IntegrationFTMSPeripheral(identifier: id, name: "D")
        m.reconnectDisconnectedKnownSensorsIfPoweredOn()
        #expect(fake.connectCallCount == 0)
    }

    @Test func settingsPersistence_roundTripCSCWheel_durableAcrossRecomposition() {
        let suite = "dc.it.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        defer { UserDefaults().removePersistentDomain(forName: suite) }

        let id = UUID()
        let deps1 = SettingsDependencies(appStorage: d.asAppStorage())
        let s = CyclingSpeedAndCadenceSensor(
            id: id,
            name: "Wheel",
            initialConnectionState: .disconnected
        )
        deps1.bluetoothSensorManager._test_registerSensor(s)
        deps1.bluetoothSensorManager.setWheelDiameter(
            peripheralID: id,
            Measurement(value: 0.71, unit: .meters)
        )
        let deps2 = SettingsDependencies(appStorage: d.asAppStorage())
        let csc = deps2.bluetoothSensorManager.cscSensor(for: id)
        #expect(csc != nil)
        if let csc {
            let m = csc.currentWheelDiameter.converted(to: .meters).value
            #expect(abs(m - 0.71) < 0.01)
        }
    }

    @Test func legacyKnownSensors_migratesToCscStoreInLiveComposition() {
        let suite = "dc.leg.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        defer { UserDefaults().removePersistentDomain(forName: suite) }

        let id = UUID()
        let legacy: [[String: String]] = [
            ["id": id.uuidString, "name": "FromLegacy"],
        ]
        d.set(try! JSONSerialization.data(withJSONObject: legacy, options: []), forKey: "Settings.knownSensors")

        let deps = SettingsDependencies(appStorage: d.asAppStorage())
        #expect(d.data(forKey: "Settings.knownSensors") == nil)
        #expect(d.data(forKey: "Settings.CSC.knownSensors.v1") != nil)
        var names: [String] = []
        let sub = deps.bluetoothSensorManager.knownSensors.sink { k in
            names = k.map(\.name)
        }
        #expect(names.contains("FromLegacy"))
        _ = sub
    }

    private func makeFTMSSensor(id: UUID, name: String, connected: Bool) -> FitnessMachineSensor {
        FitnessMachineSensor(
            id: id,
            name: name,
            initialConnectionState: connected ? .connected : .disconnected
        )
    }
}
