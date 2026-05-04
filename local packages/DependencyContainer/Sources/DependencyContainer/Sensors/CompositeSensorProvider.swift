//
//  CompositeSensorProvider.swift
//  DependencyContainer
//
//  Composition-root `SensorProvider` (ADR-0004): merges per-type participants, SEN-SCAN-7/8; per-peripheral type dedup (ADR-0012); `availability` from system radio (ADR-0009).

import Combine
import Foundation
import SettingsVM

@MainActor
final class CompositeSensorProvider: SensorProvider {
    private let sensorProviders: [any SensorProvider]
    private let systemAvailability: AnyPublisher<BluetoothAvailability, Never>
    private var store = Set<AnyCancellable>()

    private let knownSubject = CurrentValueSubject<[any Sensor], Never>([])
    private let discoveredSubject = CurrentValueSubject<[any Sensor], Never>([])

    /// Preserves sensor order within a type; re-sorted in `emitDiscoveredIfNeeded` (SEN-SCAN-7/8).
    private var currentDiscoveredFlat: [any Sensor] = []
    private var discoveredState: [UUID: (connection: SensorConnectionState, rssi: Int?)] = [:]
    private var discoveredCancellables: [UUID: Set<AnyCancellable>] = [:]
    /// Winning ``SensorType`` per peripheral after dedup; used to rebind when the chosen stack changes (ADR-0012).
    private var discoveredBoundType: [UUID: SensorType] = [:]
    /// Tracks last published discovered list so we re-emit when order changes **or** the winning type per id changes (ADR-0012).
    private var lastEmittedDiscoveredFingerprint: [String] = []

    init(
        sensorProviders: [any SensorProvider],
        systemAvailability: AnyPublisher<BluetoothAvailability, Never>,
    ) {
        self.sensorProviders = sensorProviders
        self.systemAvailability = systemAvailability
        wireKnown()
        wireDiscovered()
    }

    /// Maps system ``BluetoothAvailability`` to ``SensorAvailability``; ``SensorProvider`` is this composite when the radio is on (ADR-0009).
    var availability: AnyPublisher<SensorAvailability, Never> {
        systemAvailability
            .map { [weak self] bt -> SensorAvailability in
                guard let self else { return .notDetermined }
                return BluetoothAvailabilityMapping.sensorAvailability(for: bt, provider: self)
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var knownSensors: AnyPublisher<[any Sensor], Never> {
        knownSubject.eraseToAnyPublisher()
    }

    var discoveredSensors: AnyPublisher<[any Sensor], Never> {
        discoveredSubject.eraseToAnyPublisher()
    }

    func scan() {
        for p in sensorProviders {
            p.scan()
        }
    }

    func stopScan() {
        for p in sensorProviders {
            p.stopScan()
        }
    }

    // MARK: - Known merge

    private func wireKnown() {
        let pubs: [AnyPublisher<[any Sensor], Never>] = sensorProviders.map {
            $0.knownSensors
                .prepend([] as [any Sensor])
                .eraseToAnyPublisher()
        }
        guard !pubs.isEmpty else {
            knownSubject.send([])
            return
        }
        combineLatest(pubs)
            .map { (arrays: [[any Sensor]]) -> [any Sensor] in
                let merged = arrays.flatMap { $0 }
                let deduped = deduplicateSensorsByPeripheralPriority(merged)
                return deduped.sorted { a, b in
                    a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }
            }
            .sink { [knownSubject] in knownSubject.send($0) }
            .store(in: &store)
    }

    // MARK: - Discovered merge (SEN-SCAN-7 / SEN-SCAN-8)

    private func wireDiscovered() {
        let pubs: [AnyPublisher<[any Sensor], Never>] = sensorProviders.map {
            $0.discoveredSensors
                .prepend([] as [any Sensor])
                .eraseToAnyPublisher()
        }
        guard !pubs.isEmpty else {
            discoveredSubject.send([])
            return
        }
        combineLatest(pubs)
            .sink { [weak self] arrays in
                self?.onDiscoveredRawMerged(arrays.flatMap { $0 })
            }
            .store(in: &store)
    }

    private func onDiscoveredRawMerged(_ merged: [any Sensor]) {
        let deduped = deduplicateSensorsByPeripheralPriority(merged)
        let newIds = Set(deduped.map(\.id))
        for id in discoveredCancellables.keys where !newIds.contains(id) {
            discoveredCancellables.removeValue(forKey: id)
            discoveredState.removeValue(forKey: id)
            discoveredBoundType.removeValue(forKey: id)
        }
        for s in deduped {
            if let bound = discoveredBoundType[s.id], bound != s.type {
                discoveredCancellables.removeValue(forKey: s.id)
                discoveredState.removeValue(forKey: s.id)
            }
            discoveredBoundType[s.id] = s.type
            if discoveredCancellables[s.id] == nil {
                bindDiscoveredSensor(s)
            }
        }
        currentDiscoveredFlat = deduped
        emitDiscoveredIfNeeded()
    }

    private func bindDiscoveredSensor(_ sensor: any Sensor) {
        var set = Set<AnyCancellable>()
        sensor.connectionState
            .sink { [weak self] state in
                guard let self else { return }
                let rssi = self.discoveredState[sensor.id]?.1
                self.discoveredState[sensor.id] = (state, rssi)
                self.emitDiscoveredIfNeeded()
            }
            .store(in: &set)

        if let rssiSensor = sensor as? any SignalStrengthReporting {
            rssiSensor.rssi
                .removeDuplicates()
                .sink { [weak self] v in
                    guard let self else { return }
                    let conn = self.discoveredState[sensor.id]?.0 ?? .disconnected
                    self.discoveredState[sensor.id] = (conn, v)
                    self.emitDiscoveredIfNeeded()
                }
                .store(in: &set)
        } else {
            let conn = discoveredState[sensor.id]?.0 ?? .disconnected
            discoveredState[sensor.id] = (conn, nil)
        }

        discoveredCancellables[sensor.id] = set
    }

    private func emitDiscoveredIfNeeded() {
        if currentDiscoveredFlat.isEmpty {
            if !lastEmittedDiscoveredFingerprint.isEmpty {
                lastEmittedDiscoveredFingerprint = []
                discoveredSubject.send([])
            }
            return
        }

        let sorted = currentDiscoveredFlat.sorted { a, b in
            Self.scan7ComesBefore(
                a, discoveredState[a.id],
                b, discoveredState[b.id]
            )
        }
        let fingerprint: [String] = sorted.map { "\($0.id.uuidString):\(String(describing: $0.type))" }
        guard fingerprint != lastEmittedDiscoveredFingerprint else { return }
        lastEmittedDiscoveredFingerprint = fingerprint
        discoveredSubject.send(sorted)
    }

    /// SEN-SCAN-7: connected first, then RSSI descending, then localized case-insensitive name.
    private static func scan7ComesBefore(
        _ a: any Sensor, _ aState: (connection: SensorConnectionState, rssi: Int?)?,
        _ b: any Sensor, _ bState: (connection: SensorConnectionState, rssi: Int?)?,
    ) -> Bool {
        let aConn = (aState?.connection ?? .disconnected) == .connected
        let bConn = (bState?.connection ?? .disconnected) == .connected
        if aConn != bConn { return aConn }
        let ra = aState?.rssi ?? Int.min
        let rb = bState?.rssi ?? Int.min
        if ra != rb { return ra > rb }
        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
    }
}

// MARK: - combineLatest (N)

private func combineLatest<Output>(
    _ publishers: [AnyPublisher<Output, Never>],
) -> AnyPublisher<[Output], Never> {
    guard let first = publishers.first else {
        return Just([]).eraseToAnyPublisher()
    }
    if publishers.count == 1 {
        return first.map { [$0] }.eraseToAnyPublisher()
    }
    let initial: AnyPublisher<[Output], Never> = first.map { [$0] }.eraseToAnyPublisher()
    return publishers
        .dropFirst()
        .reduce(into: initial) { (acc, next) in
            acc = acc
                .combineLatest(next) { (left: [Output], right: Output) in
                    left + [right]
                }
                .eraseToAnyPublisher()
        }
}
