//
//  SensorTests.swift
//  SensorsTests
//

import AsyncCoreBluetooth
import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import Foundation
import Sensors
import Testing

private final class CompletionHolder: @unchecked Sendable {
    var error: Error?
}

/// Holds async-stream results without racing Swift 6 `Task`/`#expect` concurrency checks.
private final class StreamFirstValueBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Data?

    func store(_ value: Data) {
        lock.lock()
        storage = value
        lock.unlock()
    }

    func load() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private final class DataBucket: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Data] = []

    func append(_ value: Data) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }

    var last: Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage.last
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage.isEmpty
    }
}

@Suite(.serialized)
struct SensorTests {

    struct Harness {
        let central: CentralManager
        let peripheral: Peripheral
        let sensor: Sensor
        let spec: CBMPeripheralSpec
        let delegate: HeartRatePeripheralDelegate
    }

    func makeHarness(delegate: HeartRatePeripheralDelegate = HeartRatePeripheralDelegate()) async throws -> Harness {
        CBMCentralManagerMock.simulateInitialState(.poweredOff)
        let spec = MockBLEPeripheral.makeSpec(delegate: delegate)
        CBMCentralManagerMock.simulatePeripherals([spec])
        CBMCentralManagerMock.simulateInitialState(.poweredOn)

        let central = CentralManager(forceMock: true)
        for await state in await central.start() where state == .poweredOn {
            break
        }

        let peripherals = await central.retrievePeripherals(withIdentifiers: [spec.identifier])
        guard let peripheral = peripherals.first else {
            Issue.record("retrievePeripherals returned empty")
            throw HarnessError.missingPeripheral
        }

        for await state in await central.connect(peripheral) where state == .connected {
            break
        }

        let sensor = try await Sensor(peripheral: peripheral)
        return Harness(central: central, peripheral: peripheral, sensor: sensor, spec: spec, delegate: delegate)
    }

    /// Same BLE harness without constructing ``Sensor`` — used to verify notify simulation independent of `Sensor`.
    func makeConnectedPeripheralHarness(
        delegate: HeartRatePeripheralDelegate = HeartRatePeripheralDelegate()
    ) async throws -> (central: CentralManager, peripheral: Peripheral, spec: CBMPeripheralSpec, delegate: HeartRatePeripheralDelegate) {
        CBMCentralManagerMock.simulateInitialState(.poweredOff)
        let spec = MockBLEPeripheral.makeSpec(delegate: delegate)
        CBMCentralManagerMock.simulatePeripherals([spec])
        CBMCentralManagerMock.simulateInitialState(.poweredOn)

        let central = CentralManager(forceMock: true)
        for await state in await central.start() where state == .poweredOn {
            break
        }

        let peripherals = await central.retrievePeripherals(withIdentifiers: [spec.identifier])
        guard let peripheral = peripherals.first else {
            Issue.record("retrievePeripherals returned empty")
            throw HarnessError.missingPeripheral
        }

        for await state in await central.connect(peripheral) where state == .connected {
            break
        }

        return (central, peripheral, spec, delegate)
    }

    @Test func baseline_simulatedNotify_deliversOnCharacteristicStream_withoutSensor() async throws {
        let h = try await makeConnectedPeripheralHarness()
        let peripheral = h.peripheral

        let services = try await peripheral.discoverServices([MockBLEPeripheral.serviceUUID])
        guard let service = services[MockBLEPeripheral.serviceUUID] else {
            Issue.record("missing HR service")
            return
        }

        let characteristics = try await peripheral.discoverCharacteristics(
            [MockBLEPeripheral.measurementUUID],
            for: service
        )
        guard let characteristic = characteristics[MockBLEPeripheral.measurementUUID] else {
            Issue.record("missing measurement characteristic")
            return
        }

        _ = try await peripheral.setNotifyValue(true, for: characteristic)

        let payload = Data([0xCA, 0xFE])
        let box = StreamFirstValueBox()
        let waiter = Task {
            for await value in await characteristic.value.stream {
                box.store(value)
                break
            }
        }

        try await Task.sleep(nanoseconds: 50_000_000)
        h.spec.simulateValueUpdate(payload, for: MockBLEPeripheral.measurementCharacteristic)
        try await Task.sleep(nanoseconds: 200_000_000)

        waiter.cancel()

        #expect(box.load() == payload)
    }

    enum HarnessError: Error {
        case missingPeripheral
    }

    func sleepShort() async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    enum NotifyWaitError: Error {
        case timedOut
    }

    /// Waits until the mock ATT delegate records a **latest** measurement notify-enable (avoids matching stale `true` entries left in ``HeartRatePeripheralDelegate/notifyTransitions``).
    func waitForMeasurementNotifyEnabled(
        h: Harness,
        minimumPriorTransitions: Int? = nil
    ) async throws {
        let meas = MockBLEPeripheral.measurementUUID
        for _ in 0 ..< 400 {
            let transitions = h.delegate.notifyTransitions
            guard let last = transitions.last,
                  last.uuid == meas,
                  last.enabled else {
                try await Task.sleep(nanoseconds: 5_000_000)
                continue
            }
            if let minimumPriorTransitions, transitions.count <= minimumPriorTransitions {
                try await Task.sleep(nanoseconds: 5_000_000)
                continue
            }
            try await Task.sleep(nanoseconds: 50_000_000)
            return
        }
        Issue.record("Timed out waiting for measurement notify enable")
        throw NotifyWaitError.timedOut
    }

    @Test func discovery_exposesHeartRateServiceAndCharacteristic() async throws {
        let h = try await makeHarness()
        let svc = MockBLEPeripheral.serviceUUID
        let meas = MockBLEPeripheral.measurementUUID
        #expect(await h.sensor.has(service: svc))
        #expect(await h.sensor.has(characteristic: meas, in: svc))
    }

    @Test func read_unknownCharacteristic_throwsCharacteristicNotFound() async throws {
        let h = try await makeHarness()
        let svc = MockBLEPeripheral.serviceUUID
        do {
            _ = try await h.sensor.read(CBUUID(string: "FFFF"), in: svc)
            Issue.record("expected SensorError.characteristicNotFound")
        } catch let error as SensorError {
            guard case .characteristicNotFound = error else {
                Issue.record("unexpected SensorError: \(error)")
                return
            }
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func read_unknownService_throwsServiceNotFound() async throws {
        let h = try await makeHarness()
        let wrongService = CBUUID(string: "FFF0")
        let meas = MockBLEPeripheral.measurementUUID
        do {
            _ = try await h.sensor.read(meas, in: wrongService)
            Issue.record("expected SensorError.serviceNotFound")
        } catch let error as SensorError {
            guard case .serviceNotFound = error else {
                Issue.record("unexpected SensorError: \(error)")
                return
            }
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func read_measurement_returnsDelegatePayload() async throws {
        let delegate = HeartRatePeripheralDelegate()
        let expected = Data([0x16, 120])
        delegate.measurementReadPayload = expected
        let h = try await makeHarness(delegate: delegate)

        let data = try await h.sensor.read(
            MockBLEPeripheral.measurementUUID,
            in: MockBLEPeripheral.serviceUUID
        )
        #expect(data == expected)
    }

    @Test func write_control_roundTripsWithResponse() async throws {
        let h = try await makeHarness()
        let payload = Data([0x01])
        try await h.sensor.write(
            payload,
            to: MockBLEPeripheral.controlUUID,
            in: MockBLEPeripheral.serviceUUID,
            type: .withResponse
        )
        #expect(h.delegate.lastWrittenControlPayload == payload)
    }

    @Test func write_control_withoutResponse_updatesDelegate() async throws {
        let h = try await makeHarness()
        let payload = Data([0x02])
        try await h.sensor.write(
            payload,
            to: MockBLEPeripheral.controlUUID,
            in: MockBLEPeripheral.serviceUUID,
            type: .withoutResponse
        )
        try await sleepShort()
        #expect(h.delegate.lastWrittenControlPayload == payload)
    }

    @Test func subscribe_deliversSimulatedNotifications() async throws {
        let h = try await makeHarness()
        let stream = try await h.sensor.subscribe(
            to: MockBLEPeripheral.measurementUUID,
            in: MockBLEPeripheral.serviceUUID
        )
        let bucket = DataBucket()
        let task = Task {
            do {
                for try await data in stream {
                    bucket.append(data)
                }
            } catch {
                Issue.record("unexpected subscribe stream error: \(error)")
            }
        }
        defer { task.cancel() }

        try await waitForMeasurementNotifyEnabled(h: h)

        let payload = Data([0x06, 70])
        h.spec.simulateValueUpdate(payload, for: MockBLEPeripheral.measurementCharacteristic)
        try await sleepShort()
        #expect(bucket.last == payload)
    }

    @Test func subscribe_refCount_keepsNotifyUntilLastCancel() async throws {
        let h = try await makeHarness()

        let stream1 = try await h.sensor.subscribe(
            to: MockBLEPeripheral.measurementUUID,
            in: MockBLEPeripheral.serviceUUID
        )
        let firstBucket = DataBucket()
        let task1 = Task {
            do {
                for try await data in stream1 {
                    firstBucket.append(data)
                }
            } catch {}
        }

        let stream2 = try await h.sensor.subscribe(
            to: MockBLEPeripheral.measurementUUID,
            in: MockBLEPeripheral.serviceUUID
        )
        let secondBucket = DataBucket()
        let task2 = Task {
            do {
                for try await data in stream2 {
                    secondBucket.append(data)
                }
            } catch {}
        }

        try await sleepShort()

        try await waitForMeasurementNotifyEnabled(h: h)

        let payload = Data([0x01, 42])
        h.spec.simulateValueUpdate(payload, for: MockBLEPeripheral.measurementCharacteristic)
        try await sleepShort()

        #expect(firstBucket.last == payload)
        #expect(secondBucket.last == payload)

        let meas = MockBLEPeripheral.measurementUUID
        let disableStepsBefore = h.delegate.notifyTransitions.filter { $0.uuid == meas && !$0.enabled }.count

        task1.cancel()
        try await sleepShort()

        let disableStepsMiddle = h.delegate.notifyTransitions.filter { $0.uuid == meas && !$0.enabled }.count
        #expect(disableStepsMiddle == disableStepsBefore)

        task2.cancel()
        try await sleepShort()

        let disableStepsAfter = h.delegate.notifyTransitions.filter { $0.uuid == meas && !$0.enabled }.count
        #expect(disableStepsAfter == disableStepsBefore + 1)
    }

    @Test func subscribe_afterTeardownDoesNotReplayStaleCachedValue() async throws {
        let h = try await makeHarness()

        let stream1 = try await h.sensor.subscribe(
            to: MockBLEPeripheral.measurementUUID,
            in: MockBLEPeripheral.serviceUUID
        )
        let roundOne = DataBucket()
        let task1 = Task {
            do {
                for try await data in stream1 {
                    roundOne.append(data)
                }
            } catch {}
        }

        try await waitForMeasurementNotifyEnabled(h: h)

        let payloadA = Data([0xAA])
        h.spec.simulateValueUpdate(payloadA, for: MockBLEPeripheral.measurementCharacteristic)
        try await sleepShort()
        #expect(roundOne.last == payloadA)

        task1.cancel()
        try await sleepShort()

        let priorTransitionCount = h.delegate.notifyTransitions.count
        let stream2 = try await h.sensor.subscribe(
            to: MockBLEPeripheral.measurementUUID,
            in: MockBLEPeripheral.serviceUUID
        )
        let roundTwo = DataBucket()
        let task2 = Task {
            do {
                for try await data in stream2 {
                    roundTwo.append(data)
                }
            } catch {}
        }

        try await waitForMeasurementNotifyEnabled(h: h, minimumPriorTransitions: priorTransitionCount)

        try await sleepShort()
        #expect(roundTwo.isEmpty, "cached measurement must not replay after refcount hits zero")

        let payloadB = Data([0xBB])
        h.spec.simulateValueUpdate(payloadB, for: MockBLEPeripheral.measurementCharacteristic)
        try await sleepShort()
        #expect(roundTwo.last == payloadB)

        task2.cancel()
    }

    // MARK: - Extracted primitives (BLE — keep in this serialized suite with other CoreBluetoothMock tests)

    @Test func primitives_serviceDiscoverer_matchesHeartRateLayout() async throws {
        let h = try await makeHarness()
        let catalog = try await ServiceDiscoverer.discoverAll(on: h.peripheral)

        #expect(catalog.has(service: MockBLEPeripheral.serviceUUID))
        _ = try catalog.require(MockBLEPeripheral.measurementUUID, in: MockBLEPeripheral.serviceUUID)
        _ = try catalog.require(MockBLEPeripheral.controlUUID, in: MockBLEPeripheral.serviceUUID)
    }

    @Test func primitives_characteristicCatalog_discovery_matchesHeartRateLayout() async throws {
        let h = try await makeHarness()
        let catalog = try await ServiceDiscoverer.discoverAll(on: h.peripheral)

        #expect(catalog.has(service: MockBLEPeripheral.serviceUUID))
        #expect(catalog.has(characteristic: MockBLEPeripheral.measurementUUID, in: MockBLEPeripheral.serviceUUID))
        #expect(catalog.has(characteristic: MockBLEPeripheral.controlUUID, in: MockBLEPeripheral.serviceUUID))

        _ = try catalog.require(MockBLEPeripheral.measurementUUID, in: MockBLEPeripheral.serviceUUID)
    }

    @Test func primitives_connectionLifecycleObserver_emitsDisconnectAfterWasConnected() async throws {
        let h = try await makeHarness()

        let observer = ConnectionLifecycleObserver(peripheral: h.peripheral)

        let counter = EmissionCounter()

        let waiter = Task {
            for await _ in observer.disconnects {
                counter.record()
            }
        }
        defer { waiter.cancel() }

        try await sleepShort()

        _ = await h.central.cancelPeripheralConnection(h.peripheral)

        try await Task.sleep(nanoseconds: 150_000_000)

        #expect(counter.value == 1)
    }

    @Test func primitives_connectionLifecycleObserver_noEmitWhenNeverConnected() async throws {
        CBMCentralManagerMock.simulateInitialState(.poweredOff)
        let spec = MockBLEPeripheral.makeSpec(delegate: HeartRatePeripheralDelegate())
        CBMCentralManagerMock.simulatePeripherals([spec])
        CBMCentralManagerMock.simulateInitialState(.poweredOn)

        let central = CentralManager(forceMock: true)
        for await state in await central.start() where state == .poweredOn {
            break
        }

        let peripherals = await central.retrievePeripherals(withIdentifiers: [spec.identifier])
        guard let peripheral = peripherals.first else {
            Issue.record("retrievePeripherals returned empty")
            return
        }

        let observer = ConnectionLifecycleObserver(peripheral: peripheral)

        let counter = EmissionCounter()

        let waiter = Task {
            for await _ in observer.disconnects {
                counter.record()
            }
        }
        defer { waiter.cancel() }

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(counter.value == 0)
    }

    // MARK: - GATT layer (BLE — before zz_disconnect; ordering matters for mock isolation)

    @Test func gatt_adapter_discoverAllMatchesHeartRateLayout() async throws {
        let h = try await makeHarness()
        let gatt = AsyncCoreBluetoothGATTPeripheral(h.peripheral)
        let catalog = try await gatt.discoverAll()

        #expect(catalog.has(service: MockBLEPeripheral.serviceUUID))
        #expect(catalog.has(characteristic: MockBLEPeripheral.measurementUUID, in: MockBLEPeripheral.serviceUUID))
        #expect(catalog.has(characteristic: MockBLEPeripheral.controlUUID, in: MockBLEPeripheral.serviceUUID))
    }

    @Test func gatt_adapter_readReturnsDelegatePayload() async throws {
        let delegate = HeartRatePeripheralDelegate()
        let expected = Data([0x16, 120])
        delegate.measurementReadPayload = expected

        let h = try await makeHarness(delegate: delegate)
        let gatt = AsyncCoreBluetoothGATTPeripheral(h.peripheral)
        let catalog = try await gatt.discoverAll()
        let ch = try catalog.require(MockBLEPeripheral.measurementUUID, in: MockBLEPeripheral.serviceUUID)

        let data = try await gatt.read(ch)
        #expect(data == expected)
    }

    @Test func gatt_adapter_writeWithResponseRoundTrips() async throws {
        let h = try await makeHarness()
        let gatt = AsyncCoreBluetoothGATTPeripheral(h.peripheral)
        let catalog = try await gatt.discoverAll()
        let ch = try catalog.require(MockBLEPeripheral.controlUUID, in: MockBLEPeripheral.serviceUUID)

        let payload = Data([0x07])
        try await gatt.write(payload, to: ch, type: .withResponse)

        #expect(h.delegate.lastWrittenControlPayload == payload)
    }

    @Test func gatt_adapter_setNotifyAndValueStreamDeliverNotifications() async throws {
        let h = try await makeHarness()
        let gatt = AsyncCoreBluetoothGATTPeripheral(h.peripheral)
        let catalog = try await gatt.discoverAll()
        let ch = try catalog.require(MockBLEPeripheral.measurementUUID, in: MockBLEPeripheral.serviceUUID)

        _ = try await gatt.setNotify(true, for: ch)

        let stream = gatt.valueStream(for: ch)
        let box = ValueBox<Data>()
        let task = Task {
            for await value in stream {
                box.store(value)
                break
            }
        }
        defer { task.cancel() }

        try await Task.sleep(nanoseconds: 20_000_000)

        let payload = Data([0x06, 70])
        h.spec.simulateValueUpdate(payload, for: MockBLEPeripheral.measurementCharacteristic)

        try await sleepShort()

        #expect(box.load() == payload)
    }

    @Test func gatt_any_forwardsMethods() async throws {
        let (catalog, measurement, control) = try await gattCatalogMeasurementAndControl()

        let stub = GATTPeripheralStub(catalog: catalog, primaryCharacteristic: measurement, controlCharacteristic: control)
        let any = stub.eraseToAnyGATTPeripheral()

        let discovered = try await any.discoverAll()
        #expect(discovered.has(service: MockBLEPeripheral.serviceUUID))

        _ = try await any.read(measurement)
        try await any.setNotify(true, for: measurement)
        _ = any.valueStream(for: measurement)
    }

    @Test func gatt_any_eraseToAnyGATTPeripheral_isIdempotent() async throws {
        let (catalog, measurement, control) = try await gattCatalogMeasurementAndControl()

        let stub = GATTPeripheralStub(catalog: catalog, primaryCharacteristic: measurement, controlCharacteristic: control)
        let a = stub.eraseToAnyGATTPeripheral()
        let b = a.eraseToAnyGATTPeripheral()
        #expect(a === b)
    }

    @Test func gatt_serialized_forwardsAllMethods() async throws {
        let (catalog, measurement, control) = try await gattCatalogMeasurementAndControl()

        let stub = GATTPeripheralStub(catalog: catalog, primaryCharacteristic: measurement, controlCharacteristic: control)
        stub.readPayload = Data([0xDE, 0xAD])

        let gatt = SerializedGATTPeripheral(stub)

        let discovered = try await gatt.discoverAll()
        #expect(discovered.has(service: MockBLEPeripheral.serviceUUID))

        let readBack = try await gatt.read(measurement)
        #expect(readBack == Data([0xDE, 0xAD]))

        try await gatt.write(Data([0x03]), to: control, type: .withResponse)
        #expect(stub.lastWritePayload == Data([0x03]))

        try await gatt.setNotify(true, for: measurement)
        #expect(stub.lastNotifyEnabled == true)

        let stream = gatt.valueStream(for: measurement)
        let box = ValueBox<Data>()
        let task = Task {
            for await value in stream {
                box.store(value)
                break
            }
        }
        defer { task.cancel() }

        try await Task.sleep(nanoseconds: 20_000_000)
        stub.sendNotify(Data([0xFE]))
        try await Task.sleep(nanoseconds: 80_000_000)
        #expect(box.load() == Data([0xFE]))
    }

    @Test func gatt_serialized_serializesConcurrentReads() async throws {
        let (catalog, measurement, control) = try await gattCatalogMeasurementAndControl()

        let detector = OverlapDetector()
        let stub = GATTPeripheralStub(
            catalog: catalog,
            primaryCharacteristic: measurement,
            controlCharacteristic: control
        )
        stub.overlapDetector = detector
        stub.readSleepNanoseconds = 2_000_000

        let gatt = SerializedGATTPeripheral(stub)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 12 {
                group.addTask {
                    _ = try? await gatt.read(measurement)
                }
            }
        }

        #expect(!detector.overlapOccurred)
    }

    @Test func gatt_serialized_valueStreamForwardsDirectly() async throws {
        let (catalog, measurement, control) = try await gattCatalogMeasurementAndControl()

        let stub = GATTPeripheralStub(catalog: catalog, primaryCharacteristic: measurement, controlCharacteristic: control)
        let gatt = SerializedGATTPeripheral(stub)

        let fromDecorator = gatt.valueStream(for: measurement)
        let decoratorBox = ValueBox<Data>()
        let decoratorTask = Task {
            for await value in fromDecorator {
                decoratorBox.store(value)
                break
            }
        }
        defer { decoratorTask.cancel() }

        try await Task.sleep(nanoseconds: 20_000_000)
        stub.sendNotify(Data([0x11, 0x22]))
        try await Task.sleep(nanoseconds: 80_000_000)
        #expect(decoratorBox.load() == Data([0x11, 0x22]))

        let fromStub = stub.valueStream(for: measurement)
        let stubBox = ValueBox<Data>()
        let stubTask = Task {
            for await value in fromStub {
                stubBox.store(value)
                break
            }
        }
        defer { stubTask.cancel() }

        try await Task.sleep(nanoseconds: 20_000_000)
        stub.sendNotify(Data([0x33, 0x44]))
        try await Task.sleep(nanoseconds: 80_000_000)
        #expect(stubBox.load() == Data([0x33, 0x44]))
    }

    @Test func gatt_serialized_propagatesThrownErrorsAndRecovers() async throws {
        let (catalog, measurement, control) = try await gattCatalogMeasurementAndControl()

        let stub = GATTPeripheralStub(catalog: catalog, primaryCharacteristic: measurement, controlCharacteristic: control)
        let gatt = SerializedGATTPeripheral(stub)

        stub.readThrows = SensorError.disconnected

        do {
            _ = try await gatt.read(measurement)
            Issue.record("expected throw")
        } catch let error as SensorError {
            guard case .disconnected = error else {
                Issue.record("unexpected \(error)")
                return
            }
        } catch {
            Issue.record("unexpected \(error)")
        }

        stub.readThrows = nil
        let data = try await gatt.read(measurement)
        #expect(data == stub.readPayload)
    }

    /// Runs last in this suite so earlier notify/ref-count tests don’t inherit disconnect/mock fallout.
    @Test func zz_disconnect_completesSubscriberWithDisconnected() async throws {
        let h = try await makeHarness()

        let capture = CompletionHolder()

        let stream = try await h.sensor.subscribe(
            to: MockBLEPeripheral.measurementUUID,
            in: MockBLEPeripheral.serviceUUID
        )
        let task = Task {
            do {
                for try await _ in stream {}
            } catch {
                capture.error = error
            }
        }
        defer { task.cancel() }

        try await sleepShort()

        _ = await h.central.cancelPeripheralConnection(h.peripheral)

        for _ in 0 ..< 200 where capture.error == nil {
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        guard let sensorError = capture.error as? SensorError else {
            Issue.record("expected SensorError, got \(String(describing: capture.error))")
            return
        }

        guard case .disconnected = sensorError else {
            Issue.record("expected .disconnected, got \(sensorError)")
            return
        }
    }
}
