//
//  FitnessMachineService.swift
//  Sensors
//
//  Created by Tony Tallman on 5/5/26.
//

import Combine
import Foundation

package class FitnessMachineService {
    package protocol Delegate {
        func has(serviceId: String) async -> Bool
        func read(characteristicId: String) async -> Data?
        func subscribeTo(characteristicId: String) -> AnyPublisher<Data, Never>
    }

    private let delegate: Delegate

    private static let serviceId = "1826"
    private static let indoorBikeDataCharacteristicId = "2AD2"
    private static let featureCharacteristicId = "2ACC"

    package let speed: AnyPublisher<Measurement<UnitSpeed>, Never>
    package let cadence: AnyPublisher<Measurement<UnitFrequency>, Never>?
    package let heartRate: AnyPublisher<Measurement<UnitFrequency>, Never>?
    package let distance: AnyPublisher<Measurement<UnitLength>, Never>?
    package let elapsedTime: AnyPublisher<Measurement<UnitDuration>, Never>?

    private let speedSubject: PassthroughSubject<Measurement<UnitSpeed>, Never>
    private let cadenceSubject: PassthroughSubject<Measurement<UnitFrequency>, Never>?
    private let distanceSubject: PassthroughSubject<Measurement<UnitLength>, Never>?
    private let heartRateSubject: PassthroughSubject<Measurement<UnitFrequency>, Never>?
    private let elapsedTimeSubject: PassthroughSubject<Measurement<UnitDuration>, Never>?

    private var cancellable: AnyCancellable?

    package init?(delegate: Delegate) async {
        guard
            await delegate.has(serviceId: Self.serviceId),
            let featureData = await delegate.read(characteristicId: Self.featureCharacteristicId),
            let capabilities = Self.parseFeature(featureData)
        else {
            return nil
        }

        self.delegate = delegate

        let speedSub = PassthroughSubject<Measurement<UnitSpeed>, Never>()
        self.speedSubject = speedSub
        self.speed = speedSub.eraseToAnyPublisher()

        self.cadenceSubject = capabilities.cadence ? PassthroughSubject() : nil
        self.cadence = cadenceSubject?.eraseToAnyPublisher()

        self.distanceSubject = capabilities.distance ? PassthroughSubject() : nil
        self.distance = distanceSubject?.eraseToAnyPublisher()

        self.heartRateSubject = capabilities.heartRate ? PassthroughSubject() : nil
        self.heartRate = heartRateSubject?.eraseToAnyPublisher()

        self.elapsedTimeSubject = capabilities.elapsed ? PassthroughSubject() : nil
        self.elapsedTime = elapsedTimeSubject?.eraseToAnyPublisher()

        subscribeToMeasurement()
    }

    private func subscribeToMeasurement() {
        cancellable = delegate.subscribeTo(characteristicId: Self.indoorBikeDataCharacteristicId)
            .sink { [weak self] data in
                self?.handleMeasurement(data)
            }
    }

    private func handleMeasurement(_ data: Data) {
        guard let parsed = Self.parseIndoorBike(data) else {
            return
        }

        if let v = parsed.instantaneousSpeed {
            let kmh = Double(v) / 100.0
            speedSubject.send(Measurement(value: kmh, unit: UnitSpeed.kilometersPerHour))
        }
        if let v = parsed.instantaneousCadence {
            let rpm = Double(v) / 2.0
            cadenceSubject?.send(Measurement(value: rpm, unit: UnitFrequency.revolutionsPerMinute))
        }
        if let v = parsed.totalDistanceMeters {
            distanceSubject?.send(Measurement(value: Double(v), unit: UnitLength.meters))
        }
        if let v = parsed.heartRateBpm {
            heartRateSubject?.send(Measurement(value: Double(v), unit: UnitFrequency.beatsPerMinute))
        }
        if let v = parsed.elapsedTimeSeconds {
            elapsedTimeSubject?.send(Measurement(value: Double(v), unit: UnitDuration.seconds))
        }
    }

    /// Fitness Machine Feature `2ACC` first UInt32 LE (feature flags).
    private static func parseFeature(_ data: Data) -> (cadence: Bool, distance: Bool, heartRate: Bool, elapsed: Bool)? {
        guard let word = data.readUInt32LE(byteOffset: 0) else { return nil }
        let cadence = (word & (1 << 1)) != 0
        let distance = (word & (1 << 2)) != 0
        let heartRate = (word & (1 << 10)) != 0
        let elapsed = (word & (1 << 12)) != 0
        return (cadence, distance, heartRate, elapsed)
    }

    private struct ParsedIndoorBike {
        var instantaneousSpeed: UInt16?
        var instantaneousCadence: UInt16?
        var totalDistanceMeters: UInt32?
        var heartRateBpm: UInt8?
        var elapsedTimeSeconds: UInt16?
    }

    /// Indoor Bike Data `2AD2`; walk field order so offsets stay correct for selected flags.
    private static func parseIndoorBike(_ data: Data) -> ParsedIndoorBike? {
        guard let flags = data.readUInt16LE(byteOffset: 0) else { return nil }
        var offset = 2
        var parsed = ParsedIndoorBike()

        // Bit 0 "More Data": when set, instantaneous speed is omitted in this packet.
        if (flags & 0x0001) == 0 {
            guard let v = data.readUInt16LE(byteOffset: offset) else { return nil }
            parsed.instantaneousSpeed = v
            offset += 2
        }
        if (flags & 0x0002) != 0 {
            offset += 2
        }
        if (flags & 0x0004) != 0 {
            guard let v = data.readUInt16LE(byteOffset: offset) else { return nil }
            parsed.instantaneousCadence = v
            offset += 2
        }
        if (flags & 0x0008) != 0 {
            offset += 2
        }
        if (flags & 0x0010) != 0 {
            guard let v = data.readUInt24LE(byteOffset: offset) else { return nil }
            parsed.totalDistanceMeters = v
            offset += 3
        }
        if (flags & 0x0020) != 0 {
            offset += 2
        }
        if (flags & 0x0040) != 0 {
            offset += 2
        }
        if (flags & 0x0080) != 0 {
            offset += 2
        }
        if (flags & 0x0100) != 0 {
            offset += 5
        }
        if (flags & 0x0200) != 0 {
            guard offset < data.count else { return nil }
            parsed.heartRateBpm = data[data.startIndex + offset]
            offset += 1
        }
        if (flags & 0x0400) != 0 {
            offset += 1
        }
        if (flags & 0x0800) != 0 {
            guard let v = data.readUInt16LE(byteOffset: offset) else { return nil }
            parsed.elapsedTimeSeconds = v
            offset += 2
        }
        if (flags & 0x1000) != 0 {
            offset += 2
        }

        return parsed
    }
}
