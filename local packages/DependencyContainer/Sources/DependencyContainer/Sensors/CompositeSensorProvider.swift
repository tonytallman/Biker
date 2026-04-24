//
//  CompositeSensorProvider.swift
//  DependencyContainer
//
//  Composition-root `SensorProvider` (ADR-0004): merges per-type participants, SEN-SCAN-7/8; `availability` from system radio (ADR-0009).

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
    private var lastEmittedDiscoveredIds: [UUID] = []

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
                return merged.sorted { a, b in
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
        let newIds = Set(merged.map(\.id))
        for id in discoveredCancellables.keys where !newIds.contains(id) {
            discoveredCancellables.removeValue(forKey: id)
            discoveredState.removeValue(forKey: id)
        }
        currentDiscoveredFlat = merged
        for s in merged {
            if discoveredCancellables[s.id] == nil {
                bindDiscoveredSensor(s)
            }
        }
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
            if !lastEmittedDiscoveredIds.isEmpty {
                lastEmittedDiscoveredIds = []
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
        let ids = sorted.map(\.id)
        guard ids != lastEmittedDiscoveredIds else { return }
        lastEmittedDiscoveredIds = ids
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
