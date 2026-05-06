//
//  FitnessMachineService.swift
//  Sensors
//
//  Created by Tony Tallman on 5/5/26.
//

import Foundation

package final class FitnessMachineService: @unchecked Sendable {
    package protocol Delegate {
        func has(serviceId: String) async -> Bool
        func read(characteristicId: String) async -> Data?
        func subscribeTo(characteristicId: String) -> AsyncStream<Data>
    }

    private let delegate: Delegate

    private static let serviceId = "1826"
    private static let indoorBikeDataCharacteristicId = "2AD2"
    private static let featureCharacteristicId = "2ACC"

    package let speed: AsyncStream<Measurement<UnitSpeed>>
    package let cadence: AsyncStream<Measurement<UnitFrequency>>?
    package let heartRate: AsyncStream<Measurement<UnitFrequency>>?
    package let distance: AsyncStream<Measurement<UnitLength>>?
    package let elapsedTime: AsyncStream<Measurement<UnitDuration>>?

    private let speedContinuation: AsyncStream<Measurement<UnitSpeed>>.Continuation
    private let cadenceContinuation: AsyncStream<Measurement<UnitFrequency>>.Continuation?
    private let distanceContinuation: AsyncStream<Measurement<UnitLength>>.Continuation?
    private let heartRateContinuation: AsyncStream<Measurement<UnitFrequency>>.Continuation?
    private let elapsedTimeContinuation: AsyncStream<Measurement<UnitDuration>>.Continuation?

    private nonisolated(unsafe) var ingestTask: Task<Void, Never>?

    package init?(delegate: Delegate) async {
        guard
            await delegate.has(serviceId: Self.serviceId),
            let featureData = await delegate.read(characteristicId: Self.featureCharacteristicId),
            let capabilities = Self.parseFeature(featureData)
        else {
            return nil
        }

        self.delegate = delegate

        let (speedStream, speedCont) = AsyncStream<Measurement<UnitSpeed>>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        self.speed = speedStream
        self.speedContinuation = speedCont

        if capabilities.cadence {
            let (s, c) = AsyncStream<Measurement<UnitFrequency>>.makeStream(bufferingPolicy: .bufferingNewest(1))
            self.cadence = s
            self.cadenceContinuation = c
        } else {
            self.cadence = nil
            self.cadenceContinuation = nil
        }

        if capabilities.distance {
            let (s, c) = AsyncStream<Measurement<UnitLength>>.makeStream(bufferingPolicy: .bufferingNewest(1))
            self.distance = s
            self.distanceContinuation = c
        } else {
            self.distance = nil
            self.distanceContinuation = nil
        }

        if capabilities.heartRate {
            let (s, c) = AsyncStream<Measurement<UnitFrequency>>.makeStream(bufferingPolicy: .bufferingNewest(1))
            self.heartRate = s
            self.heartRateContinuation = c
        } else {
            self.heartRate = nil
            self.heartRateContinuation = nil
        }

        if capabilities.elapsed {
            let (s, c) = AsyncStream<Measurement<UnitDuration>>.makeStream(bufferingPolicy: .bufferingNewest(1))
            self.elapsedTime = s
            self.elapsedTimeContinuation = c
        } else {
            self.elapsedTime = nil
            self.elapsedTimeContinuation = nil
        }

        let dataStream = delegate.subscribeTo(characteristicId: Self.indoorBikeDataCharacteristicId)
        ingestTask = Task { [weak self] in
            for await data in dataStream {
                guard let self else { break }
                self.handleMeasurement(data)
            }
        }
    }

    deinit {
        ingestTask?.cancel()
        speedContinuation.finish()
        cadenceContinuation?.finish()
        distanceContinuation?.finish()
        heartRateContinuation?.finish()
        elapsedTimeContinuation?.finish()
    }

    private func handleMeasurement(_ data: Data) {
        guard let parsed = Self.parseIndoorBike(data) else {
            return
        }

        if let v = parsed.instantaneousSpeed {
            let kmh = Double(v) / 100.0
            speedContinuation.yield(Measurement(value: kmh, unit: UnitSpeed.kilometersPerHour))
        }
        if let v = parsed.instantaneousCadence {
            let rpm = Double(v) / 2.0
            cadenceContinuation?.yield(Measurement(value: rpm, unit: UnitFrequency.revolutionsPerMinute))
        }
        if let v = parsed.totalDistanceMeters {
            distanceContinuation?.yield(Measurement(value: Double(v), unit: UnitLength.meters))
        }
        if let v = parsed.heartRateBpm {
            heartRateContinuation?.yield(Measurement(value: Double(v), unit: UnitFrequency.beatsPerMinute))
        }
        if let v = parsed.elapsedTimeSeconds {
            elapsedTimeContinuation?.yield(Measurement(value: Double(v), unit: UnitDuration.seconds))
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
